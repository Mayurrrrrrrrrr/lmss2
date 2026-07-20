from pydantic import BaseModel
from typing import List

class TrainerKPIs(BaseModel):
    avg_course_progress: float
    total_courses_assigned: int
    standalone_quiz_avg_score: float
    total_quizzes_assigned: int

class TrainerDashboardResponse(BaseModel):
    success: bool = True
    kpis: TrainerKPIs

class ProgressMetrics(BaseModel):
    total_participants: int
    active_participants: int
    average_score: float
    pending_evaluations: int

class AssignedCourse(BaseModel):
    id: str
    title: str
    participant_count: int
    completion_rate: float

class UpcomingQuiz(BaseModel):
    id: str
    title: str
    scheduled_time: str
    course_name: str

class TrainerDashboardDataResponse(BaseModel):
    metrics: ProgressMetrics
    assigned_courses: List[AssignedCourse]
    upcoming_quizzes: List[UpcomingQuiz]

