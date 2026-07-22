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

                print(json.dumps({"ok": True, "schema": schema, "counts": counts}, indent=2))
    finally:
        await close_db_pool()


if __name__ == "__main__":
    asyncio.run(main())
