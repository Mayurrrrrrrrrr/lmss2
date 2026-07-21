"""Reversible live-quiz create/join/answer/report/delete production audit."""

import asyncio
import json
import urllib.error
import urllib.request

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool
from app.core.security import create_access_token


BASE = "http://127.0.0.1:8000/api/v2"


def call(user_id: int, method: str, path: str, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(
        BASE + path,
        data=data,
        method=method,
        headers={"Authorization": "Bearer " + create_access_token({"sub": str(user_id)}), "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"{method} {path}: {exc.code} {exc.read().decode()}") from exc


async def seed():
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute("""
                    SELECT q.created_by,q.id,qu.id,o.id
                    FROM quizzes q
                    JOIN questions qu ON qu.quiz_id=q.id AND qu.deleted_at IS NULL
                    JOIN options o ON o.question_id=qu.id AND o.is_correct=1
                    JOIN users u ON u.id=q.created_by AND LOWER(u.role)='trainer'
                    WHERE q.deleted_at IS NULL
                    ORDER BY q.id,qu.id,o.id FETCH FIRST 1 ROWS ONLY
                """)
                quiz = await cursor.fetchone()
                if not quiz:
                    raise RuntimeError("No trainer-owned quiz with a valid question and correct option exists")
                await cursor.execute("SELECT id FROM users WHERE LOWER(role)='participant' ORDER BY id FETCH FIRST 1 ROWS ONLY")
                participant = await cursor.fetchone()
                if not participant:
                    raise RuntimeError("No participant exists")
                trainer_id, quiz_id, question_id, option_id = map(int, quiz)
                participant_id = int(participant[0])
                await cursor.execute("SELECT COUNT(*) FROM assignments WHERE item_type='quiz' AND item_id=:quiz_id AND user_id=:user_id", quiz_id=quiz_id, user_id=participant_id)
                assignment_existed = int((await cursor.fetchone())[0]) > 0
                return trainer_id, participant_id, quiz_id, question_id, option_id, assignment_existed
    finally:
        await close_db_pool()


async def cleanup(session_id: int, quiz_id: int, participant_id: int, assignment_existed: bool):
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute("DELETE FROM live_session_answers WHERE session_id=:session_id", session_id=session_id)
                await cursor.execute("DELETE FROM live_session_participants WHERE session_id=:session_id", session_id=session_id)
                await cursor.execute("DELETE FROM quiz_attempts WHERE live_session_id=:session_id", session_id=session_id)
                await cursor.execute("DELETE FROM notifications WHERE user_id=:user_id AND target_type='quiz' AND target_id=:quiz_id AND title='Live Quiz Session Started'", user_id=participant_id, quiz_id=quiz_id)
                if not assignment_existed:
                    await cursor.execute("DELETE FROM assignments WHERE item_type='quiz' AND item_id=:quiz_id AND user_id=:user_id", quiz_id=quiz_id, user_id=participant_id)
                await connection.commit()
    finally:
        await close_db_pool()


async def main():
    trainer_id, participant_id, quiz_id, question_id, option_id, assignment_existed = await seed()
    session_id = None
    checks = []
    try:
        status, created = await asyncio.to_thread(call, trainer_id, "POST", "/live/trainer/sessions", {"quiz_id": quiz_id, "time_limit": 60, "user_ids": [participant_id], "store_codes": [], "manager_names": []})
        session_id = int(created["id"]); checks.append(["create", status])
        checks.append(["join", (await asyncio.to_thread(call, participant_id, "POST", "/live/participant/join", {"access_code": created["access_code"]}))[0]])
        checks.append(["open_question", (await asyncio.to_thread(call, trainer_id, "POST", f"/live/trainer/sessions/{session_id}/question", {"index": 1}))[0]])
        checks.append(["participant_state", (await asyncio.to_thread(call, participant_id, "GET", f"/live/participant/sessions/{session_id}"))[0]])
        checks.append(["answer", (await asyncio.to_thread(call, participant_id, "POST", f"/live/participant/sessions/{session_id}/answer", {"question_id": question_id, "option_id": option_id}))[0]])
        checks.append(["close_question", (await asyncio.to_thread(call, trainer_id, "POST", f"/live/trainer/sessions/{session_id}/close-question"))[0]])
        checks.append(["close_session", (await asyncio.to_thread(call, trainer_id, "POST", f"/live/trainer/sessions/{session_id}/close"))[0]])
        status, report = await asyncio.to_thread(call, trainer_id, "GET", f"/live/trainer/sessions/{session_id}/report")
        checks.append(["report", status])
        if not report.get("answers"):
            raise RuntimeError("Session report did not contain the submitted answer")
        await cleanup(session_id, quiz_id, participant_id, assignment_existed)
        checks.append(["delete", (await asyncio.to_thread(call, trainer_id, "DELETE", f"/live/trainer/sessions/{session_id}"))[0]])
        session_id = None
        print(json.dumps({"ok": all(status in (200, 201) for _, status in checks), "checks": checks, "trainer_id": trainer_id, "participant_id": participant_id, "quiz_id": quiz_id}, indent=2))
    finally:
        if session_id is not None:
            await cleanup(session_id, quiz_id, participant_id, assignment_existed)
            await init_db_pool()
            try:
                async with database._pool.acquire() as connection:
                    async with connection.cursor() as cursor:
                        await cursor.execute("DELETE FROM live_quiz_sessions WHERE id=:session_id", session_id=session_id)
                        await connection.commit()
            finally:
                await close_db_pool()


if __name__ == "__main__":
    asyncio.run(main())
