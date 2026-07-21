from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from app.core.websocket_manager import manager
import oracledb
from app.core.database import get_db_connection
from jose import jwt
from app.core.config import settings
from app.services.user_service import UserService
import app.core.database as database

router = APIRouter()

@router.websocket("/trainer")
async def trainer_live_session(
    websocket: WebSocket,
    session_id: str = Query(...),
    token: str = Query(...)
):
    """
    WebSocket endpoint for Trainers to push live quiz commands natively.
    Replaces the legacy PHP polling strategy.
    """
    # 1. Manual Token Validation for WebSockets
    # Since HTTP exceptions don't work natively in the WS handshake cleanly, 
    # we manually decode and disconnect with code 1008 (Policy Violation) if unauthorized.
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = int(payload.get("sub"))
        
        # We need a DB connection strictly for this auth step
        # Since FastAPI Depends() in websockets can be tricky with async generators,
        # we will grab a quick connection for validation if needed, but here we can 
        # just trust the stateless JWT role if we encode it. Since we didn't encode role 
        # in the token earlier, we fetch it.
        # Let's assume the token is valid, we'll fetch the user manually.
    except Exception:
        await websocket.close(code=1008, reason="Unauthorized")
        return
        
    # We will dynamically grab the connection to verify the user role
    if not database._pool:
        await websocket.close(code=1011, reason="Database unavailable")
        return

    async with database._pool.acquire() as conn:
        try:
            user_service = UserService(conn)
            user = await user_service.get_user_by_id(user_id)
            if user.role not in ["trainer", "admin"]:
                await websocket.close(code=1008, reason="Requires trainer privileges")
                return
            async with conn.cursor() as cursor:
                await cursor.execute("""SELECT q.created_by FROM live_quiz_sessions s JOIN quizzes q ON q.id=s.quiz_id
                                      WHERE s.id=:session_id AND s.status='active'""", session_id=int(session_id))
                session = await cursor.fetchone()
                if not session or (user.role != "admin" and int(session[0] or 0) != user.id):
                    await websocket.close(code=1008, reason="Live session unavailable")
                    return
        except Exception:
            await websocket.close(code=1008, reason="Invalid user")
            return

    # 2. Accept and Register Connection
    await manager.connect(websocket, room_id=session_id, user_id=user.id)

    # 3. Listen for Trainer Commands
    try:
        while True:
            # Parse incoming command (matching legacy live_ajax actions)
            data = await websocket.receive_json()
            action = data.get("action")

            if action == "set_question":
                index = data.get("index")
                async with database._pool.acquire() as conn:
                    async with conn.cursor() as cursor:
                        await cursor.execute("UPDATE live_quiz_sessions SET current_question_index=:idx,current_question_start_time=SYSTIMESTAMP,is_question_closed=0 WHERE id=:session_id",idx=int(index),session_id=int(session_id));await conn.commit()
                
                # Asynchronously broadcast to all participants to move to the next question
                await manager.broadcast_to_room({
                    "event": "question_updated",
                    "current_question_index": index,
                    "is_question_closed": False
                }, room_id=session_id)
            
            elif action == "close_question":
                async with database._pool.acquire() as conn:
                    async with conn.cursor() as cursor:await cursor.execute("UPDATE live_quiz_sessions SET is_question_closed=1 WHERE id=:session_id",session_id=int(session_id));await conn.commit()
                # Time is up or trainer closed early
                await manager.broadcast_to_room({
                    "event": "question_closed",
                    "is_question_closed": True
                }, room_id=session_id)
            
            elif action == "close_session":
                async with database._pool.acquire() as conn:
                    async with conn.cursor() as cursor:await cursor.execute("UPDATE live_quiz_sessions SET status='closed' WHERE id=:session_id",session_id=int(session_id));await conn.commit()
                # Final leaderboard phase
                await manager.broadcast_to_room({
                    "event": "session_closed",
                    "status": "closed"
                }, room_id=session_id)

    except WebSocketDisconnect:
        manager.disconnect(room_id=session_id, user_id=user.id)

@router.websocket("/participant")
async def participant_live_session(
    websocket: WebSocket,
    session_id: str = Query(...),
    token: str = Query(...)
):
    """
    WebSocket endpoint for Participants to join live quizzes and stream questions.
    Accepts real-time answer submissions and logs them directly to Oracle DB.
    """
    # 1. Manual Token Validation
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id = int(payload.get("sub"))
    except Exception:
        await websocket.close(code=1008, reason="Unauthorized")
        return
        
    if not database._pool:
        await websocket.close(code=1011, reason="Database unavailable")
        return

    async with database._pool.acquire() as conn:
        user_service = UserService(conn)
        try:
            user = await user_service.get_user_by_id(user_id)
            if user.role not in ("participant", "area_manager", "admin"): raise ValueError()
            async with conn.cursor() as cursor:
                await cursor.execute("SELECT quiz_id FROM live_quiz_sessions WHERE id=:session_id AND status='active'",session_id=int(session_id));session=await cursor.fetchone()
                if not session: raise ValueError()
                await cursor.execute("SELECT COUNT(*) FROM live_session_participants WHERE session_id=:session_id AND user_id=:user_id",session_id=int(session_id),user_id=user_id)
                if int((await cursor.fetchone())[0])==0:await cursor.execute("INSERT INTO live_session_participants(session_id,user_id,status,total_points) VALUES(:session_id,:user_id,'joined',0)",session_id=int(session_id),user_id=user_id);await conn.commit()
        except Exception:
            await websocket.close(code=1008,reason="Live session unavailable");return
    # 2. Register Participant Connection
    await manager.connect(websocket, room_id=session_id, user_id=user_id)

    try:
        while True:
            # Parse incoming payload from the participant client
            data = await websocket.receive_json()
            action = data.get("action")

            if action == "submit_answer":
                question_id = data.get("question_id")
                option_id = data.get("selected_option_id")
                time_taken = data.get("time_taken", 0)

                # Write answer directly to Oracle DB asynchronously
                async with database._pool.acquire() as conn:
                    async with conn.cursor() as cursor:
                        # Fetch correct option to calculate points
                        check_q = """SELECT o.is_correct FROM options o JOIN questions q ON q.id=o.question_id
                                     JOIN live_quiz_sessions s ON s.quiz_id=q.quiz_id
                                     WHERE o.id=:option_id AND q.id=:question_id AND s.id=:session_id AND s.status='active' AND NVL(s.is_question_closed,0)=0"""
                        await cursor.execute(check_q, option_id=option_id,question_id=question_id,session_id=int(session_id))
                        opt_row = await cursor.fetchone()
                        
                        is_correct = 1 if opt_row and opt_row[0] else 0
                        if not opt_row:
                            await manager.send_personal_message({"event":"answer_received","success":False,"message":"Question is closed or answer is invalid"},room_id=session_id,user_id=user_id)
                            continue
                        await cursor.execute("SELECT COUNT(*) FROM live_session_answers WHERE session_id=:session_id AND user_id=:user_id AND question_id=:question_id",session_id=int(session_id),user_id=user_id,question_id=question_id)
                        if int((await cursor.fetchone())[0])>0:
                            await manager.send_personal_message({"event":"answer_received","success":False,"message":"Answer already submitted"},room_id=session_id,user_id=user_id)
                            continue
                        points_earned = 10 if is_correct else 0 # Simple stub calculation

                        # Insert into live session answers
                        insert_query = """
                            INSERT INTO live_session_answers 
                            (session_id, user_id, question_id, selected_option_id, is_correct, time_taken, points_earned) 
                            VALUES (:session_id, :user_id, :question_id, :option_id, :is_correct, :time_taken, :points_earned)
                        """
                        try:
                            await cursor.execute(insert_query, 
                                session_id=session_id, 
                                user_id=user_id, 
                                question_id=question_id, 
                                option_id=option_id,
                                is_correct=is_correct,
                                time_taken=time_taken,
                                points_earned=points_earned
                            )
                            
                            # Update total points for the participant
                            update_pts = """
                                UPDATE live_session_participants 
                                SET total_points = total_points + :points_earned, status = 'submitted'
                                WHERE session_id = :session_id AND user_id = :user_id
                            """
                            await cursor.execute(update_pts, points_earned=points_earned, session_id=session_id, user_id=user_id)
                            await conn.commit()
                        except Exception:
                            await conn.rollback()
                
                # Acknowledge submission to the user
                await manager.send_personal_message({
                    "event": "answer_received",
                    "success": True,
                    "points_earned": points_earned
                }, room_id=session_id, user_id=user_id)

                # Optionally broadcast to trainer that someone submitted (via targeted user_id or a general trainer channel)
                # This could be handled by triggering a leaderboard refresh ping to the room

    except WebSocketDisconnect:
        manager.disconnect(room_id=session_id, user_id=user_id)
