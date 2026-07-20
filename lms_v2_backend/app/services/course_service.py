import oracledb
from fastapi import HTTPException, status
from app.schemas.course import SaveProgressRequest, SaveProgressResponse

class CourseService:
    """
    Handles Course Tracking Logic with heavy lifting pushed to Oracle DB
    """
    def __init__(self, conn: oracledb.AsyncConnection):
        self.conn = conn

    async def save_progress(self, user_id: int, req: SaveProgressRequest) -> SaveProgressResponse:
        async with self.conn.cursor() as cursor:
            # 1. Fetch access, chapter duration, and existing progress in a single query to save RAM/Network
            fetch_query = """
                SELECT ch.duration_seconds, ch.content_type, m.course_id,
                       NVL(up.time_spent_seconds, 0) as time_spent_seconds,
                       NVL(up.is_completed, 0) as is_completed,
                       NVL(up.progress_percent, 0) as current_progress
                FROM chapters ch
                JOIN modules m ON ch.module_id = m.id
                JOIN assignments a ON m.course_id = a.item_id AND a.item_type = 'course'
                LEFT JOIN user_progress up ON up.chapter_id = ch.id AND up.user_id = :user_id
                WHERE ch.id = :chapter_id AND a.user_id = :user_id
            """
            await cursor.execute(fetch_query, user_id=user_id, chapter_id=req.chapter_id)
            row = await cursor.fetchone()

            if not row:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN, 
                    detail="Access denied to this chapter."
                )

            # Oracle returns columns by index
            (duration_seconds, content_type, course_id, 
             db_time_spent, db_is_completed, db_progress) = row

            total_time_spent = db_time_spent + req.time_spent
            duration_seconds = duration_seconds or 60
            
            # 2. Anti-cheat Logic
            now_completed = 0
            anti_cheat_triggered = False
            progress = req.progress

            if progress >= 95:
                if content_type == 'html':
                    now_completed = 1
                    progress = 100
                elif total_time_spent >= (duration_seconds * 0.6): # 60% min attention span
                    now_completed = 1
                    progress = 100
                else:
                    progress = 94
                    anti_cheat_triggered = True

            final_progress = max(progress, db_progress)
            final_completed = 1 if (now_completed or db_is_completed) else 0

            # 3. Oracle MERGE INTO user_progress - offloading upsert resolution to the database
            merge_query = """
                MERGE INTO user_progress up
                USING (SELECT :user_id AS user_id, :chapter_id AS chapter_id FROM dual) src
                ON (up.user_id = src.user_id AND up.chapter_id = src.chapter_id)
                WHEN MATCHED THEN
                    UPDATE SET 
                        progress_percent = :final_progress,
                        time_spent_seconds = time_spent_seconds + :time_spent,
                        is_completed = :final_completed,
                        completed_at = CASE WHEN :now_completed = 1 AND completed_at IS NULL THEN CURRENT_TIMESTAMP ELSE completed_at END
                WHEN NOT MATCHED THEN
                    INSERT (user_id, chapter_id, is_completed, progress_percent, time_spent_seconds, completed_at)
                    VALUES (:user_id, :chapter_id, :now_completed, :final_progress, :time_spent, CASE WHEN :now_completed = 1 THEN CURRENT_TIMESTAMP ELSE NULL END)
            """
            await cursor.execute(merge_query, 
                                 user_id=user_id, chapter_id=req.chapter_id,
                                 final_progress=final_progress, time_spent=req.time_spent,
                                 final_completed=final_completed, now_completed=now_completed)

            course_just_completed = False
            
            # 4. Check if course is fully completed (Offloaded to DB computation)
            if course_id:
                check_course = """
                    SELECT 
                        (SELECT COUNT(*) FROM chapters ch JOIN modules m ON ch.module_id=m.id WHERE m.course_id=:course_id AND ch.deleted_at IS NULL AND m.deleted_at IS NULL) AS total,
                        (SELECT COUNT(*) FROM user_progress up JOIN chapters ch ON up.chapter_id=ch.id JOIN modules m ON ch.module_id=m.id WHERE m.course_id=:course_id AND up.user_id=:user_id AND up.is_completed=1 AND ch.deleted_at IS NULL AND m.deleted_at IS NULL) AS done
                    FROM dual
                """
                await cursor.execute(check_course, course_id=course_id, user_id=user_id)
                cc_row = await cursor.fetchone()
                if cc_row and cc_row[0] > 0 and cc_row[1] >= cc_row[0]:
                    # Insert course completion statelessly using Oracle INSERT ... SELECT NOT EXISTS
                    comp_ins = """
                        INSERT INTO course_completions (user_id, course_id, email_sent)
                        SELECT :user_id, :course_id, 0 FROM dual
                        WHERE NOT EXISTS (
                            SELECT 1 FROM course_completions WHERE user_id=:user_id AND course_id=:course_id
                        )
                    """
                    await cursor.execute(comp_ins, user_id=user_id, course_id=course_id)
                    if cursor.rowcount > 0:
                        course_just_completed = True
                        # Note: In V2, DB triggers should handle XP/Badges here to save server RAM!

            await self.conn.commit()

            return SaveProgressResponse(
                success=True,
                progress=final_progress,
                time_spent=total_time_spent,
                is_completed=bool(final_completed),
                course_just_completed=course_just_completed,
                course_id=course_id,
                anti_cheat_warning="You skipped ahead too fast! Please spend a bit more time on this chapter to get 100% completion." if anti_cheat_triggered else None
            )
