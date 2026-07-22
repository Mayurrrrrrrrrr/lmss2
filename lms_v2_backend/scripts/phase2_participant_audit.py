"""Participant portal API audit with an idempotent profile round trip."""

import asyncio
import json
import urllib.error
import urllib.request

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool
from app.core.security import create_access_token


BASE = "http://127.0.0.1:8000/api/v2"


def request(path: str, token: str, method: str = "GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        BASE + path,
        data=data,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            raw = response.read().decode("utf-8", "replace")
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(1000).decode("utf-8", "replace")
    except Exception as exc:
        return 0, str(exc)


async def main():
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute("SELECT id FROM users WHERE LOWER(role)='participant' ORDER BY id FETCH FIRST 1 ROWS ONLY")
                participant = await cursor.fetchone()
                if not participant:
                    raise RuntimeError("No participant account exists")
                user_id = int(participant[0])
    finally:
        await close_db_pool()

    token = create_access_token({"sub": str(user_id)})
    paths = [
        "/auth/me",
        "/participant/dashboard",
        "/courses/list",
        "/quizzes/list",
        "/roleplays/list",
        "/tasks/list",
        "/rewards",
        "/badges/mine",
        "/certificates",
        "/notifications",
        "/daily-booster",
        "/participant/pages",
        "/participant/search?q=course",
        "/ai/participant/recommendations",
    ]
    checks = []
    responses = {}
    for path in paths:
        status, result = await asyncio.to_thread(request, path, token)
        checks.append({"method": "GET", "path": path, "status": status, "ok": status == 200})
        responses[path] = result

    profile = responses.get("/auth/me", {}).get("user", {}) if isinstance(responses.get("/auth/me"), dict) else {}
    if profile:
        payload = {"full_name": profile.get("full_name"), "email": profile.get("email"), "phone": profile.get("phone")}
        status, result = await asyncio.to_thread(request, "/auth/profile", token, "PUT", payload)
        unchanged = isinstance(result, dict) and result.get("user", {}).get("full_name") == profile.get("full_name")
        checks.append({"method": "PUT", "path": "/auth/profile", "status": status, "ok": status == 200 and unchanged, "idempotent": True})

    courses = responses.get("/courses/list", {}).get("courses", []) if isinstance(responses.get("/courses/list"), dict) else []
    if courses:
        course_id = courses[0].get("id")
        status, _ = await asyncio.to_thread(request, f"/courses/detail?course_id={course_id}", token)
        checks.append({"method": "GET", "path": "/courses/detail", "status": status, "ok": status == 200})

    certificates = responses.get("/certificates", {}).get("certificates", []) if isinstance(responses.get("/certificates"), dict) else []
    if certificates:
        course_id = certificates[0].get("course_id")
        status, _ = await asyncio.to_thread(request, f"/certificates/{course_id}", token)
        checks.append({"method": "GET", "path": "/certificates/{course_id}", "status": status, "ok": status == 200})

    failed = [check for check in checks if not check["ok"]]
    print(json.dumps({"ok": not failed, "participant_id": user_id, "checks": len(checks), "failed": failed}, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
