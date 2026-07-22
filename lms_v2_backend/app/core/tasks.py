import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
import app.core.database as database

logger = logging.getLogger(__name__)

# Single-threaded, event-loop attached scheduler
scheduler = AsyncIOScheduler()

async def break_streaks():
    """
    Cron to check and break user streaks if they missed yesterday.
    Ported from V1 streak_cron.php. Runs daily at 00:01.
    """
    if not database._pool:
        logger.warning("Database pool not available for break_streaks cron.")
        return
        
    async with database._pool.acquire() as conn:
        async with conn.cursor() as cursor:
            # Oracle SQL: TRUNC(SYSDATE) - 1 equates to yesterday at midnight
            query = """
                UPDATE user_streaks
                SET current_streak = 0
                WHERE current_streak > 0 
                  AND last_activity_date < (TRUNC(SYSDATE) - 1)
            """
            try:
                await cursor.execute(query)
                broken = cursor.rowcount
                await conn.commit()
                logger.info(f"Streak cron ran successfully. Streaks broken: {broken}")
            except Exception as e:
                logger.error(f"Streak cron error: {e}")
                await conn.rollback()

async def send_daily_boosters():
    """
    Notifies active participants about their daily booster challenge.
    Ported from V1 daily_booster_cron.php. Runs daily at 09:00 AM.
    """
    if not database._pool:
        logger.warning("Database pool not available for send_daily_boosters cron.")
        return
        
    async with database._pool.acquire() as conn:
        async with conn.cursor() as cursor:
            try:
                # Highly optimized Oracle bulk insert avoiding individual loop execution like V1 PHP
                bulk_insert = """
                    INSERT INTO notifications (user_id, type, title, message, link, is_read, fcm_sent, created_at)
                    SELECT id, 'daily_booster', 'Daily Brain Booster Ready!', 'Answer 3 quick questions to earn up to 45 XP today!', '/participant/dashboard', 0, 1, CURRENT_TIMESTAMP
                    FROM users 
                    WHERE LOWER(role) = 'participant' AND NVL(LOWER(status),'active')='active'
                      AND NOT EXISTS (SELECT 1 FROM notifications n WHERE n.user_id=users.id AND n.type='daily_booster' AND n.created_at>=TRUNC(SYSDATE))
                """
                await cursor.execute(bulk_insert)
                notified = cursor.rowcount
                await conn.commit()
                logger.info(f"Daily booster cron ran successfully. Bulk notified {notified} participants.")
            except Exception as e:
                logger.error(f"Daily booster cron error: {e}")
                await conn.rollback()

def start_scheduler():
    """
    Starts the in-memory APScheduler inside the FastAPI event loop.
    No heavy Redis or Celery workers required. Memory footprint remains lean.
    """
    # Register background jobs
    scheduler.add_job(break_streaks, CronTrigger(hour=0, minute=1))
    scheduler.add_job(send_daily_boosters, CronTrigger(hour=9, minute=0))
    
    scheduler.start()
    logger.info("Native OS APScheduler started in single-threaded mode.")

def stop_scheduler():
    """
    Gracefully shuts down the background scheduler.
    """
    scheduler.shutdown()
    logger.info("Native OS APScheduler stopped.")
