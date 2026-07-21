"""Print targeted Oracle metadata required to resolve Phase 4 audit failures."""

import asyncio
import json

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool


TABLES = (
    "USER_PROGRESS", "LIVE_SESSION_ANSWERS", "QUIZZES", "ASSIGNMENTS",
    "USERS", "USER_PROFILES", "QUIZ_ATTEMPTS", "QUESTIONS", "OPTIONS",
)


async def main() -> None:
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                binds = ",".join(f":t{i}" for i in range(len(TABLES)))
                await cursor.execute(
                    f"SELECT table_name,column_name,data_type,nullable FROM user_tab_columns WHERE table_name IN ({binds}) ORDER BY table_name,column_id",
                    {f"t{i}": table for i, table in enumerate(TABLES)},
                )
                result = {}
                for table, column, data_type, nullable in await cursor.fetchall():
                    result.setdefault(table, []).append({"column": column, "type": data_type, "nullable": nullable})
                print(json.dumps(result, indent=2))
    finally:
        await close_db_pool()


if __name__ == "__main__":
    asyncio.run(main())
