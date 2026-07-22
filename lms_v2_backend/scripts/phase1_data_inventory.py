"""Read-only inventory of likely test/demo records in the production Oracle schema.

This script never updates or deletes data. Every match is a review candidate only.
"""

import asyncio
import json

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool


MARKERS = ("test", "demo", "dummy", "sample", "mock", "john doe", "lorem")


def looks_synthetic(*values) -> bool:
    text = " ".join(str(value or "").lower() for value in values)
    return any(marker in text for marker in MARKERS)


async def fetch_all(cursor, sql: str, **params):
    await cursor.execute(sql, params)
    return await cursor.fetchall()


async def main() -> None:
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                counts = {}
                for table in (
                    "USERS", "COURSES", "QUIZZES", "STATIC_PAGES", "STORES",
                    "ASSIGNMENTS", "USER_PROGRESS", "QUIZ_ATTEMPTS",
                ):
                    await cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    counts[table.lower()] = int((await cursor.fetchone())[0])

                users = await fetch_all(cursor, """
                    SELECT u.id,u.username,u.role,u.created_at,
                           NVL(p.full_name,u.full_name),p.email_id,
                           (SELECT COUNT(*) FROM assignments a WHERE a.user_id=u.id),
                           (SELECT COUNT(*) FROM user_progress up WHERE up.user_id=u.id),
                           (SELECT COUNT(*) FROM quiz_attempts qa WHERE qa.user_id=u.id)
                    FROM users u LEFT JOIN user_profiles p ON p.user_id=u.id
                    ORDER BY u.id
                """)
                user_candidates = [
                    {
                        "id": int(row[0]), "username": row[1], "role": row[2],
                        "created_at": row[3], "full_name": row[4], "email": row[5],
                        "assignments": int(row[6] or 0), "progress": int(row[7] or 0),
                        "quiz_attempts": int(row[8] or 0),
                    }
                    for row in users if looks_synthetic(row[1], row[4], row[5])
                ]

                courses = await fetch_all(cursor, """
                    SELECT c.id,c.title,c.created_by,c.created_at,
                           (SELECT COUNT(*) FROM modules m WHERE m.course_id=c.id),
                           (SELECT COUNT(*) FROM assignments a
                            WHERE a.item_type='course' AND a.item_id=c.id)
                    FROM courses c WHERE c.deleted_at IS NULL ORDER BY c.id
                """)
                course_candidates = [
                    {"id": int(row[0]), "title": row[1], "created_by": row[2],
                     "created_at": row[3], "modules": int(row[4] or 0),
                     "assignments": int(row[5] or 0)}
                    for row in courses if looks_synthetic(row[1])
                ]

                quizzes = await fetch_all(cursor, """
                    SELECT q.id,q.title,q.created_by,
                           (SELECT COUNT(*) FROM questions x WHERE x.quiz_id=q.id),
                           (SELECT COUNT(*) FROM assignments a
                            WHERE a.item_type='quiz' AND a.item_id=q.id),
                           (SELECT COUNT(*) FROM quiz_attempts qa WHERE qa.quiz_id=q.id)
                    FROM quizzes q WHERE q.deleted_at IS NULL ORDER BY q.id
                """)
                quiz_candidates = [
                    {"id": int(row[0]), "title": row[1], "created_by": row[2],
                     "questions": int(row[3] or 0), "assignments": int(row[4] or 0),
                     "attempts": int(row[5] or 0)}
                    for row in quizzes if looks_synthetic(row[1])
                ]

                pages = await fetch_all(cursor, """
                    SELECT id,url_slug,title,is_public,created_at
                    FROM static_pages ORDER BY id
                """)
                page_candidates = [
                    {"id": int(row[0]), "slug": row[1], "title": row[2],
                     "is_public": bool(row[3]), "created_at": row[4]}
                    for row in pages if looks_synthetic(row[1], row[2])
                ]

                stores = await fetch_all(cursor, """
                    SELECT id,store_code,store_name,city,created_at FROM stores ORDER BY id
                """)
                store_candidates = [
                    {"id": int(row[0]), "store_code": row[1], "store_name": row[2],
                     "city": row[3], "created_at": row[4]}
                    for row in stores if looks_synthetic(row[1], row[2], row[3])
                ]

                candidates = {
                    "users": user_candidates,
                    "courses": course_candidates,
                    "quizzes": quiz_candidates,
                    "static_pages": page_candidates,
                    "stores": store_candidates,
                }
                print(json.dumps({
                    "ok": True,
                    "read_only": True,
                    "warning": "Matches are review candidates; do not delete by name alone.",
                    "counts": counts,
                    "candidate_counts": {key: len(value) for key, value in candidates.items()},
                    "candidates": candidates,
                }, indent=2, default=str))
    finally:
        await close_db_pool()


if __name__ == "__main__":
    asyncio.run(main())
