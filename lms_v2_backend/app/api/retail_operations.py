from typing import Any

import oracledb
from fastapi import APIRouter, Depends

from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile


router = APIRouter(prefix="/operations", tags=["Retail Operations"])


@router.get("/capabilities")
async def capabilities(user: UserProfile = Depends(get_current_user)) -> dict[str, Any]:
    is_lead = user.role in {"trainer", "area_manager", "admin"}
    return {
        "version": 1,
        "modules": [
            {"key": "learning", "label": "Learning & certification", "enabled": True},
            {"key": "tasks", "label": "Tasks & evidence", "enabled": True},
            {"key": "roleplays", "label": "Roleplay coaching", "enabled": True},
            {"key": "store_audits", "label": "Store audits", "enabled": is_lead, "stage": "foundation"},
            {"key": "incidents", "label": "Incidents & escalation", "enabled": is_lead, "stage": "foundation"},
            {"key": "approvals", "label": "Approvals", "enabled": is_lead, "stage": "foundation"},
        ],
    }


@router.get("/dashboard")
async def operations_dashboard(
    user: UserProfile = Depends(get_current_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection),
) -> dict[str, Any]:
    async with conn.cursor() as cursor:
        await cursor.execute(
            """
            SELECT
              (SELECT COUNT(*) FROM assignments a
                WHERE a.user_id=:user_id AND a.item_type='course') assigned_courses,
              (SELECT COUNT(*) FROM course_completions cc
                WHERE cc.user_id=:user_id) completed_courses,
              (SELECT COUNT(*) FROM assignments a JOIN operational_tasks ot ON ot.id=a.item_id
                WHERE a.user_id=:user_id AND a.item_type='task' AND NVL(ot.is_active,1)=1) assigned_tasks,
              (SELECT COUNT(*) FROM task_completions tc
                WHERE tc.user_id=:user_id AND LOWER(NVL(tc.status,'pending')) IN ('pending','submitted')) pending_tasks,
              (SELECT COUNT(*) FROM roleplay_sessions r
                WHERE r.user_id=:user_id AND LOWER(NVL(r.status,'assigned'))!='completed') open_roleplays,
              (SELECT COUNT(*) FROM notifications n
                WHERE n.user_id=:user_id AND NVL(n.is_read,0)=0) unread_notifications
            FROM dual
            """,
            user_id=user.id,
        )
        row = await cursor.fetchone()
    return {
        "scope": {"user_id": user.id, "role": user.role},
        "metrics": {
            "assigned_courses": int(row[0] or 0),
            "completed_courses": int(row[1] or 0),
            "assigned_tasks": int(row[2] or 0),
            "pending_tasks": int(row[3] or 0),
            "open_roleplays": int(row[4] or 0),
            "unread_notifications": int(row[5] or 0),
        },
        "next_actions": [
            {"label": "Continue learning", "route": "/participant/courses"},
            {"label": "Complete operational tasks", "route": "/participant/tasks"},
            {"label": "Review roleplays", "route": "/participant/roleplays"},
        ],
    }
