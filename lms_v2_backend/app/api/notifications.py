from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile
from app.api.tasks import _eligible_participants

router = APIRouter()

class BroadcastInput(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    message: str = Field(min_length=1, max_length=4000)
    type: str = Field(default="system", pattern="^(system|nudge|badge_earned|at_risk)$")
    image_path: str | None = Field(default=None, max_length=4000)
    scheduled_at: datetime | None = None
    user_ids: list[int] = Field(default_factory=list)
    store_codes: list[str] = Field(default_factory=list)
    manager_names: list[str] = Field(default_factory=list)
    all_participants: bool = False

async def require_notification_manager(user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if user.role not in ("trainer", "admin", "area_manager"):
        raise HTTPException(403, "Requires trainer, admin, or area-manager privileges")
    return user

@router.get("/trainer/notification-options")
async def notification_options(user: UserProfile = Depends(require_notification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        participants = await _eligible_participants(cursor, user)
        return {"participants": participants, "store_codes": sorted({p["store_code"] for p in participants if p["store_code"]}), "manager_names": sorted({p["reporting_manager_name"] for p in participants if p["reporting_manager_name"]})}

@router.get("/trainer/notifications")
async def sent_notifications(user: UserProfile = Depends(require_notification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT title,message,type,image_path,created_at,scheduled_at,COUNT(DISTINCT user_id),SUM(CASE WHEN is_read=1 THEN 1 ELSE 0 END)
                              FROM notifications GROUP BY title,message,type,image_path,created_at,scheduled_at
                              ORDER BY NVL(scheduled_at,created_at) DESC FETCH FIRST 50 ROWS ONLY""")
        keys = ["title","message","type","image_path","created_at","scheduled_at","recipients_count","read_count"]
        return {"history": [dict(zip(keys, row)) for row in await cursor.fetchall()]}

@router.post("/trainer/notifications", status_code=201)
async def broadcast_notification(body: BroadcastInput, user: UserProfile = Depends(require_notification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        participants = await _eligible_participants(cursor, user); permitted = {int(p["id"]): p for p in participants}
        selected = set(permitted) if body.all_participants else {uid for uid in body.user_ids if uid in permitted}
        selected.update(int(p["id"]) for p in participants if p["store_code"] in body.store_codes)
        selected.update(int(p["id"]) for p in participants if p["reporting_manager_name"] in body.manager_names)
        if not selected: raise HTTPException(422, "Select at least one permitted recipient audience")
        scheduled = body.scheduled_at
        comparable = scheduled.replace(tzinfo=scheduled.tzinfo or timezone.utc) if scheduled else None
        is_future = comparable is not None and comparable > datetime.now(timezone.utc)
        database_schedule = comparable.astimezone(timezone.utc).replace(tzinfo=None) if comparable else None
        for user_id in selected:
            await cursor.execute("""INSERT INTO notifications(user_id,type,title,message,link,is_read,created_at,scheduled_at,fcm_sent,target_type,image_path)
                                  VALUES(:user_id,:type,:title,:message,'/participant/notifications',0,SYSTIMESTAMP,:scheduled_at,:fcm_sent,'broadcast',:image_path)""",
                                 user_id=user_id, type=body.type, title=body.title, message=body.message, scheduled_at=database_schedule, fcm_sent=0 if is_future else 1, image_path=body.image_path)
        await conn.commit(); return {"recipients": len(selected), "scheduled": is_future}

@router.post("/trainer/assignments/{assignment_id}/nudge")
async def nudge_assignment(assignment_id: int, user: UserProfile = Depends(require_notification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT a.user_id,a.item_type,a.item_id,CASE WHEN a.item_type='course' THEN c.title ELSE q.title END
                              FROM assignments a LEFT JOIN courses c ON c.id=a.item_id AND a.item_type='course'
                              LEFT JOIN quizzes q ON q.id=a.item_id AND a.item_type='quiz' WHERE a.id=:assignment_id""", assignment_id=assignment_id)
        row = await cursor.fetchone()
        if not row: raise HTTPException(404, "Assignment not found")
        if int(row[0]) not in {int(p["id"]) for p in await _eligible_participants(cursor, user)}: raise HTTPException(403, "Learner is outside your permitted audience")
        item_type = str(row[1]); title = row[3] or item_type
        await cursor.execute("""INSERT INTO notifications(user_id,type,title,message,link,is_read,created_at,fcm_sent,target_type,target_id)
                              VALUES(:user_id,:type,:heading,:message,:link,0,SYSTIMESTAMP,1,:target_type,:target_id)""",
                             user_id=row[0], type=f"{item_type}_nudge", heading=f"{item_type.title()} Reminder", message=f'Friendly reminder to complete your assigned {item_type}: "{title}"', link=f"/participant/{'courses' if item_type == 'course' else 'quizzes'}", target_type=item_type, target_id=row[2])
        await conn.commit(); return {"success": True}

@router.get("/notifications")
async def my_notifications(user: UserProfile = Depends(get_current_user), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT id,type,title,message,link,is_read,created_at,scheduled_at,target_type,target_id,image_path
                              FROM notifications WHERE user_id=:user_id AND (scheduled_at IS NULL OR scheduled_at<=SYSTIMESTAMP)
                              ORDER BY NVL(scheduled_at,created_at) DESC FETCH FIRST 50 ROWS ONLY""", user_id=user.id)
        keys = ["id","type","title","message","link","is_read","created_at","scheduled_at","target_type","target_id","image_path"]
        rows = [dict(zip(keys, row)) for row in await cursor.fetchall()]
        return {"unread_count": sum(1 for row in rows if not row["is_read"]), "notifications": rows}

class MarkReadInput(BaseModel):
    id: int | None = None
    all: bool = False

@router.post("/notifications/read")
async def mark_notifications_read(body: MarkReadInput, user: UserProfile = Depends(get_current_user), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        if body.all or body.id is None: await cursor.execute("UPDATE notifications SET is_read=1 WHERE user_id=:user_id", user_id=user.id)
        else: await cursor.execute("UPDATE notifications SET is_read=1 WHERE id=:id AND user_id=:user_id", id=body.id, user_id=user.id)
        await conn.commit(); return {"success": True}

@router.get("/announcements")
async def announcements(user: UserProfile = Depends(get_current_user), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT store_code FROM user_profiles WHERE user_id=:user_id", user_id=user.id); row = await cursor.fetchone(); store_code = row[0] if row else None
        if not store_code: return {"announcements": []}
        await cursor.execute("""SELECT DISTINCT sp.id,sp.title,sp.url_slug,DBMS_LOB.SUBSTR(sp.html_content,500,1),sp.created_at
                              FROM static_pages sp WHERE sp.is_public=1 AND (sp.created_by IN (
                                SELECT ams.manager_id FROM area_manager_stores ams JOIN stores s ON s.id=ams.store_id WHERE s.store_code=:store_code
                              ) OR sp.created_by IN (SELECT reporting_manager_id FROM user_profiles WHERE store_code=:store_code AND reporting_manager_id IS NOT NULL))
                              ORDER BY sp.created_at DESC""", store_code=store_code)
        keys = ["id","title","slug","message","created_at"]
        return {"announcements": [dict(zip(keys, row)) for row in await cursor.fetchall()]}
