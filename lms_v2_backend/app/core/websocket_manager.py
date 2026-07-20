from fastapi import WebSocket
from typing import Dict, Any

class WebSocketManager:
    """
    Lightweight, in-memory WebSocket connection manager.
    Eliminates the need for a Redis instance by using native Python dictionaries,
    keeping memory footprint minimal while supporting real-time Live Quizzes.
    """
    def __init__(self):
        # Structure: rooms[room_id][user_id] = WebSocket
        # Example: {"quiz_session_1": {105: <WebSocket>, 204: <WebSocket>}}
        self.rooms: Dict[str, Dict[int, WebSocket]] = {}

    async def connect(self, websocket: WebSocket, room_id: str, user_id: int):
        """
        Accepts the WebSocket connection and maps it to the specific user in the room.
        """
        await websocket.accept()
        if room_id not in self.rooms:
            self.rooms[room_id] = {}
        
        # If user reconnects, overwrite their old socket reference
        self.rooms[room_id][user_id] = websocket

    def disconnect(self, room_id: str, user_id: int):
        """
        Removes the user's socket from the room.
        Automatically garbage-collects empty rooms to preserve RAM.
        """
        if room_id in self.rooms:
            if user_id in self.rooms[room_id]:
                del self.rooms[room_id][user_id]
            
            # Clean up empty rooms completely
            if not self.rooms[room_id]:
                del self.rooms[room_id]

    async def send_personal_message(self, message: dict[str, Any], room_id: str, user_id: int):
        """
        Send a targeted JSON payload to a specific user.
        Useful for sending private scores or anti-cheat warnings.
        """
        if room_id in self.rooms and user_id in self.rooms[room_id]:
            ws = self.rooms[room_id][user_id]
            try:
                await ws.send_json(message)
            except RuntimeError:
                # Connection dropped mid-flight
                self.disconnect(room_id, user_id)

    async def broadcast_to_room(self, message: dict[str, Any], room_id: str, exclude_user_id: int = None):
        """
        Broadcasts a JSON payload to everyone currently in the room.
        Useful for triggering "Next Question" or "Leaderboard Updates".
        """
        if room_id in self.rooms:
            # Create a list of items to avoid Dictionary Changed Size During Iteration errors if someone disconnects
            for uid, ws in list(self.rooms[room_id].items()):
                if exclude_user_id and uid == exclude_user_id:
                    continue
                try:
                    await ws.send_json(message)
                except Exception:
                    self.disconnect(room_id, uid)

    async def create_room(self, room_id: str, db_pool=None):
        """
        Creates a room in memory and persists the state to Oracle.
        """
        if room_id not in self.rooms:
            self.rooms[room_id] = {}
            
        if db_pool:
            async with db_pool.acquire() as conn:
                async with conn.cursor() as cursor:
                    # Upsert session state to active
                    await cursor.execute("""
                        MERGE INTO live_quiz_sessions s
                        USING (SELECT :room_id as session_id FROM dual) d
                        ON (s.session_id = d.session_id)
                        WHEN MATCHED THEN
                            UPDATE SET status = 'active', updated_at = CURRENT_TIMESTAMP
                        WHEN NOT MATCHED THEN
                            INSERT (session_id, status, created_at)
                            VALUES (d.session_id, 'active', CURRENT_TIMESTAMP)
                    """, room_id=room_id)
                    await conn.commit()

    async def close_room(self, room_id: str, db_pool=None):
        """
        Closes a room, disconnecting all users, and marks it closed in Oracle.
        """
        if room_id in self.rooms:
            for uid, ws in list(self.rooms[room_id].items()):
                try:
                    await ws.close()
                except Exception:
                    pass
            del self.rooms[room_id]

        if db_pool:
            async with db_pool.acquire() as conn:
                async with conn.cursor() as cursor:
                    await cursor.execute("""
                        UPDATE live_quiz_sessions 
                        SET status = 'closed', updated_at = CURRENT_TIMESTAMP 
                        WHERE session_id = :room_id
                    """, room_id=room_id)
                    await conn.commit()

    async def hydrate_rooms(self, db_pool):
        """
        Called on server startup to repopulate active rooms from the database,
        ensuring Live Quizzes survive a Uvicorn crash.
        """
        try:
            async with db_pool.acquire() as conn:
                async with conn.cursor() as cursor:
                    await cursor.execute("SELECT session_id FROM live_quiz_sessions WHERE status = 'active'")
                    rows = await cursor.fetchall()
                    for row in rows:
                        room_id = row[0]
                        if room_id not in self.rooms:
                            self.rooms[room_id] = {}
        except Exception as e:
            # Table might not exist yet if migrations haven't run
            pass

# Global singleton to be imported by route controllers
manager = WebSocketManager()
