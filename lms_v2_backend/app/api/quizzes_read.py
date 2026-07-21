from fastapi import APIRouter, Depends, HTTPException, status
from typing import Any, Dict
import oracledb
from app.core.security import require_user
from app.core.database import get_db_connection
from app.schemas.user import UserProfile

router = APIRouter(prefix="/quizzes", tags=["Quizzes"])

@router.get("/list")
async def list_quizzes(
    user: UserProfile = Depends(require_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
) -> Any:
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT DISTINCT q.id, q.title, q.quiz_description, q.duration_value
            FROM quizzes q
            JOIN assignments a ON a.item_type = 'quiz' AND a.item_id = q.id
            WHERE a.user_id = :user_id AND q.deleted_at IS NULL
            ORDER BY q.title
        """, user_id=user.id)
        rows = await cursor.fetchall()
        
        quizzes = [
            {
                "id": r[0],
                "title": r[1] or "Quiz",
                "description": r[2] or "",
                "duration_minutes": r[3] or 10
            }
            for r in rows
        ]
        return {"success": True, "quizzes": quizzes}

@router.get("/detail")
async def quiz_detail(
    quiz_id: int,
    user: UserProfile = Depends(require_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
) -> Any:
    async with conn.cursor() as cursor:
        # Fetch Quiz Metadata
        await cursor.execute("""
            SELECT id, title, quiz_description, NVL(duration_value, 15)
            FROM quizzes
            WHERE id = :quiz_id AND deleted_at IS NULL
        """, quiz_id=quiz_id)
        quiz_row = await cursor.fetchone()
        
        if not quiz_row:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Quiz not found")
            
        # Fetch Questions
        await cursor.execute("""
            SELECT id, text, image_path
            FROM questions
            WHERE quiz_id = :quiz_id AND deleted_at IS NULL
            ORDER BY id
        """, quiz_id=quiz_id)
        question_rows = await cursor.fetchall()
        
        questions = []
        for q_row in question_rows:
            q_id = q_row[0]
            # Fetch Options for this question
            await cursor.execute("""
                SELECT id, text
                FROM options
                WHERE question_id = :q_id
                ORDER BY id
            """, q_id=q_id)
            option_rows = await cursor.fetchall()
            options = [{"id": o[0], "text": o[1]} for o in option_rows]
            
            questions.append({
                "id": q_id,
                "text": q_row[1] or "",
                "image_url": q_row[2],
                "options": options
            })

        return {
            "success": True,
            "quiz": {
                "id": quiz_row[0],
                "title": quiz_row[1] or "Assessment Quiz",
                "description": quiz_row[2] or "",
                "duration_minutes": quiz_row[3],
                "total_questions": len(questions),
                "questions": questions
            }
        }

@router.post("/submit")
async def submit_quiz(
    payload: Dict[str, Any],
    user: UserProfile = Depends(require_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
) -> Any:
    quiz_id = payload.get("quiz_id")
    user_answers = payload.get("answers", {}) # Map of str(question_id) -> int(option_id)
    
    if not quiz_id:
        raise HTTPException(status_code=400, detail="quiz_id is required")

    async with conn.cursor() as cursor:
        # Fetch correct answers for questions in this quiz
        await cursor.execute("""
            SELECT q.id, o.id
            FROM questions q
            JOIN options o ON o.question_id = q.id
            WHERE q.quiz_id = :quiz_id AND o.is_correct = 1 AND q.deleted_at IS NULL
        """, quiz_id=quiz_id)
        correct_rows = await cursor.fetchall()
        
        correct_map = {str(r[0]): r[1] for r in correct_rows}
        total_questions = len(correct_map) if correct_map else len(user_answers)
        
        score = 0
        for q_id_str, selected_opt in user_answers.items():
            if str(q_id_str) in correct_map and correct_map[str(q_id_str)] == int(selected_opt):
                score += 1
                
        pct = (score / total_questions * 100) if total_questions > 0 else 0
        passed = pct >= 60.0
        
        # Save Attempt
        await cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM quiz_attempts")
        next_attempt_id = (await cursor.fetchone())[0]
        
        await cursor.execute("""
            INSERT INTO quiz_attempts (id, user_id, quiz_id, score, total, start_time, end_time)
            VALUES (:1, :2, :3, :4, :5, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        """, (next_attempt_id, user.id, quiz_id, score, total_questions))
        
        await conn.commit()
        
        return {
            "success": True,
            "score": score,
            "total": total_questions,
            "percentage": round(pct, 1),
            "passed": passed,
            "xp_earned": score * 10 if passed else 0,
            "message": "Quiz completed successfully!" if passed else "Quiz completed. Keep reviewing to improve!"
        }
