from fastapi import APIRouter, Depends, Request
import oracledb
from app.core.database import get_db_connection
from app.core.security import create_access_token, get_current_user
from app.services.user_service import UserService
from app.schemas.user import (
    ChangePasswordRequest,
    LoginRequest,
    LoginResponse,
    MeResponse,
    ProfileUpdateRequest,
    UserProfile,
)
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
import bcrypt

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

@router.put("/profile", response_model=MeResponse)
async def update_profile(
    profile: ProfileUpdateRequest,
    current_user: UserProfile = Depends(get_current_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection),
):
    full_name = profile.full_name.strip()
    email = profile.email.strip() if profile.email else None
    phone = profile.phone.strip() if profile.phone else None
    if not full_name:
        raise HTTPException(status_code=422, detail="Full name is required.")

    async with conn.cursor() as cursor:
        if email:
            await cursor.execute("""
                SELECT 1 FROM users u
                LEFT JOIN user_profiles p ON p.user_id=u.id
                WHERE u.id<>:user_id AND (LOWER(u.email)=LOWER(:email) OR LOWER(p.email_id)=LOWER(:email))
                FETCH FIRST 1 ROWS ONLY
            """, user_id=current_user.id, email=email)
            if await cursor.fetchone():
                raise HTTPException(status_code=409, detail="That email address is already in use.")
        await cursor.execute("""
            MERGE INTO user_profiles p
            USING (SELECT :user_id user_id FROM dual) src
            ON (p.user_id = src.user_id)
            WHEN MATCHED THEN UPDATE SET
                p.full_name = :full_name,
                p.email_id = :email,
                p.mobile_number = :phone
            WHEN NOT MATCHED THEN INSERT
                (user_id, full_name, email_id, mobile_number)
                VALUES (:user_id, :full_name, :email, :phone)
        """, user_id=current_user.id, full_name=full_name, email=email, phone=phone)
        await cursor.execute(
            "UPDATE users SET full_name=:full_name, email=:email WHERE id=:user_id",
            full_name=full_name,
            email=email,
            user_id=current_user.id,
        )
        await conn.commit()

    refreshed = await UserService(conn).get_user_by_id(current_user.id)
    return MeResponse(success=True, user=refreshed)

@router.post("/change_password")
async def change_password(
    password: ChangePasswordRequest,
    current_user: UserProfile = Depends(get_current_user),
    conn: oracledb.AsyncConnection = Depends(get_db_connection),
):
    if password.current_password == password.new_password:
        raise HTTPException(status_code=422, detail="New password must be different from the current password.")

    async with conn.cursor() as cursor:
        await cursor.execute("SELECT password FROM users WHERE id=:user_id", user_id=current_user.id)
        row = await cursor.fetchone()
        if not row or not bcrypt.checkpw(password.current_password.encode("utf-8"), row[0].encode("utf-8")):
            raise HTTPException(status_code=400, detail="Current password is incorrect.")

        hashed = bcrypt.hashpw(password.new_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        await cursor.execute(
            "UPDATE users SET password=:password, is_first_login=0 WHERE id=:user_id",
            password=hashed,
            user_id=current_user.id,
        )
        await conn.commit()

    return {"success": True, "message": "Password changed successfully."}
