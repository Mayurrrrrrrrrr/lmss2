from pydantic import BaseModel
from typing import List

class CourseMetric(BaseModel):
    course_id: int
    total_assigned: int
    total_completed: int
    completion_rate_percent: float
    avg_progress_percent: float
    total_time_spent_seconds: int
    popularity_rank: int

class AggregatedAnalyticsResponse(BaseModel):
    success: bool = True
    metrics: List[CourseMetric]
