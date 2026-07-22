"""Read-only audit for public pages, trainer previews, and participant quiz access."""

import asyncio
import json
import urllib.error
import urllib.parse
import urllib.request

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool
from app.core.security import create_access_token


BASE = "http://127.0.0.1:8000/api/v2"


def get(path: str, token: str | None = None) -> tuple[int, dict | str]:
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    request = urllib.request.Request(BASE + path, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            body = response.read().decode("utf-8", "replace")
            try:
                return response.status, json.loads(body)
            except json.JSONDecodeError:
                return response.status, body
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read(1000).decode("utf-8", "replace")
    except Exception as exc:
        return 0, str(exc)


async def main() -> None:
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute(
                    "SELECT id FROM users WHERE LOWER(role)='trainer' ORDER BY id FETCH FIRST 1 ROW ONLY"
                )
                trainer_id = int((await cursor.fetchone())[0])
                await cursor.execute(
                    """
                    SELECT id FROM courses
                     WHERE created_by=:trainer_id AND deleted_at IS NULL
                     ORDER BY id FETCH FIRST 1 ROW ONLY
                    """,
                    trainer_id=trainer_id,
                )
                row = await cursor.fetchone()
                course_id = int(row[0]) if row else None
                await cursor.execute(
                    """
                    SELECT id FROM quizzes
                     WHERE created_by=:trainer_id AND deleted_at IS NULL
                     ORDER BY id FETCH FIRST 1 ROW ONLY
                    """,
                    trainer_id=trainer_id,
                )
                row = await cursor.fetchone()
                quiz_id = int(row[0]) if row else None
                await cursor.execute(
                    "SELECT url_slug FROM static_pages WHERE is_public=1 ORDER BY url_slug"
                )
                public_slugs = [str(row[0]) for row in await cursor.fetchall()]
    finally:
        await close_db_pool()

    trainer_token = create_access_token({"sub": str(trainer_id)})
    checks = []

    if course_id is not None:
        status, body = await asyncio.to_thread(get, f"/courses/detail?course_id={course_id}", trainer_token)
        checks.append({"name": "trainer_course_preview", "status": status, "ok": status == 200})
        if status == 200 and isinstance(body, dict):
            chapters = [chapter for module in body.get("modules", []) for chapter in module.get("chapters", [])]
            signed = [chapter.get("media_url") for chapter in chapters if chapter.get("media_url")]
            checks.append({"name": "signed_training_media", "count": len(signed), "ok": all("signature=" in url and "expires=" in url for url in signed)})
    else:
        checks.append({"name": "trainer_course_preview", "ok": False, "detail": "No owned course"})

    if quiz_id is not None:
        status, _ = await asyncio.to_thread(get, f"/quizzes/detail?quiz_id={quiz_id}", trainer_token)
        checks.append({"name": "trainer_quiz_preview", "status": status, "ok": status == 200})
    else:
        checks.append({"name": "trainer_quiz_preview", "ok": False, "detail": "No owned quiz"})

    for slug in public_slugs:
        status, body = await asyncio.to_thread(get, f"/public/pages/{urllib.parse.quote(slug)}")
        content = body.get("content", "") if isinstance(body, dict) else ""
        checks.append({"name": f"public_page:{slug}", "status": status, "content_length": len(content), "ok": status == 200 and bool(content)})

    failed = [check for check in checks if not check["ok"]]
    print(json.dumps({"ok": not failed, "trainer_id": trainer_id, "course_id": course_id, "quiz_id": quiz_id, "public_slugs": public_slugs, "checks": checks, "failed": failed}, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
