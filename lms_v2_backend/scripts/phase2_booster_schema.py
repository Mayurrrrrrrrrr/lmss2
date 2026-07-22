"""Read-only Oracle schema probe for the Daily Booster workflow."""

import asyncio
import json

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool


TABLES = (
    "DAILY_BOOSTER_ATTEMPTS",
    "DAILY_BOOSTER_QUESTION_LOGS",
    "BRAIN_BOOSTER_LINKED_QUIZZES",
    "QUESTIONS",
    "OPTIONS",
)


async def main():
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute(
                    """
                    SELECT table_name, column_name, data_type
                    FROM user_tab_columns
                    WHERE table_name IN ({})
                    ORDER BY table_name, column_id
                    """.format(",".join(f"'{table}'" for table in TABLES))
                )
                schema = {}
                for table, column, data_type in await cursor.fetchall():
                    schema.setdefault(table, []).append({"name": column, "type": data_type})

                counts = {}
                for table in TABLES:
                    if table not in schema:
                        counts[table] = None
                        continue
                    await cursor.execute(f"SELECT COUNT(*) FROM {table}")
                    counts[table] = int((await cursor.fetchone())[0])

                probes = []
                statements = [
                    (
                        "today_attempt",
                        "SELECT score,xp_earned FROM daily_booster_attempts WHERE user_id=:user_id AND \"DATE\"=TRUNC(SYSDATE)",
                        {"user_id": 24},
                    ),
                    (
                        "unseen_questions",
                        """SELECT id,text,image_path FROM (
                               SELECT q.id,q.text,q.image_path FROM questions q
                               WHERE q.deleted_at IS NULL
                                 AND (q.quiz_id=0 OR q.quiz_id IN (SELECT quiz_id FROM brain_booster_linked_quizzes))
                                 AND NOT EXISTS (
                                     SELECT 1 FROM daily_booster_question_logs l
                                     WHERE l.user_id=:user_id AND l.question_id=q.id
                                 )
                               ORDER BY DBMS_RANDOM.VALUE
                           ) FETCH FIRST 3 ROWS ONLY""",
                        {"user_id": 24},
                    ),
                    (
                        "fallback_questions",
                        """SELECT id,text,image_path FROM (
                               SELECT q.id,q.text,q.image_path FROM questions q
                               WHERE q.deleted_at IS NULL
                                 AND (q.quiz_id=0 OR q.quiz_id IN (SELECT quiz_id FROM brain_booster_linked_quizzes))
                               ORDER BY DBMS_RANDOM.VALUE
                           ) FETCH FIRST 3 ROWS ONLY""",
                        {},
                    ),
                ]
                for name, sql, params in statements:
                    try:
                        await cursor.execute(sql, params)
                        rows = await cursor.fetchall()
                        probes.append({"name": name, "ok": True, "rows": len(rows)})
                    except Exception as exc:
                        probes.append({"name": name, "ok": False, "error": str(exc)})

                print(json.dumps({"ok": all(p["ok"] for p in probes), "schema": schema, "counts": counts, "probes": probes}, indent=2))
    finally:
        await close_db_pool()


if __name__ == "__main__":
    asyncio.run(main())
