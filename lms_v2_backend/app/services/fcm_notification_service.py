import os
import logging
import asyncio
import firebase_admin
from firebase_admin import credentials, messaging
from app.core.config import settings
from app.core.database import get_db

logger = logging.getLogger(__name__)

# Initialize Firebase App
_firebase_initialized = False

def init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return
    
    cred_path = settings.FIREBASE_CREDENTIALS_PATH
    if not os.path.exists(cred_path):
        logger.warning(f"Firebase credentials not found at {cred_path}. Push notifications will be disabled.")
        return

    try:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info("Firebase Admin SDK initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin SDK: {e}")

# Initialize eagerly on module load
init_firebase()

async def send_push_notification(user_id: int, title: str, body: str, data: dict = None) -> bool:
    """
    Query all active FCM tokens for a user and dispatch real-time push notifications.
    Safely executes blocking Firebase SDK calls inside an async thread pool.
    """
    if not _firebase_initialized:
        logger.warning("Push notification skipped: Firebase not initialized.")
        return False

    tokens = []
    # 1. Fetch tokens from Oracle DB
    try:
        async with get_db() as db:
            async with db.cursor() as cursor:
                await cursor.execute(
                    "SELECT fcm_token FROM user_devices WHERE user_id = :user_id",
                    user_id=user_id
                )
                rows = await cursor.fetchall()
                tokens = [row[0] for row in rows if row[0]]
    except Exception as e:
        logger.error(f"Database error while fetching FCM tokens for user {user_id}: {e}")
        return False

    if not tokens:
        logger.info(f"No active FCM tokens found for user {user_id}.")
        return False

    # 2. Construct Multicast Message
    # Data payloads must be strictly strings in FCM
    str_data = {k: str(v) for k, v in (data or {}).items()}
    
    message = messaging.MulticastMessage(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=str_data,
        tokens=tokens,
    )

    # 3. Dispatch via ThreadPool to prevent blocking the Uvicorn event loop
    try:
        response = await asyncio.to_thread(messaging.send_each_for_multicast, message)
        logger.info(f"FCM multicast sent to {len(tokens)} devices for user {user_id}. Success: {response.success_count}, Failed: {response.failure_count}")
        
        return response.success_count > 0
    except Exception as e:
        logger.error(f"Error sending FCM multicast to user {user_id}: {e}")
        return False
