from datetime import datetime
from typing import Literal

import oracledb
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator

from app.core.database import get_db_connection
from app.core.security import require_trainer
from app.schemas.user import UserProfile

router = APIRouter()


class QuizInput(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    quiz_description: str | None = None
    module_id: int | None = None
    linked_module_id: int | None = None
    scheduled_time: datetime | None = None
    duration_type: Literal["No Duration", "Minutes", "Hours", "Days", "Weeks"] = "No Duration"
    duration_value: int | None = Field(default=None, ge=1)
    is_random: bool = False
    allows_retake: bool = False
    quiz_badge_id: int | None = None


class OptionInput(BaseModel):
    text: str = Field(min_length=1, max_length=1000)
    is_correct: bool = False


class QuestionInput(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    image_path: str | None = None
    difficulty: Literal["easy", "medium", "hard"] | None = None
    options: list[OptionInput] = Field(min_length=2)

    @model_validator(mode="after")
    def has_correct_answer(self):
        if not any(option.is_correct for option in self.options):
            raise ValueError("At least one option must be correct")
        return self


async def _owned_quiz(cursor, quiz_id: int, user: UserProfile):
    sql = "SELECT id,title FROM quizzes WHERE id=:quiz_id AND deleted_at IS NULL"
    params = {"quiz_id": quiz_id}
    if user.role != "admin":
        sql += " AND created_by=:owner_id"
        params["owner_id"] = user.id
    await cursor.execute(sql, params)
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(404, "Quiz not found or not owned by you")
    return row


@router.get("/quizzes")
async def list_quizzes(current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        sql = """
          SELECT q.id,q.title,q.quiz_description,q.duration_type,q.duration_value,q.scheduled_time,
                 q.is_random,q.allows_retake,q.quiz_badge_id,q.module_id,q.linked_module_id,
                 COUNT(DISTINCT qu.id),COUNT(DISTINCT a.user_id)
          FROM quizzes q
          LEFT JOIN questions qu ON qu.quiz_id=q.id AND qu.deleted_at IS NULL
          LEFT JOIN assignments a ON a.item_type='quiz' AND a.item_id=q.id AND a.user_id IS NOT NULL
          WHERE q.deleted_at IS NULL
        """
        params = {}
        if current_user.role != "admin":
            sql += " AND q.created_by=:owner_id"
            params["owner_id"] = current_user.id
        sql += " GROUP BY q.id,q.title,q.quiz_description,q.duration_type,q.duration_value,q.scheduled_time,q.is_random,q.allows_retake,q.quiz_badge_id,q.module_id,q.linked_module_id ORDER BY q.id DESC"
        await cursor.execute(sql, params)
        keys = ["id","title","quiz_description","duration_type","duration_value","scheduled_time","is_random","allows_retake","quiz_badge_id","module_id","linked_module_id","question_count","participant_count"]
        return {"quizzes": [dict(zip(keys, row)) for row in await cursor.fetchall()]}


@router.post("/quizzes", status_code=201)
async def create_quiz(body: QuizInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        out_id = cursor.var(oracledb.NUMBER)
        data = body.model_dump()
        data.update({"created_by": current_user.id, "is_random": int(body.is_random), "allows_retake": int(body.allows_retake), "out_id": out_id})
        await cursor.execute("""
          INSERT INTO quizzes(title,quiz_description,module_id,linked_module_id,scheduled_time,duration_type,
                              duration_value,is_random,allows_retake,quiz_badge_id,created_by)
          VALUES(:title,:quiz_description,:module_id,:linked_module_id,:scheduled_time,:duration_type,
                 :duration_value,:is_random,:allows_retake,:quiz_badge_id,:created_by) RETURNING id INTO :out_id
        """, data)
        await conn.commit()
        return {"id": int(out_id.getvalue()[0]), "message": "Quiz created"}


@router.put("/quizzes/{quiz_id}")
async def update_quiz(quiz_id: int, body: QuizInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_quiz(cursor, quiz_id, current_user)
        data = body.model_dump()
        data.update({"quiz_id": quiz_id, "is_random": int(body.is_random), "allows_retake": int(body.allows_retake)})
        await cursor.execute("""
          UPDATE quizzes SET title=:title,quiz_description=:quiz_description,module_id=:module_id,
            linked_module_id=:linked_module_id,scheduled_time=:scheduled_time,duration_type=:duration_type,
            duration_value=:duration_value,is_random=:is_random,allows_retake=:allows_retake,
            quiz_badge_id=:quiz_badge_id WHERE id=:quiz_id
        """, data)
        await conn.commit()
        return {"message": "Quiz updated"}


@router.delete("/quizzes/{quiz_id}")
async def delete_quiz(quiz_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_quiz(cursor, quiz_id, current_user)
        await cursor.execute("UPDATE quizzes SET deleted_at=SYSTIMESTAMP WHERE id=:quiz_id", quiz_id=quiz_id)
        await conn.commit()
        return {"message": "Quiz deleted"}


@router.post("/quizzes/{quiz_id}/duplicate", status_code=201)
async def duplicate_quiz(quiz_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_quiz(cursor, quiz_id, current_user)
        await cursor.execute("""SELECT title,quiz_description,module_id,linked_module_id,duration_type,duration_value,
                                        is_random,allows_retake,quiz_badge_id FROM quizzes WHERE id=:quiz_id""", quiz_id=quiz_id)
        source = await cursor.fetchone()
        out_quiz = cursor.var(oracledb.NUMBER)
        await cursor.execute("""
          INSERT INTO quizzes(title,quiz_description,module_id,linked_module_id,scheduled_time,duration_type,
                              duration_value,is_random,allows_retake,quiz_badge_id,created_by)
          VALUES(:title,:description,:module_id,:linked_module_id,NULL,:duration_type,
                 :duration_value,:is_random,:allows_retake,:badge_id,:owner_id)
          RETURNING id INTO :out_id
        """, title=source[0] + " (Copy)", description=source[1], module_id=source[2], linked_module_id=source[3],
             duration_type=source[4], duration_value=source[5], is_random=source[6], allows_retake=source[7],
             badge_id=source[8], owner_id=current_user.id, out_id=out_quiz)
        new_quiz_id = int(out_quiz.getvalue()[0])
        await cursor.execute("SELECT id,text,image_path,difficulty FROM questions WHERE quiz_id=:quiz_id AND deleted_at IS NULL ORDER BY id", quiz_id=quiz_id)
        for old_question_id, text, image_path, difficulty in await cursor.fetchall():
            out_question = cursor.var(oracledb.NUMBER)
            await cursor.execute("INSERT INTO questions(quiz_id,text,image_path,difficulty) VALUES(:quiz_id,:text,:image_path,:difficulty) RETURNING id INTO :out_id", quiz_id=new_quiz_id, text=text, image_path=image_path, difficulty=difficulty, out_id=out_question)
            await cursor.execute("INSERT INTO options(question_id,text,is_correct) SELECT :new_question,text,is_correct FROM options WHERE question_id=:old_question", new_question=int(out_question.getvalue()[0]), old_question=old_question_id)
        await conn.commit()
        return {"id": new_quiz_id, "message": "Quiz duplicated"}


@router.get("/quizzes/{quiz_id}/questions")
async def list_questions(quiz_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_quiz(cursor, quiz_id, current_user)
        await cursor.execute("SELECT id,text,image_path,difficulty FROM questions WHERE quiz_id=:quiz_id AND deleted_at IS NULL ORDER BY id", quiz_id=quiz_id)
        result = []
        for row in await cursor.fetchall():
            await cursor.execute("SELECT id,text,is_correct FROM options WHERE question_id=:question_id ORDER BY id", question_id=row[0])
            options = [{"id": option[0], "text": option[1], "is_correct": bool(option[2])} for option in await cursor.fetchall()]
            result.append({"id": row[0], "text": row[1], "image_path": row[2], "difficulty": row[3], "options": options})
        return {"questions": result}


@router.post("/quizzes/{quiz_id}/questions", status_code=201)
async def create_question(quiz_id: int, body: QuestionInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_quiz(cursor, quiz_id, current_user)
        out_id = cursor.var(oracledb.NUMBER)
        await cursor.execute("INSERT INTO questions(quiz_id,text,image_path,difficulty) VALUES(:quiz_id,:text,:image_path,:difficulty) RETURNING id INTO :out_id", quiz_id=quiz_id, text=body.text, image_path=body.image_path, difficulty=body.difficulty, out_id=out_id)
        question_id = int(out_id.getvalue()[0])
        for option in body.options:
            await cursor.execute("INSERT INTO options(question_id,text,is_correct) VALUES(:question_id,:text,:is_correct)", question_id=question_id, text=option.text, is_correct=int(option.is_correct))
        await conn.commit()
        return {"id": question_id, "message": "Question created"}


@router.put("/questions/{question_id}")
async def update_question(question_id: int, body: QuestionInput, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT quiz_id FROM questions WHERE id=:question_id AND deleted_at IS NULL", question_id=question_id)
        row = await cursor.fetchone()
        if not row: raise HTTPException(404, "Question not found")
        await _owned_quiz(cursor, row[0], current_user)
        await cursor.execute("UPDATE questions SET text=:text,image_path=:image_path,difficulty=:difficulty WHERE id=:question_id", text=body.text, image_path=body.image_path, difficulty=body.difficulty, question_id=question_id)
        await cursor.execute("DELETE FROM options WHERE question_id=:question_id", question_id=question_id)
        for option in body.options:
            await cursor.execute("INSERT INTO options(question_id,text,is_correct) VALUES(:question_id,:text,:is_correct)", question_id=question_id, text=option.text, is_correct=int(option.is_correct))
        await conn.commit()
        return {"message": "Question updated"}


@router.delete("/questions/{question_id}")
async def delete_question(question_id: int, current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT quiz_id FROM questions WHERE id=:question_id AND deleted_at IS NULL", question_id=question_id)
        row = await cursor.fetchone()
        if not row: raise HTTPException(404, "Question not found")
        await _owned_quiz(cursor, row[0], current_user)
        await cursor.execute("UPDATE questions SET deleted_at=SYSTIMESTAMP WHERE id=:question_id", question_id=question_id)
        await conn.commit()
        return {"message": "Question deleted"}


@router.get("/quiz-retake-requests")
async def retake_requests(current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        sql = """SELECT r.id,r.status,r.requested_at,r.processed_at,q.id,q.title,u.id,u.username,NVL(up.full_name,u.full_name)
                 FROM quiz_retake_requests r JOIN quizzes q ON q.id=r.quiz_id JOIN users u ON u.id=r.user_id
                 LEFT JOIN user_profiles up ON up.user_id=u.id WHERE q.deleted_at IS NULL"""
        params = {}
        if current_user.role != "admin": sql += " AND q.created_by=:owner_id"; params["owner_id"] = current_user.id
        sql += " ORDER BY CASE r.status WHEN 'pending' THEN 0 WHEN 'Pending' THEN 0 ELSE 1 END,r.requested_at DESC"
        await cursor.execute(sql, params)
        keys = ["id","status","requested_at","processed_at","quiz_id","quiz_title","user_id","username","full_name"]
        return {"requests": [dict(zip(keys, row)) for row in await cursor.fetchall()]}


@router.post("/quiz-retake-requests/{request_id}/{decision}")
async def process_retake(request_id: int, decision: Literal["approve", "reject"], current_user: UserProfile = Depends(require_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT quiz_id FROM quiz_retake_requests WHERE id=:request_id", request_id=request_id)
        row = await cursor.fetchone()
        if not row: raise HTTPException(404, "Retake request not found")
        await _owned_quiz(cursor, row[0], current_user)
        await cursor.execute("UPDATE quiz_retake_requests SET status=:status,processed_at=SYSTIMESTAMP,processed_by=:processed_by WHERE id=:request_id", status="approved" if decision == "approve" else "rejected", processed_by=current_user.id, request_id=request_id)
        await conn.commit()
        return {"message": f"Retake request {decision}d"}
