from fastapi import APIRouter, Depends, HTTPException
from app.core.security import get_current_user
from app.schemas.user import UserProfile

router = APIRouter()

@router.post("/daily_booster/complete")
async def submit_booster(
    current_user: UserProfile = Depends(get_current_user),
):
    """
    Submits a daily booster completion event.
    Automatically calculates streaks natively in Oracle and triggers a live leaderboard WebSocket refresh.
    """
    raise HTTPException(status_code=410, detail="Use POST /api/v2/daily-booster with validated answers")
