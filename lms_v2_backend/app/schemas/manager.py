from pydantic import BaseModel
from typing import List

class StoreTelemetry(BaseModel):
    store_code: str
    store_name: str
    participants_count: int
    compliance_rate: float
    approved_verifications: int
    pending_verifications: int

class ManagerDashboardResponse(BaseModel):
    success: bool = True
    total_participants: int
    total_approved: int
    total_pending: int
    stores: List[StoreTelemetry]
