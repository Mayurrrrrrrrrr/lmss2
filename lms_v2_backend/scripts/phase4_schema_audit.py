"""Read-only Oracle schema audit for the Phase 4 LMS migration."""

import asyncio
import json

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool


REQUIRED_COLUMNS = {
    "USERS": {"ID", "USERNAME", "FULL_NAME", "ROLE", "CREATED_AT"},
    "USER_PROFILES": {"USER_ID", "FULL_NAME", "STORE_CODE", "CITY", "REPORTING_MANAGER_ID", "REPORTING_MANAGER_NAME"},
    "STORES": {"ID", "STORE_CODE", "STORE_NAME", "CITY"},
    "COURSES": {"ID", "TITLE", "DESCRIPTION", "CREATED_BY", "DELETED_AT"},
    "MODULES": {"ID", "COURSE_ID", "TITLE", "DELETED_AT"},
    "CHAPTERS": {"ID", "MODULE_ID", "TITLE", "DELETED_AT", "AI_SUMMARY"},
    "ASSIGNMENTS": {"ID", "USER_ID", "ITEM_TYPE", "ITEM_ID"},
    "USER_PROGRESS": {"USER_ID", "CHAPTER_ID", "PROGRESS_PERCENT"},
    "QUIZZES": {"ID", "TITLE", "QUIZ_DESCRIPTION", "CREATED_BY", "DELETED_AT"},
    "QUESTIONS": {"ID", "QUIZ_ID", "TEXT", "IMAGE_PATH", "DIFFICULTY", "DELETED_AT"},
    "OPTIONS": {"ID", "QUESTION_ID", "TEXT", "IS_CORRECT"},
    "QUIZ_ATTEMPTS": {"ID", "USER_ID", "QUIZ_ID", "SCORE", "TOTAL", "END_TIME", "LIVE_SESSION_ID"},
    "QUIZ_ATTEMPT_ANSWERS": {"ATTEMPT_ID", "QUESTION_ID", "IS_CORRECT"},
    "LIVE_QUIZ_SESSIONS": {
        "ID", "QUIZ_ID", "ACCESS_CODE", "STATUS", "CURRENT_QUESTION_INDEX",
        "CURRENT_QUESTION_START_TIME", "TIME_LIMIT", "IS_QUESTION_CLOSED", "CREATED_AT",
    },
    "LIVE_SESSION_PARTICIPANTS": {"SESSION_ID", "USER_ID", "STATUS", "TOTAL_POINTS"},
    "LIVE_SESSION_ANSWERS": {
        "ID", "SESSION_ID", "USER_ID", "QUESTION_ID", "OPTION_ID",
        "IS_CORRECT", "TIME_TAKEN", "POINTS_EARNED",
    },
    "STATIC_PAGES": {"ID", "URL_SLUG", "TITLE", "HTML_CONTENT", "IS_PUBLIC", "CREATED_AT"},
    "LOGIN_LOGS": {"USER_ID", "LOGIN_TIME"},
    "NOTIFICATIONS": {"USER_ID", "TYPE", "TITLE", "MESSAGE", "LINK", "IS_READ", "CREATED_AT", "TARGET_TYPE", "TARGET_ID", "FCM_SENT"},
    "AI_RISK_SCORES": {"USER_ID", "TRAINER_ID", "RISK_LEVEL", "REASON", "CALCULATED_AT"},
    "SYSTEM_SETTINGS": {"SETTING_KEY", "SETTING_VALUE"},
    "AREA_MANAGER_STORES": {"MANAGER_ID", "STORE_ID"},
    "OPERATIONAL_TASKS": {"ID", "STORE_ID", "IS_ACTIVE"},
    "TASK_COMPLETIONS": {"TASK_ID", "USER_ID", "STATUS"},
    "ROLEPLAY_SESSIONS": {"ID", "USER_ID", "STATUS"},
}


async def main() -> None:
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute("SELECT table_name,column_name FROM user_tab_columns")
                actual = {}
                for table, column in await cursor.fetchall():
                    actual.setdefault(str(table).upper(), set()).add(str(column).upper())

                missing_tables = sorted(set(REQUIRED_COLUMNS) - set(actual))
                missing_columns = {
                    table: sorted(columns - actual.get(table, set()))
                    for table, columns in REQUIRED_COLUMNS.items()
                    if columns - actual.get(table, set())
                }
                await cursor.execute("""
                    SELECT access_code, COUNT(*)
                    FROM live_quiz_sessions
                    GROUP BY access_code
                    HAVING COUNT(*) > 1
                """)
                duplicate_access_codes = [row[0] for row in await cursor.fetchall()]
                result = {
                    "ok": not missing_tables and not missing_columns and not duplicate_access_codes,
                    "checked_tables": len(REQUIRED_COLUMNS),
                    "missing_tables": missing_tables,
                    "missing_columns": missing_columns,
                    "duplicate_live_access_codes": duplicate_access_codes,
                }
                print(json.dumps(result, indent=2, default=str))
                if not result["ok"]:
                    raise SystemExit(1)
    finally:
        await close_db_pool()


if __name__ == "__main__":
    asyncio.run(main())
