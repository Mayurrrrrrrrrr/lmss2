"""Read-only diagnosis for the trainer course-create failure."""

import asyncio
import json

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool


async def main():
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute("""
                    SELECT id,message,file_path,created_at
                    FROM system_errors
                    WHERE file_path='/api/v2/trainer/courses'
                    ORDER BY created_at DESC
                    FETCH FIRST 5 ROWS ONLY
                """)
                errors = [dict(zip(("id", "message", "path", "created_at"), row)) for row in await cursor.fetchall()]

                await cursor.execute("""
                    SELECT column_name,data_type,nullable,data_default,identity_column
                    FROM user_tab_columns
                    WHERE table_name='COURSES'
                    ORDER BY column_id
                """)
                columns = [dict(zip(("name", "type", "nullable", "default", "identity"), row)) for row in await cursor.fetchall()]

                await cursor.execute("""
                    SELECT trigger_name,status,triggering_event,trigger_type
                    FROM user_triggers
                    WHERE table_name='COURSES'
                    ORDER BY trigger_name
                """)
                triggers = [dict(zip(("name", "status", "event", "type"), row)) for row in await cursor.fetchall()]

                print(json.dumps({"errors": errors, "columns": columns, "triggers": triggers}, indent=2, default=str))
    finally:
        await close_db_pool()


if __name__ == "__main__":
    asyncio.run(main())
