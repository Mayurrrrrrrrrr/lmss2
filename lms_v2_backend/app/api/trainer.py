from fastapi import APIRouter, Depends
import oracledb
from app.core.database import get_db_connection
from app.core.security import require_trainer
from app.schemas.user import UserProfile
from app.schemas.trainer import TrainerDashboardResponse, TrainerKPIs, TrainerDashboardDataResponse, ProgressMetrics, AssignedCourse, UpcomingQuiz
from typing import Optional, Any, List
from pydantic import BaseModel

router = APIRouter()

@router.get("/dashboard", response_model=TrainerDashboardDataResponse)
async def get_trainer_dashboard(
    current_user: UserProfile = Depends(require_trainer),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    """
    Unified Oracle endpoint to fetch metrics, assigned courses, and upcoming quizzes 
    for the trainer dashboard.
    """
    async with conn.cursor() as cursor:
        # 1a. Total Participants
        await cursor.execute("""
            SELECT COUNT(DISTINCT a.user_id)
            FROM assignments a
            JOIN courses c ON a.item_id = c.id AND a.item_type = 'course'
            WHERE c.created_by = :uid
        """, uid=current_user.id)
        row = await cursor.fetchone()
        total_participants = row[0] if row else 0

        # 1b. Active Participants (last 30 days)
        await cursor.execute("""
            SELECT COUNT(DISTINCT a.user_id)
            FROM assignments a
            JOIN courses c ON a.item_id = c.id AND a.item_type = 'course'
            JOIN users u ON a.user_id = u.id
            WHERE c.created_by = :uid AND u.last_active >= SYSDATE - 30
        """, uid=current_user.id)
        row = await cursor.fetchone()
        active_participants = row[0] if row else 0

        # 1c. Average Score
        await cursor.execute("""
            SELECT NVL(ROUND(AVG(CASE WHEN qa.total > 0 THEN (qa.score * 100.0 / qa.total) ELSE 0 END), 2), 0.0)
            FROM quiz_attempts qa
            JOIN quizzes q ON qa.quiz_id = q.id
            WHERE q.created_by = :uid
        """, uid=current_user.id)
        row = await cursor.fetchone()
        average_score = row[0] if row else 0.0

        # 1d. Pending Evaluations (Pending Roleplay Sessions for trainer's assigned students)
        await cursor.execute("""
            SELECT COUNT(*) 
            FROM roleplay_sessions r
            WHERE r.status = 'Pending' 
              AND r.user_id IN (
                  SELECT DISTINCT a.user_id 
                  FROM assignments a 
                  JOIN courses c ON a.item_id = c.id AND a.item_type = 'course'
                  WHERE c.created_by = :uid
              )
        """, uid=current_user.id)
        row = await cursor.fetchone()
        pending_evaluations = row[0] if row else 0

        metrics = ProgressMetrics(
            total_participants=total_participants,
            active_participants=active_participants,
            average_score=average_score,
            pending_evaluations=pending_evaluations
        )

        # 2. Fetch Assigned Courses (Completion rate scaled to fraction between 0.0 and 1.0)
        await cursor.execute("""
            SELECT 
                c.id,
                c.title,
                COUNT(DISTINCT a.user_id) AS participant_count,
                NVL(ROUND(COUNT(DISTINCT cc.user_id) * 1.0 / NULLIF(COUNT(DISTINCT a.user_id), 0), 4), 0.0) AS completion_rate
            FROM courses c
            LEFT JOIN assignments a ON a.item_id = c.id AND a.item_type = 'course'
            LEFT JOIN course_completions cc ON cc.course_id = c.id AND cc.user_id = a.user_id
            WHERE c.created_by = :uid AND c.deleted_at IS NULL
            GROUP BY c.id, c.title
        """, uid=current_user.id)
        assigned_courses_rows = await cursor.fetchall()
        assigned_courses = [
            AssignedCourse(
                id=str(r[0]),
                title=r[1],
                participant_count=r[2] or 0,
                completion_rate=float(r[3] or 0.0)
            )
            for r in assigned_courses_rows
        ]

        # 3. Fetch Upcoming Quizzes
        await cursor.execute("""
            SELECT 
                q.id,
                q.title,
                TO_CHAR(q.scheduled_time, 'YYYY-MM-DD HH24:MI:SS') AS scheduled_time,
                c.title AS course_name
            FROM quizzes q
            LEFT JOIN modules m ON q.module_id = m.id
            LEFT JOIN courses c ON m.course_id = c.id
            WHERE q.created_by = :uid 
              AND q.deleted_at IS NULL 
              AND q.scheduled_time >= CURRENT_TIMESTAMP
            ORDER BY q.scheduled_time ASC
        """, uid=current_user.id)
        upcoming_quizzes_rows = await cursor.fetchall()
        upcoming_quizzes = [
            UpcomingQuiz(
                id=str(r[0]),
                title=r[1],
                scheduled_time=r[2] or "",
                course_name=r[3] or ""
            )
            for r in upcoming_quizzes_rows
        ]

        return TrainerDashboardDataResponse(
            metrics=metrics,
            assigned_courses=assigned_courses,
            upcoming_quizzes=upcoming_quizzes
        )

@router.get("/reports", response_model=TrainerDashboardResponse)
async def get_trainer_reports(
    current_user: UserProfile = Depends(require_trainer),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    """
    Replaces /trainer/reports.php
    Optimized aggregation of course and quiz completions directly assigned by this trainer.
    """
    async with conn.cursor() as cursor:
        # Aggregated Course Progress
        await cursor.execute("""
            SELECT 
                COUNT(DISTINCT a.id) as courses_assigned,
                COUNT(ch.id) as total_chapters,
                SUM(NVL(prog.is_completed, 0)) as completed_chapters
            FROM assignments a
            JOIN courses c ON a.item_id = c.id AND a.item_type = 'course'
            LEFT JOIN modules m ON c.id = m.course_id
            LEFT JOIN chapters ch ON m.id = ch.module_id
            LEFT JOIN user_progress prog ON ch.id = prog.chapter_id AND prog.user_id = a.user_id
            WHERE c.created_by = :uid
        """, uid=current_user.id)
        c_row = await cursor.fetchone()
        assigned = c_row[0] if c_row else 0
        tot_ch = c_row[1] if c_row else 0
        done_ch = c_row[2] if c_row else 0
        avg_prog = (done_ch / tot_ch * 100) if tot_ch > 0 else 0.0

        # Aggregated Quiz Progress
        await cursor.execute("""
            SELECT 
                COUNT(DISTINCT a.id) as quizzes_assigned,
                SUM(qa.score) as total_score,
                SUM(qa.total) as total_max
            FROM assignments a
            JOIN quizzes q ON a.item_id = q.id AND a.item_type = 'quiz'
            LEFT JOIN quiz_attempts qa ON q.id = qa.quiz_id AND qa.user_id = a.user_id
            WHERE q.created_by = :uid
        """, uid=current_user.id)
        q_row = await cursor.fetchone()
        q_assigned = q_row[0] if q_row else 0
        tot_score = q_row[1] if q_row else 0
        tot_max = q_row[2] if q_row else 0
        avg_score = (tot_score / tot_max * 100) if tot_max > 0 else 0.0

        kpis = TrainerKPIs(
            avg_course_progress=round(avg_prog, 1),
            total_courses_assigned=assigned,
            standalone_quiz_avg_score=round(avg_score, 1),
            total_quizzes_assigned=q_assigned
        )

        return TrainerDashboardResponse(success=True, kpis=kpis)

from app.services.ai_service import generate_executive_summary
from pydantic import BaseModel

class AISummaryResponse(BaseModel):
    success: bool
    summary: str

@router.post("/reports/ai_summary", response_model=AISummaryResponse)
async def get_trainer_ai_summary(
    current_user: UserProfile = Depends(require_trainer),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    """
    Generates a Gemini AI summary for the trainer based on their current KPI metrics.
    """
    # First, quickly compute the KPIs (reuse logic or abstract it)
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT 
                COUNT(DISTINCT a.id) as courses_assigned,
                COUNT(ch.id) as total_chapters,
                SUM(NVL(prog.is_completed, 0)) as completed_chapters
            FROM assignments a
            JOIN courses c ON a.item_id = c.id AND a.item_type = 'course'
            LEFT JOIN modules m ON c.id = m.course_id
            LEFT JOIN chapters ch ON m.id = ch.module_id
            LEFT JOIN user_progress prog ON ch.id = prog.chapter_id AND prog.user_id = a.user_id
            WHERE c.created_by = :uid
        """, uid=current_user.id)
        c_row = await cursor.fetchone()
        
        await cursor.execute("""
            SELECT 
                SUM(qa.score) as total_score,
                SUM(qa.total) as total_max
            FROM assignments a
            JOIN quizzes q ON a.item_id = q.id AND a.item_type = 'quiz'
            LEFT JOIN quiz_attempts qa ON q.id = qa.quiz_id AND qa.user_id = a.user_id
            WHERE q.created_by = :uid
        """, uid=current_user.id)
        q_row = await cursor.fetchone()
        
    tot_ch = c_row[1] if c_row else 0
    done_ch = c_row[2] if c_row else 0
    avg_prog = (done_ch / tot_ch * 100) if tot_ch > 0 else 0.0
    
    tot_score = q_row[0] if q_row else 0
    tot_max = q_row[1] if q_row else 0
    avg_score = (tot_score / tot_max * 100) if tot_max > 0 else 0.0
    
    metrics = {
        'total_assignments': c_row[0] if c_row else 0,
        'avg_progress': round(avg_prog, 1),
        'avg_score': round(avg_score, 1)
    }
    
    summary = await generate_executive_summary(metrics, current_user.id)
    return AISummaryResponse(success=True, summary=summary)

class IntegrationsReq(BaseModel):
    smtp_host: Optional[str] = None
    smtp_port: Optional[int] = None
    smtp_user: Optional[str] = None
    smtp_password: Optional[str] = None
    smtp_from_email: Optional[str] = None
    gemini_api_key: Optional[str] = None

class IntegrationsRes(BaseModel):
    smtp_host: Optional[str]
    smtp_port: Optional[int]
    smtp_user: Optional[str]
    smtp_from_email: Optional[str]
    has_smtp_password: bool
    has_gemini_api_key: bool

@router.get("/integrations", response_model=IntegrationsRes)
async def get_integrations(
    current_user: UserProfile = Depends(require_trainer),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute(
            "SELECT smtp_host, smtp_port, smtp_user, smtp_password, smtp_from_email, gemini_api_key FROM trainer_integrations WHERE trainer_id = :trainer_id",
            trainer_id=current_user.id
        )
        row = await cursor.fetchone()
        
        if not row:
            return IntegrationsRes(
                smtp_host=None, smtp_port=None, smtp_user=None, smtp_from_email=None,
                has_smtp_password=False, has_gemini_api_key=False
            )
        
        return IntegrationsRes(
            smtp_host=row[0],
            smtp_port=row[1],
            smtp_user=row[2],
            smtp_from_email=row[4],
            has_smtp_password=bool(row[3]),
            has_gemini_api_key=bool(row[5])
        )

@router.post("/integrations")
async def save_integrations(
    req: IntegrationsReq,
    current_user: UserProfile = Depends(require_trainer),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        # Check if exists
        await cursor.execute("SELECT smtp_password, gemini_api_key FROM trainer_integrations WHERE trainer_id = :trainer_id", trainer_id=current_user.id)
        row = await cursor.fetchone()
        
        final_smtp_pass = req.smtp_password
        final_gemini_key = req.gemini_api_key
        
        if row:
            # Retain existing passwords if not provided
            if not final_smtp_pass and row[0]:
                final_smtp_pass = row[0]
            if not final_gemini_key and row[1]:
                final_gemini_key = row[1]
                
            await cursor.execute("""
                UPDATE trainer_integrations
                SET smtp_host = :h, smtp_port = :p, smtp_user = :u, smtp_password = :pw, smtp_from_email = :f, gemini_api_key = :g, updated_at = CURRENT_TIMESTAMP
                WHERE trainer_id = :tid
            """, h=req.smtp_host, p=req.smtp_port, u=req.smtp_user, pw=final_smtp_pass, f=req.smtp_from_email, g=final_gemini_key, tid=current_user.id)
        else:
            await cursor.execute("""
                INSERT INTO trainer_integrations (trainer_id, smtp_host, smtp_port, smtp_user, smtp_password, smtp_from_email, gemini_api_key)
                VALUES (:tid, :h, :p, :u, :pw, :f, :g)
            """, tid=current_user.id, h=req.smtp_host, p=req.smtp_port, u=req.smtp_user, pw=final_smtp_pass, f=req.smtp_from_email, g=final_gemini_key)
        
        await conn.commit()
        return {"success": True, "message": "Integrations saved successfully"}
