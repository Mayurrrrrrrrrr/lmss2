from fastapi import APIRouter, Depends
from typing import Any
from app.core.security import require_user
from app.core.database import get_db

router = APIRouter(prefix="/leaderboard", tags=["Leaderboard"])

@router.get("/")
async def get_leaderboard(user_id: int = Depends(require_user)) -> Any:
    async with get_db() as db:
        async with db.cursor() as cursor:
            # Optimize leaderboard with Oracle Window Functions
            await cursor.execute("""
                SELECT id as user_id, 
                       username, 
                       total_xp,
                       RANK() OVER(ORDER BY total_xp DESC) as rank
                FROM users
                WHERE total_xp > 0
                FETCH FIRST 50 ROWS ONLY
            """)
            rows = await cursor.fetchall()
            
            leaderboard = [
                {
                    "user_id": r[0],
                    "username": r[1],
                    "total_xp": r[2],
                    "rank": r[3]
                }
                for r in rows
            ]
            return {"success": True, "leaderboard": leaderboard}
