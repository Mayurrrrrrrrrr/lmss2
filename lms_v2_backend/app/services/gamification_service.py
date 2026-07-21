import oracledb
from app.core.websocket_manager import manager

class GamificationService:
    """
    Handles memory-efficient gamification calculations natively inside Oracle Database.
    Replaces the heavy PHP arrays from V1 gamification_helper.php.
    """
    def __init__(self, conn: oracledb.AsyncConnection):
        self.conn = conn

    async def complete_daily_booster(self, user_id: int) -> dict:
        """
        Atomically increments the user's streak upon daily booster completion.
        Replaces the inefficient PHP O(N) loop that iterated over thousands of login_logs.
        """
        async with self.conn.cursor() as cursor:
            # 1. Oracle Native MERGE INTO to atomically process streak math
            merge_query = """
                MERGE INTO user_streaks us
                USING (SELECT :user_id AS user_id FROM dual) src
                ON (us.user_id = src.user_id)
                WHEN MATCHED THEN
                    UPDATE SET 
                        current_streak = CASE 
                            WHEN last_activity_date < TRUNC(SYSDATE) THEN current_streak + 1 
                            ELSE current_streak 
                        END,
                        longest_streak = CASE
                            WHEN last_activity_date < TRUNC(SYSDATE) THEN GREATEST(longest_streak, current_streak + 1)
                            ELSE longest_streak
                        END,
                        last_activity_date = TRUNC(SYSDATE)
                WHEN NOT MATCHED THEN
                    INSERT (user_id, current_streak, longest_streak, last_activity_date)
                    VALUES (:user_id, 1, 1, TRUNC(SYSDATE))
            """
            
            await cursor.execute(merge_query, user_id=user_id)
            
            # 2. Award standard Points for the Booster Completion
            points_query = """
                INSERT INTO xp_transactions (user_id, type, points, description, created_at)
                SELECT :user_id, 'daily_booster', 45, 'Completed Daily Brain Booster', CURRENT_TIMESTAMP
                FROM dual WHERE NOT EXISTS (
                    SELECT 1 FROM xp_transactions
                    WHERE user_id=:user_id AND type='daily_booster' AND created_at>=TRUNC(SYSDATE)
                )
            """
            await cursor.execute(points_query, user_id=user_id)

            await self.conn.commit()

        # 4. Instant Leaderboard WebSocket Trigger
        # Pushes an event down the socket so clients know to re-render without refreshing the page!
        await manager.broadcast_to_room({
            "event": "leaderboard_refresh",
            "message": "A user just completed their daily booster!"
        }, room_id="global_leaderboard")

        return {"success": True, "message": "Daily booster completed and streak updated."}
