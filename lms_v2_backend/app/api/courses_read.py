from fastapi import APIRouter, Depends
from typing import Any
from app.core.security import require_user
from app.core.database import get_db

router = APIRouter(prefix="/courses", tags=["Courses"])

@router.get("/list")
async def list_courses(user_id: int = Depends(require_user)) -> Any:
    async with get_db() as db:
        async with db.cursor() as cursor:
            await cursor.execute("""
                SELECT c.id, c.title, c.description, c.image_url, 
                       NVL(up.progress_percent, 0) as progress_percent
                FROM courses c
                LEFT JOIN user_progress up ON c.id = up.course_id AND up.user_id = :user_id
                WHERE c.status = 'published'
                ORDER BY c.created_at DESC
            """, user_id=user_id)
            rows = await cursor.fetchall()
            
            courses = [
                {
                    "id": row[0],
                    "title": row[1],
                    "description": row[2],
                    "image_url": row[3],
                    "progress_percent": row[4]
                }
                for row in rows
            ]
            return {"success": True, "courses": courses}

@router.get("/detail")
async def course_detail(course_id: int, user_id: int = Depends(require_user)) -> Any:
    # Full detail hydration will be expanded later
    return {"success": True, "course": {"id": course_id, "title": "Mock Course Detail"}}
