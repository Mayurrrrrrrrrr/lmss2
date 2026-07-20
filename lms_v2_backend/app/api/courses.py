from fastapi import APIRouter, Depends
import oracledb
from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile
from app.schemas.course import SaveProgressRequest, SaveProgressResponse
from app.services.course_service import CourseService

router = APIRouter()

@router.post("/save_progress", response_model=SaveProgressResponse)
async def save_progress(
    request: SaveProgressRequest,
    current_user: UserProfile = Depends(get_current_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    """
    Accepts tracking checkpoints from both the web interface and the mobile app.
    Validates attention span and saves progress securely in Oracle DB.
    """
    service = CourseService(conn)
    # Offload execution to the service layer
    return await service.save_progress(current_user.id, request)
