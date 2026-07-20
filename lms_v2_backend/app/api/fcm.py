from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import Any
from app.core.security import require_user
from app.core.database import get_db

router = APIRouter(prefix="/fcm", tags=["FCM Notifications"])

class FCMRegisterReq(BaseModel):
    token: str
    device_type: str = "android"

@router.post("/register")
async def register_fcm_token(req: FCMRegisterReq, user_id: int = Depends(require_user)) -> Any:
    async with get_db() as db:
        async with db.cursor() as cursor:
            # Upsert FCM token to Oracle DB to track active device for push notifications
            await cursor.execute("""
                MERGE INTO user_devices d
                USING (SELECT :user_id as user_id, :token as fcm_token, :device_type as device_type FROM dual) s
                ON (d.user_id = s.user_id AND d.device_type = s.device_type)
                WHEN MATCHED THEN
                    UPDATE SET fcm_token = s.fcm_token, last_active = CURRENT_TIMESTAMP
                WHEN NOT MATCHED THEN
                    INSERT (user_id, fcm_token, device_type, created_at)
                    VALUES (s.user_id, s.fcm_token, s.device_type, CURRENT_TIMESTAMP)
            """, user_id=user_id, token=req.token, device_type=req.device_type)
            await db.commit()
            
            return {"success": True, "message": "FCM token registered successfully"}
