from fastapi import APIRouter, Depends, Request
import oracledb
from app.core.database import get_db_connection
from app.core.security import create_access_token, get_current_user
from app.services.user_service import UserService
from app.schemas.user import LoginRequest, LoginResponse, MeResponse, UserProfile
from datetime import datetime, timedelta, timezone
from app.core.config import settings

router = APIRouter()

@router.post("/login", response_model=LoginResponse)
async def login(
    request: Request,
    login_data: LoginRequest,
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    """
    Authenticates the user and returns a stateless JWT.
    Replaces the stateful V1 /api/auth/login.php.
    """
    # Extract client IP for lockout protection
    client_ip = request.client.host if request.client else "127.0.0.1"
    
    user_service = UserService(conn)
    
    # This will raise HTTPExceptions on failure/lockout
    user_profile = await user_service.authenticate_user(login_data, client_ip)
    is_browser = "mozilla" in request.headers.get("user-agent", "").lower()
    if login_data.app_version and user_profile.role == "participant" and not is_browser:
        async with conn.cursor() as cursor:
            await cursor.execute("UPDATE user_profiles SET android_app_version=:version,last_app_ping=SYSTIMESTAMP WHERE user_id=:user_id", version=login_data.app_version, user_id=user_profile.id)
            await conn.commit()
    
    # Generate stateless JWT token
    access_token = create_access_token(data={"sub": str(user_profile.id)})
    
    # Calculate expiry timestamp matching V1 structure
    expires_at = int((datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)).timestamp())
    
    return LoginResponse(
        success=True,
        token=access_token,
        expires_at=expires_at,
        user=user_profile
    )

@router.get("/me", response_model=MeResponse)
async def get_me(
    current_user: UserProfile = Depends(get_current_user)
):
    """
    Returns the current logged-in user's profile.
    Replaces V1 /api/auth/me.php.
    """
    return MeResponse(
        success=True,
        user=current_user
    )

from pydantic import BaseModel
from app.services.email_service import send_reset_password_email
import secrets
from fastapi import HTTPException

class ForgotPasswordRequest(BaseModel):
    email: str

@router.post("/forgot_password")
async def forgot_password(
    req: ForgotPasswordRequest,
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id FROM users WHERE email = :email AND status = 'active'", email=req.email)
        user = await cursor.fetchone()
        
        # Always return success to prevent email enumeration
        if user:
            reset_token = secrets.token_urlsafe(32)
            
            # Upsert into password_resets
            await cursor.execute("""
                MERGE INTO password_resets pr
                USING (SELECT :email as email, :token as token, CURRENT_TIMESTAMP + INTERVAL '1' HOUR as expires FROM dual) s
                ON (pr.email = s.email)
                WHEN MATCHED THEN
                    UPDATE SET token_hash = s.token, expires_at = s.expires
                WHEN NOT MATCHED THEN
                    INSERT (email, token_hash, expires_at) VALUES (s.email, s.token, s.expires)
            """, email=req.email, token=reset_token)
            await conn.commit()
            
            # Dispatch async email
            await send_reset_password_email(req.email, reset_token)
            
    return {"success": True, "message": "If the email address exists, a password reset link has been sent."}
