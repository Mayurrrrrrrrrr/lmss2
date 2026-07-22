from fastapi import APIRouter, Depends
import oracledb
from app.core.database import get_db_connection
from app.core.security import require_manager
from app.schemas.user import UserProfile
from app.schemas.manager import ManagerDashboardResponse, StoreTelemetry

router = APIRouter()

@router.get("/dashboard", response_model=ManagerDashboardResponse)
async def get_manager_dashboard(
    current_user: UserProfile = Depends(require_manager),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    """
    Replaces /area_manager/dashboard.php
    Consolidates heavy N+1 PHP loops into a unified Oracle aggregation query to calculate compliance telemetry.
    """
    async with conn.cursor() as cursor:
        # Optimized Oracle aggregation grouping by store mapped to this specific manager
        query = """
            SELECT 
                s.store_code,
                s.store_name,
                COUNT(DISTINCT u.id) as participants,
                SUM(CASE WHEN tc.status = 'approved' THEN 1 ELSE 0 END) as approved_count,
                SUM(CASE WHEN tc.status = 'pending_review' THEN 1 ELSE 0 END) as pending_count,
                COUNT(DISTINCT ot.id) as tasks_count
            FROM stores s
            LEFT JOIN area_manager_stores ams ON s.id = ams.store_id
            LEFT JOIN user_profiles up ON s.store_code = up.store_code
            LEFT JOIN users u ON up.user_id = u.id AND u.role = 'participant'
            LEFT JOIN operational_tasks ot ON ot.is_active = 1 AND (ot.store_id = s.id OR ot.store_id IS NULL)
            LEFT JOIN task_completions tc ON tc.task_id = ot.id AND tc.user_id = u.id
            WHERE ams.manager_id = :manager_id OR up.reporting_manager_id = :manager_id
            GROUP BY s.store_code, s.store_name
        """
        await cursor.execute(query, manager_id=current_user.id)
        rows = await cursor.fetchall()
        
        stores = []
        tot_parts = 0
        tot_appr = 0
        tot_pend = 0

        for r in rows:
            store_code, store_name, parts, appr, pend, t_count = r
            parts = parts or 0
            appr = appr or 0
            pend = pend or 0
            t_count = t_count or 0
            
            tot_parts += parts
            tot_appr += appr
            tot_pend += pend
            
            expected = parts * t_count
            comp_rate = round((appr / expected * 100), 1) if expected > 0 else 100.0

            stores.append(StoreTelemetry(
                store_code=store_code,
                store_name=store_name,
                participants_count=parts,
                compliance_rate=comp_rate,
                approved_verifications=appr,
                pending_verifications=pend
            ))

        return ManagerDashboardResponse(
            total_participants=tot_parts,
            total_approved=tot_appr,
            total_pending=tot_pend,
            stores=stores
        )
