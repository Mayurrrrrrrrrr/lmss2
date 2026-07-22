from pydantic import BaseModel, Field
from typing import Optional

# -------------------------------------------------------------------
# Request Schemas
# -------------------------------------------------------------------

class LoginRequest(BaseModel):
    """
    Payload expected by the POST /api/auth/login endpoint,
    mirroring the payload defined in the Flutter app's api_service.dart.
    """
    username: str
    password: str
    app_version: Optional[str] = None

# -------------------------------------------------------------------
# Shared / Nested Schemas
# -------------------------------------------------------------------

class UserProfile(BaseModel):
    """
    Core user data returned in authentication and profile requests.
    Field names explicitly match the legacy PHP JSON structures.
    """
    id: int
    username: str
    full_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    designation: Optional[str] = None
    department: Optional[str] = None
    role: str
    is_first_login: bool

# -------------------------------------------------------------------
# Response Schemas
# -------------------------------------------------------------------

class LoginResponse(BaseModel):
    """
    Response returned upon successful authentication.
    """
    success: bool = True
    token: str
    expires_at: int
    user: UserProfile

class MeResponse(BaseModel):
    """
    Response returned for GET /api/auth/me (Profile lookup).
    """
    success: bool = True
    user: UserProfile

class ProfileUpdateRequest(BaseModel):
    full_name: str = Field(min_length=1, max_length=150)
    email: Optional[str] = Field(default=None, max_length=255)
    phone: Optional[str] = Field(default=None, max_length=50)

class ChangePasswordRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=200)
    new_password: str = Field(min_length=8, max_length=200)
