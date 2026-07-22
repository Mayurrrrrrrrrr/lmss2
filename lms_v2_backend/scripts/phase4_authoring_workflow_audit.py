"""Reversible production audit for chapter upload and quiz assignment visibility."""

import asyncio
import json
from pathlib import Path
import urllib.error
import urllib.request
from uuid import uuid4

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool
from app.core.security import create_access_token


BASE = "http://127.0.0.1:8000/api/v2"
UPLOAD_ROOT = Path("/var/www/lms_portal/uploads")


def request(path: str, token: str, data: bytes | None = None, content_type: str | None = None):
    headers = {"Authorization": f"Bearer {token}"}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(BASE + path, data=data, headers=headers, method="POST" if data is not None else "GET")
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            return response.status, json.loads(response.read().decode())
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(1000).decode("utf-8", "replace")


async def main():
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute("SELECT id FROM users WHERE LOWER(role)='trainer' ORDER BY id FETCH FIRST 1 ROW ONLY")
                trainer_id = int((await cursor.fetchone())[0])
                await cursor.execute("SELECT id FROM users WHERE LOWER(role)='participant' ORDER BY id FETCH FIRST 1 ROW ONLY")
                participant_id = int((await cursor.fetchone())[0])
                await cursor.execute("SELECT id FROM quizzes WHERE created_by=:trainer_id AND deleted_at IS NULL ORDER BY id FETCH FIRST 1 ROW ONLY", trainer_id=trainer_id)
                quiz_id = int((await cursor.fetchone())[0])
    finally:
        await close_db_pool()

    trainer_token = create_access_token({"sub": str(trainer_id)})
    participant_token = create_access_token({"sub": str(participant_id)})
    checks = []
    uploaded_path = None
    assignment_id = None
    assignment_created = False
    try:
        boundary = "----LMSAudit" + uuid4().hex
        file_content = b"Phase 4 upload audit; safe to delete."
        body = (
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"phase4-audit.txt\"\r\n"
            "Content-Type: text/plain\r\n\r\n"
        ).encode() + file_content + f"\r\n--{boundary}--\r\n".encode()
        status, result = await asyncio.to_thread(request, "/trainer/content/upload", trainer_token, body, f"multipart/form-data; boundary={boundary}")
        uploaded_path = result.get("content_path") if isinstance(result, dict) else None
        checks.append({"name": "chapter_file_upload", "status": status, "ok": status == 201 and bool(uploaded_path)})

        payload = json.dumps({"user_ids": [participant_id]}).encode()
        status, result = await asyncio.to_thread(request, f"/trainer/quizzes/{quiz_id}/assign", trainer_token, payload, "application/json")
        assignment_created = status == 200 and isinstance(result, dict) and int(result.get("assigned", 0)) == 1
        checks.append({"name": "quiz_assignment", "status": status, "ok": status == 200})

        status, result = await asyncio.to_thread(request, "/quizzes/list", participant_token)
        visible = status == 200 and any(int(item["id"]) == quiz_id for item in result.get("quizzes", []))
        checks.append({"name": "participant_quiz_visibility", "status": status, "ok": visible})

        await init_db_pool()
        try:
            async with database._pool.acquire() as connection:
                async with connection.cursor() as cursor:
                    await cursor.execute("SELECT id FROM assignments WHERE item_type='quiz' AND item_id=:quiz_id AND user_id=:user_id ORDER BY id DESC FETCH FIRST 1 ROW ONLY", quiz_id=quiz_id, user_id=participant_id)
                    row = await cursor.fetchone()
                    assignment_id = int(row[0]) if row else None
                    if assignment_created and assignment_id:
                        await cursor.execute("DELETE FROM assignments WHERE id=:assignment_id", assignment_id=assignment_id)
                        await connection.commit()
        finally:
            await close_db_pool()
    finally:
        if uploaded_path:
            (UPLOAD_ROOT / uploaded_path).unlink(missing_ok=True)

    failed = [check for check in checks if not check["ok"]]
    print(json.dumps({"ok": not failed, "trainer_id": trainer_id, "participant_id": participant_id, "quiz_id": quiz_id, "checks": checks, "cleanup": {"upload": uploaded_path, "assignment_id": assignment_id}, "failed": failed}, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
