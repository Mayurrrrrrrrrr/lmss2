from fastapi import APIRouter, Depends
import oracledb
from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile
from app.services.gamification_service import GamificationService

router = APIRouter()

@router.post("/daily_booster/complete")
async def submit_booster(
    current_user: UserProfile = Depends(get_current_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    """
    Submits a daily booster completion event.
    Automatically calculates streaks natively in Oracle and triggers a live leaderboard WebSocket refresh.
    """
    service = GamificationService(conn)
    result = await service.complete_daily_booster(current_user.id)
    return result
