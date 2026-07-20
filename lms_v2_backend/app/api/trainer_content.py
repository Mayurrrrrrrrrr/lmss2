from datetime import datetime, timedelta, timezone
from typing import Literal

import oracledb
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.core.database import get_db_connection
from app.core.security import require_trainer
from app.schemas.user import UserProfile


router = APIRouter()


class CourseInput(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    duration_type: Literal["No Duration", "Days", "Weeks"] = "No Duration"
    duration_value: int | None = Field(default=None, ge=1)
    assessment_q_count: int = Field(default=0, ge=0)
    assessment_score: int = Field(default=0, ge=0, le=100)
    course_badge_id: int | None = None
    thumbnail_path: str | None = None


class ModuleInput(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    sequence_order: int = Field(default=1, ge=0)


class ChapterInput(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    content_type: Literal["html", "youtube", "pdf", "word", "ppt", "txt", "video", "audio", "image"]
    content_path: str = Field(min_length=1)
    sequence_order: int = Field(default=1, ge=0)
    duration_seconds: int = Field(default=60, ge=0)


class BulkAssignmentInput(BaseModel):
    course_ids: list[int] = Field(min_length=1)
    user_ids: list[int] = Field(default_factory=list)
    store_codes: list[str] = Field(default_factory=list)
    manager_names: list[str] = Field(default_factory=list)


async def _owned_course(cursor, course_id: int, user: UserProfile):
    sql = "SELECT id, title FROM courses WHERE id=:course_id AND deleted_at IS NULL"
    params = {"course_id": course_id}
    if user.role != "admin":
        sql += " AND created_by=:owner_id"
        params["owner_id"] = user.id
    await cursor.execute(sql, params)
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(404, "Course not found or not owned by you")
    return row


async def _owned_module(cursor, module_id: int, user: UserProfile):
    sql = """
        SELECT m.id, m.course_id, m.title
        FROM modules m JOIN courses c ON c.id=m.course_id
        WHERE m.id=:module_id AND m.deleted_at IS NULL AND c.deleted_at IS NULL
    """
    params = {"module_id": module_id}
    if user.role != "admin":
        sql += " AND c.created_by=:owner_id"
        params["owner_id"] = user.id
    await cursor.execute(sql, params)
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(404, "Module not found or not owned by you")
    return row


@router.get("/courses")
async def list_courses(current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        sql = """
            SELECT c.id,c.title,c.description,c.duration_type,c.duration_value,
                   c.assessment_q_count,c.assessment_score,c.thumbnail_path,c.course_badge_id,
                   c.created_at,COUNT(DISTINCT m.id),COUNT(DISTINCT ch.id),COUNT(DISTINCT a.user_id)
            FROM courses c
            LEFT JOIN modules m ON m.course_id=c.id AND m.deleted_at IS NULL
            LEFT JOIN chapters ch ON ch.module_id=m.id AND ch.deleted_at IS NULL
            LEFT JOIN assignments a ON a.item_type='course' AND a.item_id=c.id AND a.user_id IS NOT NULL
            WHERE c.deleted_at IS NULL
        """
        params = {}
        if current_user.role != "admin":
            sql += " AND c.created_by=:owner_id"
            params["owner_id"] = current_user.id
        sql += " GROUP BY c.id,c.title,c.description,c.duration_type,c.duration_value,c.assessment_q_count,c.assessment_score,c.thumbnail_path,c.course_badge_id,c.created_at ORDER BY c.id DESC"
        await cursor.execute(sql, params)
        rows = await cursor.fetchall()
        keys = ["id","title","description","duration_type","duration_value","assessment_q_count","assessment_score","thumbnail_path","course_badge_id","created_at","module_count","chapter_count","participant_count"]
        return {"courses": [dict(zip(keys, row)) for row in rows]}


@router.post("/courses", status_code=201)
async def create_course(body: CourseInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        out_id = cursor.var(oracledb.NUMBER)
        await cursor.execute("""
            INSERT INTO courses(title,description,duration_type,duration_value,assessment_q_count,
                                assessment_score,thumbnail_path,created_by,course_badge_id)
            VALUES(:title,:description,:duration_type,:duration_value,:assessment_q_count,
                   :assessment_score,:thumbnail_path,:created_by,:course_badge_id)
            RETURNING id INTO :out_id
        """, {**body.model_dump(), "created_by": current_user.id, "out_id": out_id})
        await conn.commit()
        return {"id": int(out_id.getvalue()[0]), "message": "Course created"}


@router.put("/courses/{course_id}")
async def update_course(course_id: int, body: CourseInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_course(cursor, course_id, current_user)
        await cursor.execute("""
            UPDATE courses SET title=:title,description=:description,duration_type=:duration_type,
              duration_value=:duration_value,assessment_q_count=:assessment_q_count,
              assessment_score=:assessment_score,thumbnail_path=:thumbnail_path,course_badge_id=:course_badge_id
            WHERE id=:course_id
        """, {**body.model_dump(), "course_id": course_id})
        await conn.commit()
        return {"message": "Course updated"}


@router.delete("/courses/{course_id}")
async def delete_course(course_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_course(cursor, course_id, current_user)
        await cursor.execute("UPDATE courses SET deleted_at=SYSTIMESTAMP WHERE id=:course_id", course_id=course_id)
        await conn.commit()
        return {"message": "Course deleted"}


@router.post("/courses/{course_id}/duplicate", status_code=201)
async def duplicate_course(course_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_course(cursor, course_id, current_user)
        await cursor.execute("""SELECT title,description,duration_type,duration_value,assessment_q_count,
                                        assessment_score,course_badge_id,thumbnail_path FROM courses WHERE id=:course_id""", course_id=course_id)
        source = await cursor.fetchone()
        new_course = cursor.var(oracledb.NUMBER)
        await cursor.execute("""
          INSERT INTO courses(title,description,created_by,duration_type,duration_value,assessment_q_count,
                              assessment_score,course_badge_id,thumbnail_path)
          VALUES(:title,:description,:owner_id,:duration_type,:duration_value,:assessment_q_count,
                 :assessment_score,:course_badge_id,:thumbnail_path)
          RETURNING id INTO :out_id
        """, title=source[0] + " (Copy)", description=source[1], owner_id=current_user.id,
             duration_type=source[2], duration_value=source[3], assessment_q_count=source[4],
             assessment_score=source[5], course_badge_id=source[6], thumbnail_path=source[7], out_id=new_course)
        new_id = int(new_course.getvalue()[0])
        await cursor.execute("SELECT id,title,sequence_order FROM modules WHERE course_id=:course_id AND deleted_at IS NULL ORDER BY sequence_order,id", course_id=course_id)
        for old_module_id, title, sequence in await cursor.fetchall():
            new_module = cursor.var(oracledb.NUMBER)
            await cursor.execute("INSERT INTO modules(course_id,title,sequence_order) VALUES(:course_id,:title,:seq) RETURNING id INTO :out_id", course_id=new_id, title=title, seq=sequence, out_id=new_module)
            await cursor.execute("""
              INSERT INTO chapters(module_id,title,content_type,content_path,sequence_order,ai_summary,duration_seconds)
              SELECT :new_module,title,content_type,content_path,sequence_order,ai_summary,duration_seconds
              FROM chapters WHERE module_id=:old_module AND deleted_at IS NULL
            """, new_module=int(new_module.getvalue()[0]), old_module=old_module_id)
        await conn.commit()
        return {"id": new_id, "message": "Course duplicated"}


@router.get("/courses/{course_id}/modules")
async def list_modules(course_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_course(cursor, course_id, current_user)
        await cursor.execute("""
          SELECT m.id,m.title,m.sequence_order,COUNT(ch.id)
          FROM modules m LEFT JOIN chapters ch ON ch.module_id=m.id AND ch.deleted_at IS NULL
          WHERE m.course_id=:course_id AND m.deleted_at IS NULL
          GROUP BY m.id,m.title,m.sequence_order ORDER BY m.sequence_order,m.id
        """, course_id=course_id)
        return {"modules": [{"id":r[0],"title":r[1],"sequence_order":r[2],"chapter_count":r[3]} for r in await cursor.fetchall()]}


@router.post("/courses/{course_id}/modules", status_code=201)
async def create_module(course_id: int, body: ModuleInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_course(cursor, course_id, current_user)
        out_id = cursor.var(oracledb.NUMBER)
        await cursor.execute("INSERT INTO modules(course_id,title,sequence_order) VALUES(:course_id,:title,:sequence_order) RETURNING id INTO :out_id", course_id=course_id, out_id=out_id, **body.model_dump())
        await conn.commit()
        return {"id": int(out_id.getvalue()[0]), "message": "Module created"}


@router.put("/modules/{module_id}")
async def update_module(module_id: int, body: ModuleInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_module(cursor, module_id, current_user)
        await cursor.execute("UPDATE modules SET title=:title,sequence_order=:sequence_order WHERE id=:module_id", module_id=module_id, **body.model_dump())
        await conn.commit()
        return {"message": "Module updated"}


@router.delete("/modules/{module_id}")
async def delete_module(module_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_module(cursor, module_id, current_user)
        await cursor.execute("UPDATE modules SET deleted_at=SYSTIMESTAMP WHERE id=:module_id", module_id=module_id)
        await conn.commit()
        return {"message": "Module deleted"}


@router.get("/modules/{module_id}/chapters")
async def list_chapters(module_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_module(cursor, module_id, current_user)
        await cursor.execute("SELECT id,title,content_type,content_path,sequence_order,duration_seconds FROM chapters WHERE module_id=:module_id AND deleted_at IS NULL ORDER BY sequence_order,id", module_id=module_id)
        result=[]
        for row in await cursor.fetchall():
            content = await row[3].read() if hasattr(row[3], "read") else row[3]
            result.append({"id":row[0],"title":row[1],"content_type":row[2],"content_path":content,"sequence_order":row[4],"duration_seconds":row[5]})
        return {"chapters": result}


@router.post("/modules/{module_id}/chapters", status_code=201)
async def create_chapter(module_id: int, body: ChapterInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_module(cursor, module_id, current_user)
        out_id=cursor.var(oracledb.NUMBER)
        await cursor.execute("""
          INSERT INTO chapters(module_id,title,content_type,content_path,sequence_order,duration_seconds)
          VALUES(:module_id,:title,:content_type,:content_path,:sequence_order,:duration_seconds) RETURNING id INTO :out_id
        """, module_id=module_id, out_id=out_id, **body.model_dump())
        await conn.commit()
        return {"id":int(out_id.getvalue()[0]),"message":"Chapter created"}


@router.put("/chapters/{chapter_id}")
async def update_chapter(chapter_id: int, body: ChapterInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT module_id FROM chapters WHERE id=:chapter_id AND deleted_at IS NULL", chapter_id=chapter_id)
        row=await cursor.fetchone()
        if not row: raise HTTPException(404,"Chapter not found")
        await _owned_module(cursor,row[0],current_user)
        await cursor.execute("UPDATE chapters SET title=:title,content_type=:content_type,content_path=:content_path,sequence_order=:sequence_order,duration_seconds=:duration_seconds WHERE id=:chapter_id", chapter_id=chapter_id, **body.model_dump())
        await conn.commit()
        return {"message":"Chapter updated"}


@router.delete("/chapters/{chapter_id}")
async def delete_chapter(chapter_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT module_id FROM chapters WHERE id=:chapter_id AND deleted_at IS NULL", chapter_id=chapter_id)
        row=await cursor.fetchone()
        if not row: raise HTTPException(404,"Chapter not found")
        await _owned_module(cursor,row[0],current_user)
        await cursor.execute("UPDATE chapters SET deleted_at=SYSTIMESTAMP WHERE id=:chapter_id",chapter_id=chapter_id)
        await conn.commit()
        return {"message":"Chapter deleted"}


@router.get("/assignment-options")
async def assignment_options(current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT u.id,u.username,NVL(up.full_name,u.full_name),up.store_code,up.city,up.reporting_manager_name
                              FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id
                              WHERE LOWER(u.role)='participant' AND NVL(LOWER(u.status),'active')='active'
                              ORDER BY NVL(up.full_name,u.full_name),u.username""")
        participants=[dict(zip(["id","username","full_name","store_code","city","reporting_manager_name"],r)) for r in await cursor.fetchall()]
        return {"participants":participants,"store_codes":sorted({r["store_code"] for r in participants if r["store_code"]}),"cities":sorted({r["city"] for r in participants if r["city"]}),"manager_names":sorted({r["reporting_manager_name"] for r in participants if r["reporting_manager_name"]})}


@router.get("/assignments")
async def list_assignments(page:int=Query(1,ge=1),limit:int=Query(50,ge=1,le=200),current_user:UserProfile=Depends(require_trainer),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        owner_clause="" if current_user.role=="admin" else " AND c.created_by=:owner_id"
        owner_params = {}
        if current_user.role!="admin": owner_params["owner_id"]=current_user.id
        await cursor.execute("SELECT COUNT(*) FROM assignments a JOIN courses c ON c.id=a.item_id AND a.item_type='course' WHERE a.user_id IS NOT NULL"+owner_clause,owner_params)
        total=(await cursor.fetchone())[0]
        params={**owner_params,"offset":(page-1)*limit,"limit":limit}
        await cursor.execute("""SELECT a.id,a.item_id,c.title,a.user_id,u.username,NVL(up.full_name,u.full_name),a.assigned_date,a.deadline_date
          FROM assignments a JOIN courses c ON c.id=a.item_id AND a.item_type='course' JOIN users u ON u.id=a.user_id
          LEFT JOIN user_profiles up ON up.user_id=u.id WHERE a.user_id IS NOT NULL"""+owner_clause+" ORDER BY a.id DESC OFFSET :offset ROWS FETCH NEXT :limit ROWS ONLY",params)
        keys=["id","course_id","course_title","user_id","username","full_name","assigned_date","deadline_date"]
        return {"assignments":[dict(zip(keys,r)) for r in await cursor.fetchall()],"total":total,"page":page,"limit":limit}


@router.post("/assignments/bulk")
async def bulk_assign(body:BulkAssignmentInput,current_user:UserProfile=Depends(require_trainer),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        courses={}
        for course_id in set(body.course_ids):
            await _owned_course(cursor,course_id,current_user)
            await cursor.execute("SELECT duration_type,duration_value FROM courses WHERE id=:course_id",course_id=course_id)
            courses[course_id]=await cursor.fetchone()
        user_ids=set(body.user_ids)
        filters=[]; params={}
        for i,value in enumerate(body.store_codes): params[f"s{i}"]=value
        if body.store_codes: filters.append("up.store_code IN ("+",".join(f":s{i}" for i in range(len(body.store_codes)))+")")
        for i,value in enumerate(body.manager_names): params[f"m{i}"]=value
        if body.manager_names: filters.append("up.reporting_manager_name IN ("+",".join(f":m{i}" for i in range(len(body.manager_names)))+")")
        if filters:
            await cursor.execute("SELECT u.id FROM users u JOIN user_profiles up ON up.user_id=u.id WHERE LOWER(u.role)='participant' AND ("+" OR ".join(filters)+")",params)
            user_ids.update(r[0] for r in await cursor.fetchall())
        if not user_ids: raise HTTPException(422,"Select at least one participant, store, or manager")
        binds={f"u{i}":uid for i,uid in enumerate(user_ids)}
        await cursor.execute("SELECT id FROM users WHERE LOWER(role)='participant' AND id IN ("+",".join(f":u{i}" for i in range(len(user_ids)))+")",binds)
        valid_users={r[0] for r in await cursor.fetchall()}
        assigned=skipped=0
        now=datetime.now(timezone.utc).replace(tzinfo=None)
        for course_id,(duration_type,duration_value) in courses.items():
            deadline=None
            if duration_value and duration_type in ("Days","Weeks"):
                deadline=now+timedelta(days=int(duration_value)*(7 if duration_type=="Weeks" else 1))
            for user_id in valid_users:
                await cursor.execute("SELECT 1 FROM assignments WHERE item_type='course' AND item_id=:course_id AND user_id=:user_id",course_id=course_id,user_id=user_id)
                if await cursor.fetchone(): skipped+=1; continue
                await cursor.execute("INSERT INTO assignments(item_type,item_id,user_id,assigned_date,deadline_date) VALUES('course',:course_id,:user_id,:assigned_date,:deadline_date)",course_id=course_id,user_id=user_id,assigned_date=now,deadline_date=deadline)
                assigned+=1
        await conn.commit()
        return {"message":"Assignments processed","assigned":assigned,"skipped":skipped}


@router.delete("/assignments/{assignment_id}")
async def unassign(assignment_id:int,current_user:UserProfile=Depends(require_trainer),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT item_id FROM assignments WHERE id=:assignment_id AND item_type='course'",assignment_id=assignment_id)
        row=await cursor.fetchone()
        if not row: raise HTTPException(404,"Assignment not found")
        await _owned_course(cursor,row[0],current_user)
        await cursor.execute("DELETE FROM assignments WHERE id=:assignment_id",assignment_id=assignment_id)
        await conn.commit()
        return {"message":"Assignment removed"}
