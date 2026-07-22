from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
import oracledb
from app.core.config import settings
from app.core.database import get_db_connection
from app.services.user_service import UserService
from app.schemas.user import UserProfile

# The tokenUrl must match our login route
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v2/auth/login")
ALGORITHM = "HS256"

def create_access_token(data: dict) -> str:
    """
    Generates a lightweight JWT. 
    Does not rely on massive external cryptographic libraries to save RAM.
    """
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(
    token: str = Depends(oauth2_scheme), 
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
) -> UserProfile:
    """
    Dependency to validate the JWT and fetch the current user profile statelessly.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[ALGORITHM])
        user_id_str: str = payload.get("sub")
        if user_id_str is None:
            raise credentials_exception
        user_id = int(user_id_str)
    except (JWTError, ValueError):
        raise credentials_exception
    
    # Instantiate the user service and fetch the user
    user_service = UserService(conn)
    try:
        user = await user_service.get_user_by_id(user_id)
        return user
    except HTTPException:
        # If user is deleted or role changed
        raise credentials_exception

async def require_user(current_user: UserProfile = Depends(get_current_user)) -> UserProfile:
    """
    Dependency that ensures a user is authenticated and returns their profile.
    """
    return current_user

async def require_admin(current_user: UserProfile = Depends(get_current_user)) -> UserProfile:
    """
    RBAC Dependency: Validates that the active user is an Admin.
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Requires admin privileges."
        )
    return current_user

async def require_trainer_or_admin(current_user: UserProfile = Depends(get_current_user)) -> UserProfile:
    """
    RBAC Dependency: Validates that the active user is a Trainer or Admin.
    """
    if current_user.role not in ["trainer", "admin"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to access this resource."
        )
    return current_user

async def require_trainer(current_user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if current_user.role not in ["trainer", "admin"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Requires trainer privileges.")
    return current_user

async def require_manager(current_user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if current_user.role not in ["area_manager", "admin"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Requires area manager privileges.")
    return current_user
