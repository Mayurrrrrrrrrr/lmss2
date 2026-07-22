"""Read-only endpoint and RBAC audit for all LMS roles."""

import asyncio
import json
import urllib.error
import urllib.request

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool
from app.core.security import create_access_token


BASE = "http://127.0.0.1:8000/api/v2"
ROLE_ENDPOINTS = {
    "admin": ["/admin/dashboard", "/admin/users", "/admin/pages", "/reports/options"],
    "trainer": ["/trainer/dashboard", "/trainer/courses", "/trainer/quizzes", "/live/trainer/options", "/ai/trainer/options", "/reports/options"],
    "participant": ["/participant/dashboard", "/courses/list", "/quizzes/list", "/tasks/list", "/roleplays/list", "/participant/pages"],
    "area_manager": ["/manager/dashboard", "/reports/options", "/participant/search?q=course"],
}
DENIED_ENDPOINTS = {
    "participant": ["/admin/dashboard", "/trainer/dashboard", "/live/trainer/options"],
    "trainer": ["/admin/dashboard", "/manager/dashboard"],
    "area_manager": ["/admin/dashboard", "/trainer/dashboard"],
}


def get(path: str, token: str) -> tuple[int, str]:
    request = urllib.request.Request(BASE + path, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return response.status, response.read(500).decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(500).decode("utf-8", "replace")
    except Exception as exc:
        return 0, str(exc)


async def main() -> None:
    await init_db_pool()
    try:
        ids = {}
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                for role in ROLE_ENDPOINTS:
                    await cursor.execute(
                        "SELECT id FROM users WHERE LOWER(role)=:role ORDER BY id FETCH FIRST 1 ROWS ONLY",
                        role=role,
                    )
                    row = await cursor.fetchone()
                    ids[role] = int(row[0]) if row else None
    finally:
        await close_db_pool()

    results = []
    for role, endpoints in ROLE_ENDPOINTS.items():
        user_id = ids[role]
        if user_id is None:
            results.append({"role": role, "path": "*", "status": None, "ok": False, "detail": "No user exists for role"})
            continue
        token = create_access_token({"sub": str(user_id)})
        for path in endpoints:
            status, detail = await asyncio.to_thread(get, path, token)
            results.append({"role": role, "path": path, "status": status, "ok": status == 200, "detail": detail if status != 200 else ""})
        for path in DENIED_ENDPOINTS.get(role, []):
            status, detail = await asyncio.to_thread(get, path, token)
            results.append({"role": role, "path": path, "status": status, "ok": status == 403, "expected": 403, "detail": detail if status != 403 else ""})

    failed = [result for result in results if not result["ok"]]
    print(json.dumps({"ok": not failed, "users": ids, "checks": len(results), "failed": failed}, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
