from fastapi import APIRouter, Depends
import oracledb
from app.core.database import get_db_connection
from app.core.security import require_trainer_or_admin
from app.schemas.user import UserProfile
from app.schemas.analytics import AggregatedAnalyticsResponse
from app.services.analytics_service import AnalyticsService

router = APIRouter()

@router.get("/metrics", response_model=AggregatedAnalyticsResponse)
async def get_course_metrics(
    # RBAC: Dependency enforces that only Trainers and Admins can hit this endpoint
    current_user: UserProfile = Depends(require_trainer_or_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    """
    Returns aggregated course metrics computed directly in the Oracle Autonomous DB.
    Authorized for Trainers and Admins only.
    """
    service = AnalyticsService(conn)
    metrics = await service.get_course_metrics()
    
    return AggregatedAnalyticsResponse(
        success=True,
        metrics=metrics
    )
