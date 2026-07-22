from typing import Literal

import oracledb
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.database import get_db_connection
from app.core.security import get_current_user, require_trainer
from app.schemas.user import UserProfile

router = APIRouter()


class RoleplayAssignmentInput(BaseModel):
    week_no: str = Field(min_length=1, max_length=50)
    day: str = Field(min_length=1, max_length=50)
    scenario_topic: str = Field(min_length=1, max_length=500)
    user_ids: list[int] = Field(default_factory=list)
    store_codes: list[str] = Field(default_factory=list)
    manager_names: list[str] = Field(default_factory=list)


class RoleplayUpdateInput(BaseModel):
    week_no: str = Field(min_length=1, max_length=50)
    day: str = Field(min_length=1, max_length=50)
    scenario_topic: str = Field(min_length=1, max_length=500)


class RoleplayEvaluationInput(BaseModel):
    observer_score: float = Field(ge=1, le=5)
    debrief_notes: str | None = Field(default=None, max_length=4000)


class RoleplaySubmissionInput(BaseModel):
    video_url: str = Field(min_length=8, max_length=2000)
    participant_remarks: str | None = Field(default=None, max_length=4000)


def _roleplay_dict(row):
    keys = ["id","user_id","username","full_name","store_code","week_no","day","scenario_topic","jdc_name","status","video_url","observer_score","debrief_notes","participant_remarks","created_at","updated_at"]
    return dict(zip(keys, row))


async def _learner(current_user: UserProfile = Depends(get_current_user)):
    if current_user.role not in ("participant", "area_manager", "admin"):
        raise HTTPException(403, "Requires learner privileges")
    return current_user


@router.get("/trainer/roleplays")
async def trainer_roleplays(
    status: str | None = None,
    store_code: str | None = None,
    topic: str | None = None,
    page: int = Query(1, ge=1),
    limit: int = Query(100, ge=1, le=500),
    current_user: UserProfile = Depends(require_trainer),
    conn=Depends(get_db_connection),
):
    del current_user
    conditions = []
    params = {"offset": (page - 1) * limit, "limit": limit}
    if status: conditions.append("LOWER(r.status)=LOWER(:status)"); params["status"] = status
    if store_code: conditions.append("r.store_code=:store_code"); params["store_code"] = store_code
    if topic: conditions.append("LOWER(r.scenario_topic) LIKE '%'||LOWER(:topic)||'%'"); params["topic"] = topic
    where = " WHERE " + " AND ".join(conditions) if conditions else ""
    async with conn.cursor() as cursor:
        count_params = {key: value for key, value in params.items() if key not in ("offset", "limit")}
        await cursor.execute("SELECT COUNT(*) FROM roleplay_sessions r" + where, count_params)
        total = (await cursor.fetchone())[0]
        await cursor.execute("""
          SELECT r.id,r.user_id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),r.store_code,
                 r.week_no,r.day,r.scenario_topic,r.jdc_name,r.status,r.video_path,r.observer_score,
                 r.debrief_notes,r.participant_remarks,r.created_at,r.updated_at
          FROM roleplay_sessions r JOIN users u ON u.id=r.user_id
          LEFT JOIN user_profiles up ON up.user_id=u.id
        """ + where + " ORDER BY r.created_at DESC,r.id DESC OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY", params)
        return {"sessions": [_roleplay_dict(row) for row in await cursor.fetchall()], "total": total, "page": page, "limit": limit}


@router.get("/trainer/roleplay-options")
async def roleplay_options(current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    del current_user
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code,up.reporting_manager_name
                              FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id
                              WHERE LOWER(u.role)='participant' AND NVL(LOWER(u.status),'active')='active'
                              ORDER BY NVL(up.full_name,NVL(u.full_name,u.username))""")
        participants = [dict(zip(["id","username","full_name","store_code","reporting_manager_name"], row)) for row in await cursor.fetchall()]
        await cursor.execute("SELECT DISTINCT scenario_topic FROM roleplay_sessions WHERE scenario_topic IS NOT NULL ORDER BY scenario_topic")
        topics = [row[0] for row in await cursor.fetchall()]
        return {"participants": participants, "store_codes": sorted({p["store_code"] for p in participants if p["store_code"]}), "manager_names": sorted({p["reporting_manager_name"] for p in participants if p["reporting_manager_name"]}), "topics": topics}


@router.post("/trainer/roleplays/assign", status_code=201)
async def assign_roleplays(body: RoleplayAssignmentInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    del current_user
    user_ids = set(body.user_ids)
    params = {}
    filters = []
    if body.store_codes:
        params.update({f"s{i}": value for i, value in enumerate(body.store_codes)})
        filters.append("up.store_code IN (" + ",".join(f":s{i}" for i in range(len(body.store_codes))) + ")")
    if body.manager_names:
        params.update({f"m{i}": value for i, value in enumerate(body.manager_names)})
        filters.append("up.reporting_manager_name IN (" + ",".join(f":m{i}" for i in range(len(body.manager_names))) + ")")
    async with conn.cursor() as cursor:
        if filters:
            await cursor.execute("SELECT u.id FROM users u JOIN user_profiles up ON up.user_id=u.id WHERE LOWER(u.role)='participant' AND (" + " OR ".join(filters) + ")", params)
            user_ids.update(row[0] for row in await cursor.fetchall())
        if not user_ids: raise HTTPException(422, "Select at least one participant, store, or manager")
        binds = {f"u{i}": value for i, value in enumerate(user_ids)}
        await cursor.execute("""SELECT u.id,NVL(up.store_code,'N/A'),NVL(up.full_name,NVL(u.full_name,u.username))
                              FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id
                              WHERE LOWER(u.role)='participant' AND u.id IN (""" + ",".join(f":u{i}" for i in range(len(user_ids))) + ")", binds)
        participants = await cursor.fetchall()
        for user_id, store_code, full_name in participants:
            await cursor.execute("""INSERT INTO roleplay_sessions(user_id,store_code,week_no,day,scenario_topic,jdc_name,status,created_at,updated_at)
                                  VALUES(:user_id,:store_code,:week_no,:day,:topic,:jdc_name,'Assigned',SYSTIMESTAMP,SYSTIMESTAMP)""",
                                 user_id=user_id, store_code=store_code, week_no=body.week_no, day=body.day, topic=body.scenario_topic, jdc_name=full_name)
        await conn.commit()
        return {"message": "Roleplays assigned", "assigned": len(participants)}


@router.put("/trainer/roleplays/{session_id}")
async def update_roleplay(session_id: int, body: RoleplayUpdateInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    del current_user
    async with conn.cursor() as cursor:
        await cursor.execute("UPDATE roleplay_sessions SET week_no=:week_no,day=:day,scenario_topic=:topic,updated_at=SYSTIMESTAMP WHERE id=:session_id", week_no=body.week_no, day=body.day, topic=body.scenario_topic, session_id=session_id)
        if cursor.rowcount == 0: raise HTTPException(404, "Roleplay session not found")
        await conn.commit(); return {"message": "Roleplay updated"}


@router.post("/trainer/roleplays/{session_id}/evaluate")
async def evaluate_roleplay(session_id: int, body: RoleplayEvaluationInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    del current_user
    async with conn.cursor() as cursor:
        await cursor.execute("UPDATE roleplay_sessions SET observer_score=:score,debrief_notes=:notes,status='Completed',updated_at=SYSTIMESTAMP WHERE id=:session_id AND LOWER(status)='pending'", score=body.observer_score, notes=body.debrief_notes, session_id=session_id)
        if cursor.rowcount == 0: raise HTTPException(404, "Pending roleplay session not found")
        await conn.commit(); return {"message": "Evaluation saved"}


@router.delete("/trainer/roleplays/{session_id}/video")
async def remove_roleplay_video(session_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    del current_user
    async with conn.cursor() as cursor:
        await cursor.execute("UPDATE roleplay_sessions SET video_path=NULL,updated_at=SYSTIMESTAMP WHERE id=:session_id", session_id=session_id)
        if cursor.rowcount == 0: raise HTTPException(404, "Roleplay session not found")
        await conn.commit(); return {"message": "Video reference removed"}


@router.delete("/trainer/roleplays/{session_id}")
async def delete_roleplay(session_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    del current_user
    async with conn.cursor() as cursor:
        await cursor.execute("DELETE FROM roleplay_sessions WHERE id=:session_id", session_id=session_id)
        if cursor.rowcount == 0: raise HTTPException(404, "Roleplay session not found")
        await conn.commit(); return {"message": "Roleplay session deleted"}


@router.get("/roleplays/list")
async def participant_roleplays(current_user: UserProfile = Depends(_learner), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT r.id,r.user_id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),r.store_code,
                                      r.week_no,r.day,r.scenario_topic,r.jdc_name,r.status,r.video_path,r.observer_score,
                                      r.debrief_notes,r.participant_remarks,r.created_at,r.updated_at
                               FROM roleplay_sessions r JOIN users u ON u.id=r.user_id LEFT JOIN user_profiles up ON up.user_id=u.id
                               WHERE r.user_id=:user_id ORDER BY r.created_at DESC,r.id DESC""", user_id=current_user.id)
        grouped = {"assigned": [], "pending": [], "completed": []}
        for row in await cursor.fetchall():
            item = _roleplay_dict(row)
            key = str(item["status"] or "assigned").lower()
            grouped.setdefault(key, []).append(item)
        return grouped


@router.post("/roleplays/{session_id}/submit")
async def submit_roleplay(session_id: int, body: RoleplaySubmissionInput, current_user: UserProfile = Depends(_learner), conn=Depends(get_db_connection)):
    if not body.video_url.lower().startswith(("http://", "https://")):
        raise HTTPException(422, "A valid HTTP(S) video URL is required")
    async with conn.cursor() as cursor:
        await cursor.execute("""UPDATE roleplay_sessions SET video_path=:video_url,participant_remarks=:remarks,
                                      status='Pending',updated_at=SYSTIMESTAMP
                               WHERE id=:session_id AND user_id=:user_id AND LOWER(status)='assigned'""",
                             video_url=body.video_url, remarks=body.participant_remarks, session_id=session_id, user_id=current_user.id)
        if cursor.rowcount == 0: raise HTTPException(404, "Assigned roleplay session not found")
        await conn.commit(); return {"message": "Roleplay submitted", "video_url": body.video_url}
