from fastapi import APIRouter, Depends
from typing import Any
from app.core.security import require_user
from app.core.database import get_db

router = APIRouter(prefix="/quizzes", tags=["Quizzes"])

@router.get("/list")
async def list_quizzes(user_id: int = Depends(require_user)) -> Any:
    async with get_db() as db:
        async with db.cursor() as cursor:
            await cursor.execute("""
                SELECT DISTINCT q.id, q.title, q.quiz_description
                FROM quizzes q
                JOIN assignments a ON a.item_type = 'quiz' AND a.item_id = q.id
                WHERE a.user_id = :user_id AND q.deleted_at IS NULL
                ORDER BY q.title
            """, user_id=user_id)
            rows = await cursor.fetchall()
            
            quizzes = [{"id": r[0], "title": r[1], "description": r[2]} for r in rows]
            return {"success": True, "quizzes": quizzes}

@router.get("/detail")
async def quiz_detail(quiz_id: int, user_id: int = Depends(require_user)) -> Any:
    return {"success": True, "quiz": {"id": quiz_id, "title": "Mock Quiz Detail"}}
