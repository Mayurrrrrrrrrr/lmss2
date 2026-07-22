"""Reversible end-to-end trainer authoring and assignment workflow audit."""

import asyncio
import json
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool
from app.core.security import create_access_token


BASE = "http://127.0.0.1:8000/api/v2"


def call(method, path, token, body=None):
    request = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read().decode("utf-8", "replace")
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(2000).decode("utf-8", "replace")
    except Exception as exc:
        return 0, str(exc)


async def identities():
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute("SELECT id FROM users WHERE LOWER(role)='trainer' ORDER BY id FETCH FIRST 1 ROWS ONLY")
                trainer = await cursor.fetchone()
                await cursor.execute("SELECT id FROM users WHERE LOWER(role)='participant' ORDER BY id FETCH FIRST 1 ROWS ONLY")
                participant = await cursor.fetchone()
                if not trainer or not participant:
                    raise RuntimeError("Trainer and participant accounts are required")
                return int(trainer[0]), int(participant[0])
    finally:
        await close_db_pool()


async def purge(created):
    """Remove only records created by this audit, including soft-deleted rows."""
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                if created.get("task"):
                    await cursor.execute("DELETE FROM notifications WHERE target_type='task' AND target_id=:id", id=created["task"])
                if created.get("question"):
                    await cursor.execute("DELETE FROM options WHERE question_id=:id", id=created["question"])
                    await cursor.execute("DELETE FROM questions WHERE id=:id", id=created["question"])
                if created.get("quiz"):
                    await cursor.execute("DELETE FROM quizzes WHERE id=:id", id=created["quiz"])
                if created.get("chapter"):
                    await cursor.execute("DELETE FROM chapters WHERE id=:id", id=created["chapter"])
                if created.get("module"):
                    await cursor.execute("DELETE FROM modules WHERE id=:id", id=created["module"])
                if created.get("course"):
                    await cursor.execute("DELETE FROM assignments WHERE item_type='course' AND item_id=:id", id=created["course"])
                    await cursor.execute("DELETE FROM courses WHERE id=:id", id=created["course"])
                if created.get("roleplay_topic"):
                    await cursor.execute("DELETE FROM roleplay_sessions WHERE scenario_topic=:topic", topic=created["roleplay_topic"])
                await connection.commit()
    finally:
        await close_db_pool()


async def main():
    trainer_id, participant_id = await identities()
    token = create_access_token({"sub": str(trainer_id)})
    marker = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    created = {}
    checks = []

    async def run(method, path, expected, body=None):
        status, result = await asyncio.to_thread(call, method, path, token, body)
        ok = status == expected
        checks.append({"method": method, "path": path, "status": status, "expected": expected, "ok": ok, "detail": "" if ok else result})
        if not ok:
            raise RuntimeError(f"{method} {path} returned {status}: {result}")
        return result

    try:
        course = await run("POST", "/trainer/courses", 201, {
            "title": f"Phase 3 Audit Course {marker}", "description": "Temporary workflow audit",
            "duration_type": "Days", "duration_value": 1, "assessment_q_count": 1,
            "assessment_score": 70, "course_badge_id": None, "thumbnail_path": None,
        })
        created["course"] = int(course["id"])
        await run("PUT", f"/trainer/courses/{created['course']}", 200, {
            "title": f"Phase 3 Audit Course {marker} Updated", "description": "Temporary workflow audit",
            "duration_type": "Days", "duration_value": 1, "assessment_q_count": 1,
            "assessment_score": 75, "course_badge_id": None, "thumbnail_path": None,
        })

        module = await run("POST", f"/trainer/courses/{created['course']}/modules", 201, {"title": "Audit module", "sequence_order": 1})
        created["module"] = int(module["id"])
        await run("PUT", f"/trainer/modules/{created['module']}", 200, {"title": "Audit module updated", "sequence_order": 1})

        chapter = await run("POST", f"/trainer/modules/{created['module']}/chapters", 201, {
            "title": "Audit chapter", "content_type": "html", "content_path": "<p>Temporary audit content</p>",
            "sequence_order": 1, "duration_seconds": 60,
        })
        created["chapter"] = int(chapter["id"])
        await run("PUT", f"/trainer/chapters/{created['chapter']}", 200, {
            "title": "Audit chapter updated", "content_type": "html", "content_path": "<p>Temporary audit content</p>",
            "sequence_order": 1, "duration_seconds": 90,
        })

        assignment = await run("POST", "/trainer/assignments/bulk", 200, {"course_ids": [created["course"]], "user_ids": [participant_id]})
        if int(assignment.get("assigned", 0)) != 1:
            raise RuntimeError(f"Expected one course assignment: {assignment}")
        listing = await run("GET", "/trainer/assignments?limit=200", 200)
        assignment_row = next(item for item in listing["assignments"] if int(item["course_id"]) == created["course"] and int(item["user_id"]) == participant_id)
        await run("DELETE", f"/trainer/assignments/{assignment_row['id']}", 200)

        quiz = await run("POST", "/trainer/quizzes", 201, {
            "title": f"Phase 3 Audit Quiz {marker}", "quiz_description": "Temporary workflow audit",
            "module_id": created["module"], "linked_module_id": created["module"], "scheduled_time": None,
            "duration_type": "Minutes", "duration_value": 10, "is_random": False,
            "allows_retake": True, "quiz_badge_id": None,
        })
        created["quiz"] = int(quiz["id"])
        question = await run("POST", f"/trainer/quizzes/{created['quiz']}/questions", 201, {
            "text": "Which answer confirms the audit?", "image_path": None, "difficulty": "easy",
            "options": [{"text": "Pass", "is_correct": True}, {"text": "Fail", "is_correct": False}],
        })
        created["question"] = int(question["id"])
        await run("GET", f"/trainer/quizzes/{created['quiz']}/questions", 200)

        task = await run("POST", "/trainer/tasks", 201, {
            "title": f"Phase 3 Audit Task {marker}", "description": "Temporary workflow audit",
            "verification_type": "text", "photo_source": "any", "user_ids": [participant_id],
            "store_codes": [], "manager_names": [],
        })
        created["task"] = int(task["id"])
        await run("DELETE", f"/trainer/tasks/{created['task']}", 200)

        topic = f"Phase 3 Audit Roleplay {marker}"
        created["roleplay_topic"] = topic
        await run("POST", "/trainer/roleplays/assign", 201, {
            "week_no": "Audit", "day": "Audit", "scenario_topic": topic,
            "user_ids": [participant_id], "store_codes": [], "manager_names": [],
        })
        roleplays = await run("GET", f"/trainer/roleplays?topic={urllib.parse.quote(topic)}", 200)
        session = next(item for item in roleplays["sessions"] if item["scenario_topic"] == topic)
        await run("PUT", f"/trainer/roleplays/{session['id']}", 200, {"week_no": "Audit", "day": "Audit updated", "scenario_topic": topic})
        await run("DELETE", f"/trainer/roleplays/{session['id']}", 200)

        await run("DELETE", f"/trainer/questions/{created['question']}", 200)
        await run("DELETE", f"/trainer/quizzes/{created['quiz']}", 200)
        await run("DELETE", f"/trainer/chapters/{created['chapter']}", 200)
        await run("DELETE", f"/trainer/modules/{created['module']}", 200)
        await run("DELETE", f"/trainer/courses/{created['course']}", 200)
    except Exception as exc:
        checks.append({"path": "workflow", "ok": False, "detail": str(exc)})
    finally:
        await purge(created)

    failed = [item for item in checks if not item["ok"]]
    print(json.dumps({"ok": not failed, "trainer_id": trainer_id, "participant_id": participant_id, "checks": len(checks), "failed": failed, "cleanup": "complete"}, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
