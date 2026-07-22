from fastapi import APIRouter, Depends
from typing import Any
from app.core.security import require_user
from app.core.database import get_db

router = APIRouter(prefix="/leaderboard", tags=["Leaderboard"])

@router.get("")
@router.get("/")
async def get_leaderboard(user_id: int = Depends(require_user), leaderboard_type: str = "individual", season: str = "month") -> Any:
    async with get_db() as db:
        async with db.cursor() as cursor:
            if leaderboard_type == "store":
                await cursor.execute("""SELECT RANK() OVER(ORDER BY NVL(AVG(rs.observer_score),0) DESC,COUNT(rs.id) DESC),
                                      s.store_code,s.store_name,NVL(AVG(rs.observer_score),0),COUNT(rs.id)
                                      FROM stores s LEFT JOIN roleplay_sessions rs ON rs.store_code=s.store_code
                                      AND LOWER(rs.status)='completed' AND rs.observer_score IS NOT NULL
                                      GROUP BY s.store_code,s.store_name ORDER BY 1 FETCH FIRST 100 ROWS ONLY""")
                rows = await cursor.fetchall()
                return {"success": True, "leaderboard": [{"rank": r[0], "store_code": r[1], "display_name": f"{r[2]} ({r[1]})", "average_score": round(float(r[3] or 0), 2), "roleplays_submitted": r[4]} for r in rows]}
            date_clause = "AND x.created_at>=TRUNC(SYSDATE,'MM')" if season != "all" else ""
            await cursor.execute("""
                SELECT RANK() OVER(ORDER BY NVL(xp.total_xp,0) DESC,NVL(progress.completed,0) DESC),u.id,
                       NVL(up.full_name,NVL(u.full_name,u.username)),up.profile_pic,up.store_code,NVL(xp.total_xp,0),
                       NVL(progress.completed,0),NVL(attempts.taken,0)
                FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id
                LEFT JOIN (SELECT x.user_id,SUM(x.points) total_xp FROM xp_transactions x WHERE 1=1 """ + date_clause + """ GROUP BY x.user_id) xp ON xp.user_id=u.id
                LEFT JOIN (SELECT user_id,COUNT(*) completed FROM user_progress WHERE is_completed=1 GROUP BY user_id) progress ON progress.user_id=u.id
                LEFT JOIN (SELECT user_id,COUNT(*) taken FROM quiz_attempts GROUP BY user_id) attempts ON attempts.user_id=u.id
                WHERE LOWER(u.role)='participant' ORDER BY 1 FETCH FIRST 100 ROWS ONLY
            """)
            rows = await cursor.fetchall()
            
            leaderboard = [
                {
                    "rank": r[0], "user_id": r[1], "display_name": r[2], "profile_pic": r[3],
                    "store_code": r[4], "total_xp": r[5], "chapters_completed": r[6],
                    "quizzes_taken": r[7], "is_me": int(r[1]) == user_id
                }
                for r in rows
            ]
            return {"success": True, "leaderboard": leaderboard}
