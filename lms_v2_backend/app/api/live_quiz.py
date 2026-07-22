import secrets
from datetime import datetime, timezone
from typing import Literal

import app.core.database as database
import oracledb
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect
from jose import jwt
from pydantic import BaseModel, Field

from app.core.config import settings
from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.core.websocket_manager import manager
from app.schemas.user import UserProfile
from app.services.user_service import UserService

router = APIRouter()


class StartSessionInput(BaseModel):
    quiz_id: int
    time_limit: int = Field(default=30, ge=5, le=600)
    user_ids: list[int] = Field(default_factory=list)
    store_codes: list[str] = Field(default_factory=list)
    manager_names: list[str] = Field(default_factory=list)


class QuestionControlInput(BaseModel):
    index: int = Field(ge=1)


class JoinSessionInput(BaseModel):
    access_code: str = Field(min_length=4, max_length=12)


class AnswerInput(BaseModel):
    question_id: int
    option_id: int


def _value(value):
    return value.isoformat() if isinstance(value, datetime) else value


async def require_host(user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if user.role not in ("trainer", "admin"):
        raise HTTPException(403, "Requires trainer or admin privileges")
    return user


async def require_player(user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if user.role not in ("participant", "area_manager", "admin"):
        raise HTTPException(403, "Requires participant privileges")
    return user


async def _owned_session(cursor, session_id: int, user: UserProfile, active_only: bool = False):
    sql = """
        SELECT s.id,s.quiz_id,s.access_code,s.status,NVL(s.current_question_index,0),
               s.current_question_start_time,NVL(s.time_limit,30),NVL(s.is_question_closed,0),
               s.created_at,q.title,q.created_by
        FROM live_quiz_sessions s JOIN quizzes q ON q.id=s.quiz_id
        WHERE s.id=:session_id
    """
    params = {"session_id": session_id}
    if user.role != "admin":
        sql += " AND q.created_by=:owner_id"
        params["owner_id"] = user.id
    if active_only:
        sql += " AND LOWER(s.status)='active'"
    await cursor.execute(sql, params)
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(404, "Live session not found or unavailable")
    keys = ["id", "quiz_id", "access_code", "status", "current_question_index",
            "current_question_start_time", "time_limit", "is_question_closed",
            "created_at", "quiz_title", "created_by"]
    return dict(zip(keys, row))


async def _session_questions(cursor, quiz_id: int, reveal_answers: bool = False):
    await cursor.execute("""
        SELECT id,text,image_path,difficulty FROM questions
        WHERE quiz_id=:quiz_id AND deleted_at IS NULL ORDER BY id
    """, quiz_id=quiz_id)
    result = []
    for question in await cursor.fetchall():
        option_sql = "SELECT id,text" + (",is_correct" if reveal_answers else "") + " FROM options WHERE question_id=:question_id ORDER BY id"
        await cursor.execute(option_sql, question_id=question[0])
        options = []
        for option in await cursor.fetchall():
            item = {"id": int(option[0]), "text": option[1]}
            if reveal_answers:
                item["is_correct"] = bool(option[2])
            options.append(item)
        result.append({"id": int(question[0]), "text": question[1], "image_path": question[2],
                       "difficulty": question[3], "options": options})
    return result


async def _leaderboard(cursor, session_id: int):
    await cursor.execute("""
        SELECT lsp.user_id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),
               NVL(SUM(lsa.points_earned),0),NVL(SUM(lsa.is_correct),0),COUNT(lsa.id),
               lsp.status,lsp.joined_at
        FROM live_session_participants lsp JOIN users u ON u.id=lsp.user_id
        LEFT JOIN user_profiles up ON up.user_id=u.id
        LEFT JOIN live_session_answers lsa ON lsa.session_id=lsp.session_id AND lsa.user_id=lsp.user_id
        WHERE lsp.session_id=:session_id
        GROUP BY lsp.user_id,u.username,up.full_name,u.full_name,lsp.status,lsp.joined_at
        ORDER BY NVL(SUM(lsa.points_earned),0) DESC,NVL(SUM(lsa.is_correct),0) DESC,lsp.joined_at
    """, session_id=session_id)
    keys = ["user_id", "username", "full_name", "points", "correct_answers", "answered", "status", "joined_at"]
    return [{key: _value(value) for key, value in zip(keys, row)} for row in await cursor.fetchall()]


async def _close_session(cursor, session: dict):
    await cursor.execute("UPDATE live_quiz_sessions SET status='closed',is_question_closed=1 WHERE id=:session_id", session_id=session["id"])
    await cursor.execute("SELECT COUNT(*) FROM questions WHERE quiz_id=:quiz_id AND deleted_at IS NULL", quiz_id=session["quiz_id"])
    total = int((await cursor.fetchone())[0])
    await cursor.execute("SELECT user_id FROM live_session_participants WHERE session_id=:session_id", session_id=session["id"])
    for (user_id,) in await cursor.fetchall():
        await cursor.execute("SELECT COUNT(*) FROM quiz_attempts WHERE user_id=:user_id AND live_session_id=:session_id", user_id=user_id, session_id=session["id"])
        if int((await cursor.fetchone())[0]) == 0:
            await cursor.execute("SELECT NVL(SUM(is_correct),0) FROM live_session_answers WHERE session_id=:session_id AND user_id=:user_id", session_id=session["id"], user_id=user_id)
            score = int((await cursor.fetchone())[0])
            await cursor.execute("""
                INSERT INTO quiz_attempts(user_id,quiz_id,score,total,end_time,live_session_id)
                VALUES(:user_id,:quiz_id,:score,:total,SYSTIMESTAMP,:session_id)
            """, user_id=user_id, quiz_id=session["quiz_id"], score=score, total=total, session_id=session["id"])


@router.get("/trainer/options")
async def trainer_options(user: UserProfile = Depends(require_host), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        quiz_sql = "SELECT id,title FROM quizzes WHERE deleted_at IS NULL AND EXISTS (SELECT 1 FROM questions WHERE quiz_id=quizzes.id AND deleted_at IS NULL)"
        params = {}
        if user.role != "admin":
            quiz_sql += " AND created_by=:owner_id"
            params["owner_id"] = user.id
        quiz_sql += " ORDER BY title"
        await cursor.execute(quiz_sql, params)
        quizzes = [{"id": int(row[0]), "title": row[1]} for row in await cursor.fetchall()]
        await cursor.execute("""
            SELECT u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code,up.reporting_manager_name
            FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id
            WHERE LOWER(u.role)='participant' AND NVL(LOWER(u.status),'active')='active'
            ORDER BY NVL(up.full_name,NVL(u.full_name,u.username))
        """)
        keys = ["id", "username", "full_name", "store_code", "reporting_manager_name"]
        participants = [dict(zip(keys, row)) for row in await cursor.fetchall()]
        return {"quizzes": quizzes, "participants": participants,
                "store_codes": sorted({p["store_code"] for p in participants if p["store_code"]}),
                "manager_names": sorted({p["reporting_manager_name"] for p in participants if p["reporting_manager_name"]})}


@router.get("/trainer/sessions")
async def list_sessions(user: UserProfile = Depends(require_host), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        sql = """
            SELECT s.id,s.quiz_id,q.title,s.access_code,s.status,NVL(s.current_question_index,0),
                   NVL(s.time_limit,30),s.created_at,COUNT(DISTINCT p.user_id)
            FROM live_quiz_sessions s JOIN quizzes q ON q.id=s.quiz_id
            LEFT JOIN live_session_participants p ON p.session_id=s.id WHERE 1=1
        """
        params = {}
        if user.role != "admin":
            sql += " AND q.created_by=:owner_id"
            params["owner_id"] = user.id
        sql += " GROUP BY s.id,s.quiz_id,q.title,s.access_code,s.status,s.current_question_index,s.time_limit,s.created_at ORDER BY s.created_at DESC,s.id DESC"
        await cursor.execute(sql, params)
        keys = ["id", "quiz_id", "quiz_title", "access_code", "status", "current_question_index", "time_limit", "created_at", "participant_count"]
        return {"sessions": [{key: _value(value) for key, value in zip(keys, row)} for row in await cursor.fetchall()]}


@router.post("/trainer/sessions", status_code=201)
async def start_session(body: StartSessionInput, user: UserProfile = Depends(require_host), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        quiz_sql = "SELECT id,title FROM quizzes WHERE id=:quiz_id AND deleted_at IS NULL"
        params = {"quiz_id": body.quiz_id}
        if user.role != "admin":
            quiz_sql += " AND created_by=:owner_id"
            params["owner_id"] = user.id
        await cursor.execute(quiz_sql, params)
        quiz = await cursor.fetchone()
        if not quiz:
            raise HTTPException(404, "Quiz not found or not owned by you")
        await cursor.execute("SELECT COUNT(*) FROM questions WHERE quiz_id=:quiz_id AND deleted_at IS NULL", quiz_id=body.quiz_id)
        if int((await cursor.fetchone())[0]) == 0:
            raise HTTPException(422, "Add at least one question before starting a live session")
        alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
        code = None
        for _ in range(12):
            candidate = "".join(secrets.choice(alphabet) for _ in range(6))
            await cursor.execute("SELECT COUNT(*) FROM live_quiz_sessions WHERE access_code=:code AND LOWER(status)='active'", code=candidate)
            if int((await cursor.fetchone())[0]) == 0:
                code = candidate
                break
        if not code:
            raise HTTPException(503, "Could not allocate a unique access code")
        out_id = cursor.var(oracledb.NUMBER)
        await cursor.execute("""
            INSERT INTO live_quiz_sessions(quiz_id,access_code,status,current_question_index,time_limit,is_question_closed,created_at)
            VALUES(:quiz_id,:code,'active',0,:time_limit,0,SYSTIMESTAMP) RETURNING id INTO :out_id
        """, quiz_id=body.quiz_id, code=code, time_limit=body.time_limit, out_id=out_id)
        session_id = int(out_id.getvalue()[0])
        await cursor.execute("""
            SELECT u.id,up.store_code,up.reporting_manager_name FROM users u
            LEFT JOIN user_profiles up ON up.user_id=u.id
            WHERE LOWER(u.role)='participant' AND NVL(LOWER(u.status),'active')='active'
        """)
        eligible = await cursor.fetchall()
        selected = {int(row[0]) for row in eligible if int(row[0]) in body.user_ids or row[1] in body.store_codes or row[2] in body.manager_names}
        for user_id in selected:
            await cursor.execute("""
                MERGE INTO assignments a USING (SELECT 'quiz' item_type,:quiz_id item_id,:user_id user_id FROM dual) src
                ON (a.item_type=src.item_type AND a.item_id=src.item_id AND a.user_id=src.user_id)
                WHEN NOT MATCHED THEN INSERT(item_type,item_id,user_id,assigned_date) VALUES(src.item_type,src.item_id,src.user_id,SYSTIMESTAMP)
            """, quiz_id=body.quiz_id, user_id=user_id)
            await cursor.execute("""
                INSERT INTO notifications(user_id,type,title,message,link,is_read,created_at,target_type,target_id,fcm_sent)
                VALUES(:user_id,'quiz_assigned','Live Quiz Session Started',:message,'/participant/live',0,SYSTIMESTAMP,'quiz',:quiz_id,0)
            """, user_id=user_id, message=f'Join "{quiz[1]}" using code {code}', quiz_id=body.quiz_id)
        await conn.commit()
        return {"id": session_id, "access_code": code, "assigned_count": len(selected), "message": "Live session started"}


@router.get("/trainer/sessions/{session_id}")
async def host_state(session_id: int, user: UserProfile = Depends(require_host), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        session = await _owned_session(cursor, session_id, user)
        questions = await _session_questions(cursor, session["quiz_id"], reveal_answers=True)
        current = session["current_question_index"]
        distribution = []
        if 0 < current <= len(questions):
            await cursor.execute("""
                SELECT o.id,o.text,COUNT(a.id) FROM options o
                LEFT JOIN live_session_answers a ON a.option_id=o.id AND a.session_id=:session_id
                WHERE o.question_id=:question_id GROUP BY o.id,o.text ORDER BY o.id
            """, session_id=session_id, question_id=questions[current - 1]["id"])
            distribution = [{"option_id": int(row[0]), "text": row[1], "count": int(row[2])} for row in await cursor.fetchall()]
        return {"session": {key: _value(value) for key, value in session.items()}, "questions": questions,
                "leaderboard": await _leaderboard(cursor, session_id), "answer_distribution": distribution}


@router.post("/trainer/sessions/{session_id}/question")
async def set_question(session_id: int, body: QuestionControlInput, user: UserProfile = Depends(require_host), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        session = await _owned_session(cursor, session_id, user, active_only=True)
        await cursor.execute("SELECT COUNT(*) FROM questions WHERE quiz_id=:quiz_id AND deleted_at IS NULL", quiz_id=session["quiz_id"])
        total = int((await cursor.fetchone())[0])
        if body.index > total:
            raise HTTPException(422, "Question index is outside this quiz")
        await cursor.execute("UPDATE live_quiz_sessions SET current_question_index=:idx,current_question_start_time=SYSTIMESTAMP,is_question_closed=0 WHERE id=:session_id", idx=body.index, session_id=session_id)
        await conn.commit()
    await manager.broadcast_to_room({"event": "question_updated", "current_question_index": body.index, "is_question_closed": False}, str(session_id))
    return {"message": "Question opened", "index": body.index}


@router.post("/trainer/sessions/{session_id}/close-question")
async def close_question(session_id: int, user: UserProfile = Depends(require_host), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_session(cursor, session_id, user, active_only=True)
        await cursor.execute("UPDATE live_quiz_sessions SET is_question_closed=1 WHERE id=:session_id", session_id=session_id)
        await conn.commit()
    await manager.broadcast_to_room({"event": "question_closed", "is_question_closed": True}, str(session_id))
    return {"message": "Question closed"}


@router.post("/trainer/sessions/{session_id}/close")
async def close_session(session_id: int, user: UserProfile = Depends(require_host), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        session = await _owned_session(cursor, session_id, user)
        if str(session["status"]).lower() != "closed":
            await _close_session(cursor, session)
            await conn.commit()
    await manager.broadcast_to_room({"event": "session_closed", "status": "closed"}, str(session_id))
    return {"message": "Session closed"}


@router.delete("/trainer/sessions/{session_id}")
async def delete_session(session_id: int, user: UserProfile = Depends(require_host), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _owned_session(cursor, session_id, user)
        await cursor.execute("DELETE FROM live_quiz_sessions WHERE id=:session_id", session_id=session_id)
        await conn.commit()
    return {"message": "Session deleted"}


@router.get("/trainer/sessions/{session_id}/report")
async def session_report(session_id: int, user: UserProfile = Depends(require_host), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        session = await _owned_session(cursor, session_id, user)
        questions = await _session_questions(cursor, session["quiz_id"], reveal_answers=True)
        await cursor.execute("""
            SELECT a.user_id,a.question_id,a.option_id,a.is_correct,a.time_taken,a.points_earned
            FROM live_session_answers a WHERE a.session_id=:session_id ORDER BY a.user_id,a.question_id
        """, session_id=session_id)
        keys = ["user_id", "question_id", "selected_option_id", "is_correct", "time_taken", "points_earned"]
        answers = [dict(zip(keys, row)) for row in await cursor.fetchall()]
        return {"session": {key: _value(value) for key, value in session.items()}, "questions": questions,
                "leaderboard": await _leaderboard(cursor, session_id), "answers": answers}


@router.post("/participant/join")
async def join_session(body: JoinSessionInput, user: UserProfile = Depends(require_player), conn=Depends(get_db_connection)):
    code = body.access_code.strip().upper()
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT s.id,s.quiz_id,q.title,NVL(s.time_limit,30) FROM live_quiz_sessions s
            JOIN quizzes q ON q.id=s.quiz_id WHERE UPPER(s.access_code)=:code AND LOWER(s.status)='active'
        """, code=code)
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Invalid or expired access code")
        await cursor.execute("""
            MERGE INTO live_session_participants p USING (SELECT :session_id session_id,:user_id user_id FROM dual) src
            ON (p.session_id=src.session_id AND p.user_id=src.user_id)
            WHEN NOT MATCHED THEN INSERT(session_id,user_id,status,total_points,joined_at) VALUES(src.session_id,src.user_id,'joined',0,SYSTIMESTAMP)
        """, session_id=row[0], user_id=user.id)
        await cursor.execute("""
            MERGE INTO assignments a USING (SELECT 'quiz' item_type,:quiz_id item_id,:user_id user_id FROM dual) src
            ON (a.item_type=src.item_type AND a.item_id=src.item_id AND a.user_id=src.user_id)
            WHEN NOT MATCHED THEN INSERT(item_type,item_id,user_id,assigned_date) VALUES(src.item_type,src.item_id,src.user_id,SYSTIMESTAMP)
        """, quiz_id=row[1], user_id=user.id)
        await conn.commit()
        return {"session_id": int(row[0]), "quiz_id": int(row[1]), "quiz_title": row[2], "time_limit": int(row[3])}


@router.get("/participant/sessions/{session_id}")
async def participant_state(session_id: int, user: UserProfile = Depends(require_player), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT s.id,s.quiz_id,s.status,NVL(s.current_question_index,0),s.current_question_start_time,
                   NVL(s.time_limit,30),NVL(s.is_question_closed,0),q.title
            FROM live_quiz_sessions s JOIN quizzes q ON q.id=s.quiz_id
            JOIN live_session_participants p ON p.session_id=s.id AND p.user_id=:user_id
            WHERE s.id=:session_id
        """, user_id=user.id, session_id=session_id)
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Join this live session before viewing it")
        keys = ["id", "quiz_id", "status", "current_question_index", "current_question_start_time", "time_limit", "is_question_closed", "quiz_title"]
        session = dict(zip(keys, row))
        questions = await _session_questions(cursor, session["quiz_id"])
        current = session["current_question_index"]
        question = questions[current - 1] if 0 < current <= len(questions) else None
        answer = None
        if question:
            await cursor.execute("""
                SELECT option_id,is_correct,points_earned,time_taken FROM live_session_answers
                WHERE session_id=:session_id AND user_id=:user_id AND question_id=:question_id
            """, session_id=session_id, user_id=user.id, question_id=question["id"])
            answer_row = await cursor.fetchone()
            if answer_row:
                answer = {"selected_option_id": int(answer_row[0]), "is_correct": bool(answer_row[1]),
                          "points_earned": int(answer_row[2] or 0), "time_taken": int(answer_row[3] or 0)}
        response = {"session": {key: _value(value) for key, value in session.items()}, "total_questions": len(questions), "question": question, "answer": answer}
        if str(session["status"]).lower() == "closed":
            response["leaderboard"] = await _leaderboard(cursor, session_id)
        return response


@router.post("/participant/sessions/{session_id}/answer")
async def submit_answer(session_id: int, body: AnswerInput, user: UserProfile = Depends(require_player), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT s.quiz_id,s.current_question_index,s.current_question_start_time,NVL(s.time_limit,30),NVL(s.is_question_closed,0)
            FROM live_quiz_sessions s JOIN live_session_participants p ON p.session_id=s.id AND p.user_id=:user_id
            WHERE s.id=:session_id AND LOWER(s.status)='active'
        """, user_id=user.id, session_id=session_id)
        session = await cursor.fetchone()
        if not session:
            raise HTTPException(400, "Session is not active or you have not joined")
        if int(session[4]) != 0:
            raise HTTPException(409, "Question is closed")
        await cursor.execute("""
            SELECT q.id,o.is_correct FROM questions q JOIN options o ON o.question_id=q.id
            WHERE q.id=:question_id AND o.id=:option_id AND q.quiz_id=:quiz_id AND q.deleted_at IS NULL
              AND (SELECT COUNT(*) FROM questions prior_question
                   WHERE prior_question.quiz_id=q.quiz_id
                     AND prior_question.deleted_at IS NULL
                     AND prior_question.id<=q.id)=:current_index
        """, question_id=body.question_id, option_id=body.option_id, quiz_id=session[0], current_index=session[1])
        option = await cursor.fetchone()
        if not option:
            raise HTTPException(422, "Option does not belong to the current question")
        await cursor.execute("SELECT COUNT(*) FROM live_session_answers WHERE session_id=:session_id AND user_id=:user_id AND question_id=:question_id", session_id=session_id, user_id=user.id, question_id=body.question_id)
        if int((await cursor.fetchone())[0]) > 0:
            raise HTTPException(409, "Answer already submitted")
        started = session[2]
        now = datetime.now(timezone.utc)
        if started and started.tzinfo is None:
            started = started.replace(tzinfo=timezone.utc)
        elapsed = max(0, int((now - started).total_seconds())) if started else 0
        limit = max(1, int(session[3]))
        correct = bool(option[1]) and elapsed <= limit
        points = max(500, int(1000 * (1 - elapsed / (2 * limit)))) if correct else 0
        await cursor.execute("""
            INSERT INTO live_session_answers(session_id,user_id,question_id,option_id,is_correct,time_taken,points_earned)
            VALUES(:session_id,:user_id,:question_id,:option_id,:is_correct,:time_taken,:points)
        """, session_id=session_id, user_id=user.id, question_id=body.question_id, option_id=body.option_id,
             is_correct=int(correct), time_taken=elapsed, points=points)
        await cursor.execute("UPDATE live_session_participants SET status='submitted',total_points=NVL(total_points,0)+:points WHERE session_id=:session_id AND user_id=:user_id", points=points, session_id=session_id, user_id=user.id)
        await conn.commit()
        return {"success": True, "is_correct": correct, "points_earned": points, "time_taken": elapsed}


@router.websocket("/trainer")
async def trainer_socket(websocket: WebSocket, session_id: str = Query(...), token: str = Query(...)):
    user = await _socket_user(websocket, token, ("trainer", "admin"))
    if not user:
        return
    async with database._pool.acquire() as conn:
        async with conn.cursor() as cursor:
            try:
                await _owned_session(cursor, int(session_id), user, active_only=True)
            except Exception:
                await websocket.close(code=1008, reason="Live session unavailable")
                return
    await manager.connect(websocket, session_id, user.id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(session_id, user.id)


@router.websocket("/participant")
async def participant_socket(websocket: WebSocket, session_id: str = Query(...), token: str = Query(...)):
    user = await _socket_user(websocket, token, ("participant", "area_manager", "admin"))
    if not user:
        return
    async with database._pool.acquire() as conn:
        async with conn.cursor() as cursor:
            await cursor.execute("SELECT COUNT(*) FROM live_session_participants WHERE session_id=:session_id AND user_id=:user_id", session_id=int(session_id), user_id=user.id)
            if int((await cursor.fetchone())[0]) == 0:
                await websocket.close(code=1008, reason="Join the session first")
                return
    await manager.connect(websocket, session_id, user.id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(session_id, user.id)


async def _socket_user(websocket: WebSocket, token: str, roles: tuple[str, ...]):
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = int(payload.get("sub"))
        if not database._pool:
            raise ValueError("Database unavailable")
        async with database._pool.acquire() as conn:
            user = await UserService(conn).get_user_by_id(user_id)
        if user.role not in roles:
            raise ValueError("Invalid role")
        return user
    except Exception:
        await websocket.close(code=1008, reason="Unauthorized")
        return None
