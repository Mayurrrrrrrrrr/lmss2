import oracledb
from app.schemas.analytics import CourseMetric
from typing import List

class AnalyticsService:
    """
    Handles heavy analytical operations directly via Oracle Autonomous Database
    compute power to save on Python application memory.
    """
    def __init__(self, conn: oracledb.AsyncConnection):
        self.conn = conn

    async def get_course_metrics(self) -> List[CourseMetric]:
        """
        Executes an optimized Oracle Window Function query to aggregate
        student completion and engagement rates across all courses.
        This prevents the backend from loading millions of rows into Python memory.
        """
        query = """
            WITH course_stats AS (
                SELECT 
                    c.id AS course_id,
                    COUNT(DISTINCT a.user_id) AS total_assigned,
                    COUNT(DISTINCT cc.user_id) AS total_completed,
                    NVL(ROUND(AVG(up.progress_percent), 2), 0) AS avg_progress_percent,
                    NVL(SUM(up.time_spent_seconds), 0) AS total_time_spent_seconds
                FROM courses c
                LEFT JOIN assignments a ON a.item_id = c.id AND a.item_type = 'course'
                LEFT JOIN course_completions cc ON cc.course_id = c.id
                LEFT JOIN modules m ON m.course_id = c.id
                LEFT JOIN chapters ch ON ch.module_id = m.id
                LEFT JOIN user_progress up ON up.chapter_id = ch.id
                GROUP BY c.id
            )
            SELECT 
                course_id,
                total_assigned,
                total_completed,
                CASE 
                    WHEN total_assigned > 0 THEN ROUND((total_completed / total_assigned) * 100, 2)
                    ELSE 0 
                END AS completion_rate_percent,
                avg_progress_percent,
                total_time_spent_seconds,
                RANK() OVER (ORDER BY total_completed DESC, total_assigned DESC) AS popularity_rank
            FROM course_stats
            ORDER BY popularity_rank ASC
        """
        
        async with self.conn.cursor() as cursor:
            await cursor.execute(query)
            rows = await cursor.fetchall()
            
            metrics = []
            for row in rows:
                (course_id, total_assigned, total_completed, completion_rate, 
                 avg_progress, total_time, rank) = row
                
                metrics.append(
                    CourseMetric(
                        course_id=course_id,
                        total_assigned=total_assigned,
                        total_completed=total_completed,
                        completion_rate_percent=completion_rate,
                        avg_progress_percent=avg_progress,
                        total_time_spent_seconds=total_time,
                        popularity_rank=rank
                    )
                )
            
            return metrics
