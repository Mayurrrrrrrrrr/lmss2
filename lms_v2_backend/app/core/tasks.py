"""Idempotent scheduled LMS jobs.

These functions are intentionally not started by FastAPI. Production runs more
than one web worker, so embedding a scheduler in the API would execute every job
once per worker. Dedicated systemd timers invoke the runner instead.
"""

import logging

import app.core.database as database

logger = logging.getLogger(__name__)


async def break_streaks() -> int:
    """Reset streaks whose owner did not record activity yesterday."""
    if not database._pool:
        raise RuntimeError("Database pool is not available")
    async with database._pool.acquire() as conn:
        async with conn.cursor() as cursor:
            try:
                await cursor.execute("""
                    UPDATE user_streaks
                    SET current_streak = 0
                    WHERE current_streak > 0
                      AND last_activity_date < (TRUNC(SYSDATE) - 1)
                """)
                affected = int(cursor.rowcount or 0)
                await conn.commit()
                logger.info("Streak maintenance completed: %s reset", affected)
                return affected
            except Exception:
                await conn.rollback()
                logger.exception("Streak maintenance failed")
                raise


async def send_daily_boosters() -> int:
    """Create one in-app booster reminder per active participant per day."""
    if not database._pool:
        raise RuntimeError("Database pool is not available")
    async with database._pool.acquire() as conn:
        async with conn.cursor() as cursor:
            try:
                await cursor.execute("""
                    INSERT INTO notifications
                        (user_id, type, title, message, link, is_read,
                         fcm_sent, created_at, target_type)
                    SELECT id, 'daily_booster', 'Daily Brain Booster Ready!',
                           'Answer 3 quick questions to earn up to 45 XP today!',
                           '/participant/booster', 0, 0, SYSTIMESTAMP, 'daily_booster'
                    FROM users u
                    WHERE LOWER(u.role) = 'participant'
                      AND NVL(LOWER(u.status), 'active') = 'active'
                      AND NOT EXISTS (
                          SELECT 1 FROM notifications n
                          WHERE n.user_id = u.id
                            AND n.type = 'daily_booster'
                            AND n.created_at >= TRUNC(SYSDATE)
                      )
                """)
                affected = int(cursor.rowcount or 0)
                await conn.commit()
                logger.info("Daily booster reminders created: %s", affected)
                return affected
            except Exception:
                await conn.rollback()
                logger.exception("Daily booster reminder job failed")
                raise


JOBS = {
    "daily-booster": send_daily_boosters,
    "break-streaks": break_streaks,
}
