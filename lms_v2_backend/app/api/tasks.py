from datetime import datetime
from io import BytesIO
from pathlib import Path
from uuid import uuid4
from zoneinfo import ZoneInfo

import oracledb
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import FileResponse, RedirectResponse
from PIL import Image, ImageDraw, ImageFont
from pydantic import BaseModel, Field

from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile

router = APIRouter()
UPLOAD_ROOT = Path("/home/ubuntu/lms_uploads/tasks")


class TaskCreateInput(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=4000)
    verification_type: str = Field(pattern="^(photo|text)$")
    photo_source: str = Field(default="any", pattern="^(any|camera)$")
    user_ids: list[int] = Field(default_factory=list)
    store_codes: list[str] = Field(default_factory=list)
    manager_names: list[str] = Field(default_factory=list)


class TextSubmissionInput(BaseModel):
    text_response: str = Field(min_length=1, max_length=4000)


class ReviewInput(BaseModel):
    status: str = Field(pattern="^(approved|rejected)$")


async def require_task_manager(current_user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if current_user.role not in ("trainer", "admin", "area_manager"):
        raise HTTPException(403, "Requires trainer, admin, or area-manager privileges")
    return current_user


async def require_task_learner(current_user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if current_user.role not in ("participant", "area_manager", "admin"):
        raise HTTPException(403, "Requires learner privileges")
    return current_user


async def _manager_team_ids(cursor, manager_id: int) -> set[int]:
    await cursor.execute("""
        SELECT DISTINCT id FROM (
            SELECT u.id,u.role,up.reporting_manager_id
            FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id
            START WITH up.reporting_manager_id=:manager_id
            CONNECT BY NOCYCLE PRIOR u.id=up.reporting_manager_id
        ) WHERE LOWER(role)='participant'
    """, manager_id=manager_id)
    return {int(row[0]) for row in await cursor.fetchall()}


async def _eligible_participants(cursor, user: UserProfile) -> list[dict]:
    params = {}
    restriction = ""
    if user.role == "area_manager":
        team = await _manager_team_ids(cursor, user.id)
        if not team:
            return []
        params = {f"team_{index}": value for index, value in enumerate(team)}
        restriction = " AND u.id IN (" + ",".join(f":team_{index}" for index in range(len(team))) + ")"
    await cursor.execute("""
        SELECT u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code,up.reporting_manager_name
        FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id
        WHERE LOWER(u.role)='participant' AND NVL(LOWER(u.status),'active')='active'
    """ + restriction + " ORDER BY NVL(up.full_name,NVL(u.full_name,u.username))", params)
    keys = ["id", "username", "full_name", "store_code", "reporting_manager_name"]
    return [dict(zip(keys, row)) for row in await cursor.fetchall()]


async def _notify(cursor, user_id: int, kind: str, title: str, message: str, task_id: int):
    await cursor.execute("""
        INSERT INTO notifications(user_id,type,title,message,link,is_read,created_at,target_type,target_id,fcm_sent)
        VALUES(:user_id,:kind,:title,:message,'/participant/tasks',0,SYSTIMESTAMP,'task',:task_id,0)
    """, user_id=user_id, kind=kind, title=title, message=message, task_id=task_id)


async def _assert_assigned_task(cursor, task_id: int, user_id: int):
    await cursor.execute("""
        SELECT ot.id,ot.verification_type,ot.photo_source
        FROM operational_tasks ot JOIN assignments a ON a.item_type='task' AND a.item_id=ot.id
        WHERE ot.id=:task_id AND a.user_id=:user_id AND NVL(ot.is_active,1)=1
    """, task_id=task_id, user_id=user_id)
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(404, "Assigned active task not found")
    return row


async def _upsert_completion(cursor, user_id: int, task_id: int, image_url: str | None, text_response: str | None):
    await cursor.execute("SELECT id FROM task_completions WHERE user_id=:user_id AND task_id=:task_id ORDER BY id DESC FETCH FIRST 1 ROWS ONLY", user_id=user_id, task_id=task_id)
    row = await cursor.fetchone()
    if row:
        await cursor.execute("""UPDATE task_completions SET image_url=:image_url,text_response=:text_response,
                                      status='pending_review',submitted_at=SYSTIMESTAMP WHERE id=:completion_id""",
                             image_url=image_url, text_response=text_response, completion_id=row[0])
        return int(row[0])
    out_id = cursor.var(oracledb.NUMBER)
    await cursor.execute("""INSERT INTO task_completions(user_id,task_id,image_url,text_response,status,submitted_at)
                          VALUES(:user_id,:task_id,:image_url,:text_response,'pending_review',SYSTIMESTAMP)
                          RETURNING id INTO :out_id""",
                         user_id=user_id, task_id=task_id, image_url=image_url, text_response=text_response, out_id=out_id)
    return int(out_id.getvalue()[0])


@router.get("/trainer/task-options")
async def task_options(current_user: UserProfile = Depends(require_task_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        participants = await _eligible_participants(cursor, current_user)
        return {
            "participants": participants,
            "store_codes": sorted({p["store_code"] for p in participants if p["store_code"]}),
            "manager_names": sorted({p["reporting_manager_name"] for p in participants if p["reporting_manager_name"]}),
        }


@router.get("/trainer/tasks")
async def trainer_tasks(current_user: UserProfile = Depends(require_task_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        params = {}
        restriction = ""
        if current_user.role == "area_manager":
            restriction = " WHERE ot.created_by=:creator_id"
            params["creator_id"] = current_user.id
        await cursor.execute("""
            SELECT ot.id,ot.title,ot.description,ot.verification_type,ot.photo_source,ot.is_active,
                   ot.created_at,ot.created_by,ot.creator_role,COUNT(DISTINCT a.user_id)
            FROM operational_tasks ot LEFT JOIN assignments a ON a.item_type='task' AND a.item_id=ot.id
        """ + restriction + " GROUP BY ot.id,ot.title,ot.description,ot.verification_type,ot.photo_source,ot.is_active,ot.created_at,ot.created_by,ot.creator_role ORDER BY ot.created_at DESC,ot.id DESC", params)
        keys = ["id","title","description","verification_type","photo_source","is_active","created_at","created_by","creator_role","assignment_count"]
        tasks = [dict(zip(keys, row)) for row in await cursor.fetchall()]

        completion_params = {}
        completion_restriction = " WHERE LOWER(tc.status)='pending_review'"
        if current_user.role == "area_manager":
            team = await _manager_team_ids(cursor, current_user.id)
            team_params = {f"team_{index}": value for index, value in enumerate(team)}
            completion_params.update(team_params)
            clauses = ["ot.created_by=:creator_id"]
            completion_params["creator_id"] = current_user.id
            if team:
                clauses.append("tc.user_id IN (" + ",".join(f":team_{index}" for index in range(len(team))) + ")")
            completion_restriction += " AND (" + " OR ".join(clauses) + ")"
        await cursor.execute("""
            SELECT tc.id,tc.user_id,tc.task_id,tc.image_url,tc.text_response,tc.status,tc.submitted_at,
                   ot.title,u.username,NVL(up.full_name,NVL(u.full_name,u.username))
            FROM task_completions tc JOIN operational_tasks ot ON ot.id=tc.task_id
            JOIN users u ON u.id=tc.user_id LEFT JOIN user_profiles up ON up.user_id=u.id
        """ + completion_restriction + " ORDER BY tc.submitted_at,tc.id", completion_params)
        completion_keys = ["id","user_id","task_id","image_url","text_response","status","submitted_at","task_title","username","full_name"]
        completions = [dict(zip(completion_keys, row)) for row in await cursor.fetchall()]
        return {"tasks": tasks, "pending_completions": completions}


@router.post("/trainer/tasks", status_code=201)
async def create_task(body: TaskCreateInput, current_user: UserProfile = Depends(require_task_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        participants = await _eligible_participants(cursor, current_user)
        by_id = {int(item["id"]): item for item in participants}
        selected = {user_id for user_id in body.user_ids if user_id in by_id}
        selected.update(int(item["id"]) for item in participants if item["store_code"] in body.store_codes)
        selected.update(int(item["id"]) for item in participants if item["reporting_manager_name"] in body.manager_names)
        if not selected:
            raise HTTPException(422, "Select at least one permitted participant, store, or manager")
        out_id = cursor.var(oracledb.NUMBER)
        await cursor.execute("""
            INSERT INTO operational_tasks(title,description,verification_type,photo_source,is_active,created_by,creator_role,created_at)
            VALUES(:title,:description,:verification_type,:photo_source,1,:created_by,:creator_role,SYSTIMESTAMP)
            RETURNING id INTO :out_id
        """, title=body.title, description=body.description, verification_type=body.verification_type,
             photo_source=body.photo_source, created_by=current_user.id, creator_role=current_user.role, out_id=out_id)
        task_id = int(out_id.getvalue()[0])
        for user_id in selected:
            await cursor.execute("INSERT INTO assignments(item_type,item_id,user_id,assigned_date) VALUES('task',:task_id,:user_id,SYSTIMESTAMP)", task_id=task_id, user_id=user_id)
            await _notify(cursor, user_id, "task_assigned", "New Task Assigned", f'You have been assigned: "{body.title}"', task_id)
        await conn.commit()
        return {"id": task_id, "assigned": len(selected), "message": "Task created and assigned"}


@router.delete("/trainer/tasks/{task_id}")
async def delete_task(task_id: int, current_user: UserProfile = Depends(require_task_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT created_by FROM operational_tasks WHERE id=:task_id", task_id=task_id)
        row = await cursor.fetchone()
        if not row: raise HTTPException(404, "Task not found")
        if current_user.role == "area_manager" and row[0] != current_user.id:
            raise HTTPException(403, "You can only delete tasks you created")
        await cursor.execute("DELETE FROM task_completions WHERE task_id=:task_id", task_id=task_id)
        await cursor.execute("DELETE FROM assignments WHERE item_type='task' AND item_id=:task_id", task_id=task_id)
        await cursor.execute("DELETE FROM operational_tasks WHERE id=:task_id", task_id=task_id)
        await conn.commit(); return {"message": "Task deleted"}


@router.post("/trainer/task-completions/{completion_id}/review")
async def review_completion(completion_id: int, body: ReviewInput, current_user: UserProfile = Depends(require_task_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT tc.user_id,tc.task_id,ot.title,ot.created_by FROM task_completions tc
                              JOIN operational_tasks ot ON ot.id=tc.task_id WHERE tc.id=:completion_id""", completion_id=completion_id)
        row = await cursor.fetchone()
        if not row: raise HTTPException(404, "Task completion not found")
        if current_user.role == "area_manager":
            team = await _manager_team_ids(cursor, current_user.id)
            if row[3] != current_user.id and int(row[0]) not in team:
                raise HTTPException(403, "You do not manage this task completion")
        await cursor.execute("UPDATE task_completions SET status=:status WHERE id=:completion_id", status=body.status, completion_id=completion_id)
        kind = "task_approved" if body.status == "approved" else "task_rejected"
        title = "Task Verification Approved" if body.status == "approved" else "Task Verification Rejected"
        await _notify(cursor, int(row[0]), kind, title, f'Your submission for "{row[2]}" was {body.status}.', int(row[1]))
        await conn.commit(); return {"message": f"Task completion {body.status}"}


@router.get("/tasks/list")
async def participant_tasks(current_user: UserProfile = Depends(require_task_learner), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT ot.id,ot.title,ot.description,ot.verification_type,ot.photo_source,
                   NVL(tc.status,'pending'),tc.id,tc.image_url,tc.text_response,tc.submitted_at,a.assigned_date
            FROM operational_tasks ot JOIN assignments a ON a.item_type='task' AND a.item_id=ot.id AND a.user_id=:user_id
            LEFT JOIN task_completions tc ON tc.task_id=ot.id AND tc.user_id=:user_id
            WHERE NVL(ot.is_active,1)=1 ORDER BY a.assigned_date DESC,ot.created_at DESC
        """, user_id=current_user.id)
        keys = ["id","title","description","verification_type","photo_source","status","completion_id","image_url","text_response","submitted_at","assigned_date"]
        return {"tasks": [dict(zip(keys, row)) for row in await cursor.fetchall()]}


@router.post("/tasks/{task_id}/submit/text")
async def submit_task_text(task_id: int, body: TextSubmissionInput, current_user: UserProfile = Depends(require_task_learner), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        task = await _assert_assigned_task(cursor, task_id, current_user.id)
        if str(task[1]).lower() != "text": raise HTTPException(422, "This task requires photo verification")
        completion_id = await _upsert_completion(cursor, current_user.id, task_id, None, body.text_response.strip())
        await conn.commit(); return {"completion_id": completion_id, "message": "Task response submitted"}


@router.post("/tasks/{task_id}/submit/photo")
async def submit_task_photo(task_id: int, request: Request, current_user: UserProfile = Depends(require_task_learner), conn=Depends(get_db_connection)):
    content_type = request.headers.get("content-type", "").split(";", 1)[0].lower()
    if content_type not in ("image/jpeg", "image/png"):
        raise HTTPException(415, "Only JPEG and PNG evidence is accepted")
    data = await request.body()
    if not data or len(data) > 5 * 1024 * 1024:
        raise HTTPException(413, "Evidence image must be between 1 byte and 5 MB")
    async with conn.cursor() as cursor:
        task = await _assert_assigned_task(cursor, task_id, current_user.id)
        if str(task[1]).lower() != "photo": raise HTTPException(422, "This task requires text verification")
        try:
            image = Image.open(BytesIO(data)); image.verify()
            image = Image.open(BytesIO(data)).convert("RGB")
        except Exception as exc:
            raise HTTPException(422, "Invalid image data") from exc
        draw = ImageDraw.Draw(image)
        stamp = datetime.now(ZoneInfo("Asia/Kolkata")).strftime("%d %b %Y %I:%M %p IST")
        font = ImageFont.load_default()
        box = draw.textbbox((0, 0), stamp, font=font)
        x = max(5, image.width - (box[2] - box[0]) - 15); y = max(5, image.height - (box[3] - box[1]) - 15)
        draw.text((x + 1, y + 1), stamp, fill="black", font=font); draw.text((x, y), stamp, fill=(249, 115, 22), font=font)
        UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
        filename = f"verification_{current_user.id}_{task_id}_{uuid4().hex}.jpg"
        relative_path = f"tasks/{filename}"; image.save(UPLOAD_ROOT / filename, "JPEG", quality=90)
        completion_id = await _upsert_completion(cursor, current_user.id, task_id, relative_path, None)
        await conn.commit(); return {"completion_id": completion_id, "message": "Task photo submitted"}


@router.get("/tasks/evidence/{completion_id}")
async def task_evidence(completion_id: int, current_user: UserProfile = Depends(get_current_user), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT tc.user_id,tc.image_url,ot.created_by
            FROM task_completions tc JOIN operational_tasks ot ON ot.id=tc.task_id
            WHERE tc.id=:completion_id
        """, completion_id=completion_id)
        row = await cursor.fetchone()
        if not row or not row[1]: raise HTTPException(404, "Task evidence not found")
        permitted = current_user.role in ("trainer", "admin") or int(row[0]) == current_user.id
        if current_user.role == "area_manager":
            permitted = int(row[2]) == current_user.id or int(row[0]) in await _manager_team_ids(cursor, current_user.id)
        if not permitted:
            raise HTTPException(403, "Not permitted to view this evidence")
        value = str(row[1])
        if value.startswith(("http://", "https://")): return RedirectResponse(value)
        path = (Path("/home/ubuntu/lms_uploads") / value).resolve()
        base = Path("/home/ubuntu/lms_uploads").resolve()
        if base not in path.parents or not path.is_file(): raise HTTPException(404, "Evidence file missing")
        return FileResponse(path, media_type="image/jpeg")
