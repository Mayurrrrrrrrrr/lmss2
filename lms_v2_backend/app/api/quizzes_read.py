from fastapi import APIRouter, Depends, HTTPException, status
from typing import Any, Dict
import oracledb
from app.core.security import get_current_user
from app.core.database import get_db_connection
from app.schemas.user import UserProfile

router = APIRouter(prefix="/quizzes", tags=["Quizzes"])

@router.get("/list")
async def list_quizzes(
    user: UserProfile = Depends(get_current_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
) -> Any:
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT DISTINCT q.id, q.title, q.quiz_description, q.duration_value
            FROM quizzes q
            JOIN assignments a ON a.item_type = 'quiz' AND a.item_id = q.id
            WHERE q.deleted_at IS NULL
              AND (
                a.user_id = :user_id OR (
                  a.user_id IS NULL AND a.course_id IS NOT NULL AND EXISTS (
                    SELECT 1 FROM assignments ca
                     WHERE ca.item_type='course' AND ca.item_id=a.course_id
                       AND ca.user_id=:user_id
                  )
                )
              )
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
    user: UserProfile = Depends(get_current_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
) -> Any:
    async with conn.cursor() as cursor:
        # Fetch Quiz Metadata
        await cursor.execute("""
            SELECT id, title, quiz_description, NVL(duration_value, 15)
            FROM quizzes q
            WHERE id = :quiz_id AND deleted_at IS NULL
              AND (
                    :is_admin = 1 OR q.created_by = :user_id OR EXISTS (
                        SELECT 1 FROM assignments a
                        WHERE a.item_type='quiz' AND a.item_id=q.id
                          AND (
                            a.user_id=:user_id OR (
                              a.user_id IS NULL AND a.course_id IS NOT NULL AND EXISTS (
                                SELECT 1 FROM assignments ca
                                 WHERE ca.item_type='course' AND ca.item_id=a.course_id
                                   AND ca.user_id=:user_id
                              )
                            )
                          )
                    )
              )
        """, quiz_id=quiz_id, user_id=user.id, is_admin=int(user.role == "admin"))
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
    user: UserProfile = Depends(get_current_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
) -> Any:
    quiz_id = payload.get("quiz_id")
    user_answers = payload.get("answers", {}) # Map of str(question_id) -> int(option_id)

    if not quiz_id:
        raise HTTPException(status_code=400, detail="quiz_id is required")

    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT q.allows_retake,
                   (SELECT COUNT(*) FROM quiz_attempts qa
                    WHERE qa.quiz_id=q.id AND qa.user_id=:user_id)
            FROM quizzes q
            WHERE q.id=:quiz_id AND q.deleted_at IS NULL
              AND EXISTS (
                    SELECT 1 FROM assignments a
                     WHERE a.item_type='quiz' AND a.item_id=q.id
                       AND (
                         a.user_id=:user_id OR (
                           a.user_id IS NULL AND a.course_id IS NOT NULL AND EXISTS (
                             SELECT 1 FROM assignments ca
                              WHERE ca.item_type='course' AND ca.item_id=a.course_id
                                AND ca.user_id=:user_id
                           )
                         )
                       )
              )
        """, quiz_id=quiz_id, user_id=user.id)
        access = await cursor.fetchone()
        if not access:
            raise HTTPException(status_code=403, detail="Quiz is not assigned to this user")
        if int(access[1] or 0) > 0 and not bool(access[0]):
            raise HTTPException(status_code=409, detail="This quiz does not allow another attempt")

        await cursor.execute("""
            SELECT q.id, o.id, o.is_correct
            FROM questions q
            JOIN options o ON o.question_id = q.id
            WHERE q.quiz_id = :quiz_id AND q.deleted_at IS NULL
        """, quiz_id=quiz_id)
        option_rows = await cursor.fetchall()
        valid_options = {(str(r[0]), int(r[1])) for r in option_rows}
        correct_map = {str(r[0]): int(r[1]) for r in option_rows if int(r[2] or 0) == 1}
        total_questions = len(correct_map)
        if total_questions == 0:
            raise HTTPException(status_code=409, detail="Quiz has no answerable questions")

        normalized_answers: Dict[str, int] = {}
        try:
            normalized_answers = {str(question_id): int(option_id) for question_id, option_id in user_answers.items()}
        except (TypeError, ValueError):
            raise HTTPException(status_code=400, detail="Answers must map question IDs to option IDs")
        if any((question_id, option_id) not in valid_options for question_id, option_id in normalized_answers.items()):
            raise HTTPException(status_code=400, detail="One or more selected options do not belong to the quiz question")

        score = 0
        for q_id_str, selected_opt in normalized_answers.items():
            if correct_map.get(q_id_str) == selected_opt:
                score += 1

        pct = (score / total_questions * 100) if total_questions > 0 else 0
        passed = pct >= 60.0

        attempt_id_var = cursor.var(oracledb.NUMBER)
        await cursor.execute("""
            INSERT INTO quiz_attempts (user_id, quiz_id, score, total, start_time, end_time)
            VALUES (:user_id, :quiz_id, :score, :total, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            RETURNING id INTO :attempt_id
        """, user_id=user.id, quiz_id=quiz_id, score=score, total=total_questions,
             attempt_id=attempt_id_var)
        attempt_id = int(attempt_id_var.getvalue()[0])
        for question_id, option_id in normalized_answers.items():
            await cursor.execute("""
                INSERT INTO quiz_attempt_answers
                    (attempt_id, question_id, selected_option_id, is_correct)
                VALUES (:attempt_id, :question_id, :option_id, :is_correct)
            """, attempt_id=attempt_id, question_id=int(question_id), option_id=option_id,
                 is_correct=int(correct_map.get(question_id) == option_id))
        xp_earned = score * 10 if passed else 0
        if xp_earned:
            await cursor.execute("""
                INSERT INTO xp_transactions
                    (user_id,type,points,reference_id,description,created_at)
                VALUES (:user_id,'quiz',:points,:attempt_id,:description,SYSTIMESTAMP)
            """, user_id=user.id, points=xp_earned, attempt_id=attempt_id,
                 description=f"Quiz completed: {quiz_id}")
        await conn.commit()

        return {
            "success": True,
            "score": score,
            "total": total_questions,
            "percentage": round(pct, 1),
            "passed": passed,
            "attempt_id": attempt_id,
            "xp_earned": xp_earned,
            "message": "Quiz completed successfully!" if passed else "Quiz completed. Keep reviewing to improve!"
        }
