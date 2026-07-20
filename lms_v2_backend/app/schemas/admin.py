from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class RecentLogin(BaseModel):
    username: str
    role: str
    login_time: datetime

class RecentPage(BaseModel):
    id: int
    title: str
    url_slug: str
    created_at: datetime

class DashboardStats(BaseModel):
    total_users: int
    total_trainers: int
    total_participants: int
    new_users: int
    new_trainers: int
    new_participants: int
    total_courses: int
    new_courses: int
    total_pages: int
    new_pages: int

class AdminDashboardResponse(BaseModel):
    success: bool = True
    stats: DashboardStats
    recent_logins: List[RecentLogin]
    recent_pages: List[RecentPage]
