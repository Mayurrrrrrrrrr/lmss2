from fastapi import APIRouter, Depends
from typing import List, Optional
from pydantic import BaseModel
import oracledb
from app.core.security import require_user
from app.core.database import get_db_connection
from app.schemas.user import UserProfile

router = APIRouter(prefix="/participant", tags=["Participant"])

class EnrolledCourse(BaseModel):
    id: str
    title: str
    progress: float
    has_pending_quiz: bool
    thumbnail_url: Optional[str] = None

class AvailableQuiz(BaseModel):
    id: str
    title: str
    due_date: Optional[str] = None

class RecentAchievement(BaseModel):
    id: str
    title: str
    date: str

class LeaderboardRank(BaseModel):
    rank: int
    points: int

class ParticipantDashboardResponse(BaseModel):
    enrolled_courses: List[EnrolledCourse]
    available_quizzes: List[AvailableQuiz]
    recent_achievements: List[RecentAchievement]
    leaderboard_rank: LeaderboardRank

@router.get("/dashboard", response_model=ParticipantDashboardResponse)
async def get_dashboard(
    current_user: UserProfile = Depends(require_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    user_id = current_user.id
    async with conn.cursor() as cursor:
        # 1. Enrolled Courses
        # Progress is calculated as (completed chapters / total chapters in course).
        # We also look up if there are any assigned quizzes for this user under the course
        # that haven't been attempted yet.
        await cursor.execute("""
            SELECT c.id, c.title, c.thumbnail_path,
                   (SELECT COUNT(*) FROM chapters ch JOIN modules m ON ch.module_id=m.id WHERE m.course_id=c.id AND ch.deleted_at IS NULL AND m.deleted_at IS NULL) AS total_chapters,
                   (SELECT COUNT(*) FROM user_progress up JOIN chapters ch ON up.chapter_id=ch.id JOIN modules m ON ch.module_id=m.id WHERE m.course_id=c.id AND up.user_id=:user_id AND up.is_completed=1 AND ch.deleted_at IS NULL AND m.deleted_at IS NULL) AS completed_chapters,
                   CASE WHEN EXISTS (
                       SELECT 1
                       FROM quizzes q
                       JOIN assignments a_quiz ON a_quiz.item_id = q.id AND a_quiz.item_type = 'quiz'
                       WHERE a_quiz.course_id = c.id
                         AND a_quiz.user_id = :user_id
                         AND q.deleted_at IS NULL
                         AND NOT EXISTS (
                             SELECT 1 FROM quiz_attempts qa WHERE qa.quiz_id = q.id AND qa.user_id = :user_id
                         )
                   ) THEN 1 ELSE 0 END as has_pending_quiz
            FROM courses c
            JOIN assignments a ON a.item_id = c.id AND a.item_type = 'course'
            WHERE a.user_id = :user_id AND c.deleted_at IS NULL
        """, user_id=user_id)
        course_rows = await cursor.fetchall()
        
        enrolled_courses = []
        for r in course_rows:
            cid, title, thumb, total_ch, done_ch, pending_q = r
            progress = float(done_ch) / float(total_ch) if total_ch > 0 else 0.0
            enrolled_courses.append(EnrolledCourse(
                id=str(cid),
                title=title,
                progress=round(progress, 4),
                has_pending_quiz=bool(pending_q),
                thumbnail_url=thumb
            ))

        # 2. Available Quizzes
        # Quizzes assigned to the user that do not have any attempt yet.
        await cursor.execute("""
            SELECT q.id, q.title, a.deadline_date
            FROM quizzes q
            JOIN assignments a ON a.item_id = q.id AND a.item_type = 'quiz'
            WHERE a.user_id = :user_id AND q.deleted_at IS NULL
              AND NOT EXISTS (
                  SELECT 1 FROM quiz_attempts qa WHERE qa.quiz_id = q.id AND qa.user_id = :user_id
              )
            ORDER BY a.deadline_date ASC NULLS LAST
        """, user_id=user_id)
        quiz_rows = await cursor.fetchall()
        
        available_quizzes = [
            AvailableQuiz(
                id=str(r[0]),
                title=r[1],
                due_date=r[2].strftime("%Y-%m-%d") if r[2] else None
            )
            for r in quiz_rows
        ]

        # 3. Recent Achievements
        # Badges awarded to the user.
        await cursor.execute("""
            SELECT b.id, b.name, ub.awarded_at
            FROM user_badges ub
            JOIN badges b ON ub.badge_id = b.id
            WHERE ub.user_id = :user_id
            ORDER BY ub.awarded_at DESC
        """, user_id=user_id)
        badge_rows = await cursor.fetchall()
        
        recent_achievements = [
            RecentAchievement(
                id=str(r[0]),
                title=r[1],
                date=r[2].strftime("%Y-%m-%d") if r[2] else ""
            )
            for r in badge_rows
        ]

        # 4. Leaderboard Rank & Points
        # Using DENSE_RANK over sum of xp_transactions.points per user.
        await cursor.execute("""
            WITH user_xp AS (
                SELECT user_id, SUM(points) as points
                FROM xp_transactions
                GROUP BY user_id
            ),
            user_ranks AS (
                SELECT user_id, points,
                       DENSE_RANK() OVER (ORDER BY points DESC) as rank
                FROM user_xp
            )
            SELECT rank, points FROM user_ranks WHERE user_id = :user_id
        """, user_id=user_id)
        rank_row = await cursor.fetchone()
        
        if rank_row:
            rank_val, points_val = rank_row
        else:
            rank_val, points_val = 0, 0
            
        leaderboard_rank = LeaderboardRank(rank=rank_val, points=points_val)

        return ParticipantDashboardResponse(
            enrolled_courses=enrolled_courses,
            available_quizzes=available_quizzes,
            recent_achievements=recent_achievements,
            leaderboard_rank=leaderboard_rank
        )
