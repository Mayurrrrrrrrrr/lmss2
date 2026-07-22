"""Read-only trainer portal audit against the live Oracle-backed API."""

import asyncio
import json
import urllib.error
import urllib.request

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool
from app.core.security import create_access_token


BASE = "http://127.0.0.1:8000/api/v2"
STATIC_PATHS = (
    "/trainer/dashboard",
    "/trainer/courses",
    "/trainer/assignment-options",
    "/trainer/assignments",
    "/trainer/quizzes",
    "/trainer/quiz-retake-requests",
    "/trainer/roleplay-options",
    "/trainer/roleplays",
    "/trainer/task-options",
    "/trainer/tasks",
    "/trainer/badges",
    "/trainer/rewards",
    "/trainer/points-settings",
    "/trainer/notification-options",
    "/trainer/notifications",
    "/trainer/booster",
    "/trainer/milestones-kudos",
    "/trainer/integrations",
    "/trainer/app-versions",
    "/live/trainer/options",
    "/live/trainer/sessions",
    "/ai/trainer/options",
    "/reports/options",
)


def get(path, token):
    request = urllib.request.Request(BASE + path, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
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
                await cursor.execute("SELECT id FROM users WHERE LOWER(role)='trainer' ORDER BY id FETCH FIRST 1 ROWS ONLY")
                row = await cursor.fetchone()
                if not row:
                    raise RuntimeError("No trainer account exists")
                trainer_id = int(row[0])
    finally:
        await close_db_pool()

    token = create_access_token({"sub": str(trainer_id)})
    checks = []
    responses = {}
    for path in STATIC_PATHS:
        status, data = await asyncio.to_thread(get, path, token)
        checks.append({"path": path, "status": status, "ok": status == 200})
        responses[path] = data

    courses = responses.get("/trainer/courses", {}).get("courses", []) if isinstance(responses.get("/trainer/courses"), dict) else []
    owned_course = next((course for course in courses if int(course.get("created_by") or 0) == trainer_id), courses[0] if courses else None)
    if owned_course:
        course_id = int(owned_course["id"])
        dynamic = [
            f"/trainer/courses/{course_id}/modules",
            f"/trainer/courses/{course_id}/certificate-config",
        ]
        for path in dynamic:
            status, data = await asyncio.to_thread(get, path, token)
            checks.append({"path": path, "status": status, "ok": status == 200})
            responses[path] = data
        modules = responses.get(dynamic[0], {}).get("modules", []) if isinstance(responses.get(dynamic[0]), dict) else []
        if modules:
            path = f"/trainer/modules/{modules[0]['id']}/chapters"
            status, _ = await asyncio.to_thread(get, path, token)
            checks.append({"path": path, "status": status, "ok": status == 200})

    quizzes = responses.get("/trainer/quizzes", {}).get("quizzes", []) if isinstance(responses.get("/trainer/quizzes"), dict) else []
    owned_quiz = next((quiz for quiz in quizzes if int(quiz.get("created_by") or 0) == trainer_id), quizzes[0] if quizzes else None)
    if owned_quiz:
        path = f"/trainer/quizzes/{owned_quiz['id']}/questions"
        status, _ = await asyncio.to_thread(get, path, token)
        checks.append({"path": path, "status": status, "ok": status == 200})

    sessions = responses.get("/live/trainer/sessions", {}).get("sessions", []) if isinstance(responses.get("/live/trainer/sessions"), dict) else []
    if sessions:
        session_id = sessions[0]["id"]
        for suffix in ("", "/report"):
            path = f"/live/trainer/sessions/{session_id}{suffix}"
            status, _ = await asyncio.to_thread(get, path, token)
            checks.append({"path": path, "status": status, "ok": status == 200})

    failed = [check for check in checks if not check["ok"]]
    print(json.dumps({"ok": not failed, "trainer_id": trainer_id, "checks": len(checks), "failed": failed}, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
