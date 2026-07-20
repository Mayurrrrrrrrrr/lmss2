from pydantic import BaseModel, Field
from typing import Optional

class SaveProgressRequest(BaseModel):
    chapter_id: int
    progress: int = Field(ge=0, le=100)
    time_spent: int = Field(ge=0, description="Time spent in seconds during this session")

class SaveProgressResponse(BaseModel):
    success: bool = True
    progress: int
    time_spent: int
    is_completed: bool
    course_just_completed: bool = False
    course_id: Optional[int] = None
    anti_cheat_warning: Optional[str] = None
