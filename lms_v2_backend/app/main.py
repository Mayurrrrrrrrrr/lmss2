from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
from app.core.database import init_db_pool, close_db_pool
from app.core.config import settings
from app.api.auth import router as auth_router
from app.api.courses import router as courses_router
from app.api.analytics import router as analytics_router
from app.api.live_quiz import router as live_quiz_router
from app.api.gamification import router as gamification_router
from app.api.admin import router as admin_router
from app.api.trainer import router as trainer_router
from app.api.trainer_content import router as trainer_content_router
from app.api.trainer_quizzes import router as trainer_quizzes_router
from app.api.roleplays import router as roleplays_router
from app.api.tasks import router as tasks_router
from app.api.portal_gamification import router as portal_gamification_router
from app.api.notifications import router as notifications_router
from app.api.reports import router as reports_router
from app.api.configuration import router as configuration_router
from app.api.ai_tools import router as ai_tools_router
from app.api.utilities import router as utilities_router
from app.api.manager import router as manager_router
from app.api.courses_read import router as courses_read_router
from app.api.quizzes_read import router as quizzes_read_router
from app.api.leaderboard import router as leaderboard_router
from app.api.fcm import router as fcm_router
from app.api.media import router as media_router
from app.api.participant import router as participant_router
from app.core.websocket_manager import manager
import app.core.database as db

# NOTE: Refer to the architecture and ERD mapped in v1_analysis_for_v2.md
# for structuring APIs corresponding to V1 workflows.

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Initialize shared services for the application lifecycle.
    await init_db_pool()

    # Hydrate WebSocket rooms from Oracle so sessions survive restarts.
    if db._pool:
        await manager.hydrate_rooms(db._pool)

    yield
    # Cleanup resources on shutdown.
    await close_db_pool()

# Keep production API documentation disabled to reduce exposure and overhead.
is_prod = settings.ENVIRONMENT == "production"

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Lean and memory-efficient backend for Firefly LMS.",
    version="2.0.0",
    docs_url=None if is_prod else "/api/docs",
    redoc_url=None,  # Always disabled in this deployment.
    openapi_url=None if is_prod else "/api/openapi.json",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Automated Real-Time Error Logger Middleware
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    error_msg = f"{type(exc).__name__}: {str(exc)}"
    path_info = str(request.url.path)

    # Insert real error log asynchronously into Oracle DB SYSTEM_ERRORS
    if db._pool:
        try:
            async with db._pool.acquire() as conn:
                async with conn.cursor() as cursor:
                    await cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM system_errors")
                    next_id = (await cursor.fetchone())[0]
                    await cursor.execute("""
                        INSERT INTO system_errors (id, error_level, message, file_path, line_number, created_at)
                        VALUES (:1, 'ERROR', :2, :3, 0, CURRENT_TIMESTAMP)
                    """, (next_id, error_msg[:4000], path_info[:500]))
                    await conn.commit()
        except Exception:
            pass

    return JSONResponse(
        status_code=500,
        content={"detail": "An internal server error occurred."}
    )

# Register API Routers
app.include_router(auth_router, prefix="/api/v2/auth", tags=["Auth"])
app.include_router(courses_router, prefix="/api/v2/courses", tags=["Courses"])
app.include_router(analytics_router, prefix="/api/v2/analytics", tags=["Analytics"])
app.include_router(live_quiz_router, prefix="/api/v2/live", tags=["Live Quiz"])
app.include_router(gamification_router, prefix="/api/v2/gamification", tags=["Gamification"])
app.include_router(admin_router, prefix="/api/v2/admin", tags=["Admin"])
app.include_router(trainer_router, prefix="/api/v2/trainer", tags=["Trainer"])
app.include_router(trainer_content_router, prefix="/api/v2/trainer", tags=["Trainer Content"])
app.include_router(trainer_quizzes_router, prefix="/api/v2/trainer", tags=["Trainer Quizzes"])
app.include_router(roleplays_router, prefix="/api/v2", tags=["Roleplays"])
app.include_router(tasks_router, prefix="/api/v2", tags=["Operational Tasks"])
app.include_router(portal_gamification_router, prefix="/api/v2", tags=["Portal Gamification"])
app.include_router(notifications_router, prefix="/api/v2", tags=["Notifications"])
app.include_router(reports_router, prefix="/api/v2", tags=["Reports"])
app.include_router(configuration_router, prefix="/api/v2", tags=["Configuration"])
app.include_router(ai_tools_router, prefix="/api/v2/ai", tags=["AI Tools"])
app.include_router(utilities_router, prefix="/api/v2", tags=["Utilities"])
app.include_router(manager_router, prefix="/api/v2/manager", tags=["Manager"])

# Mobile and participant read endpoints.
app.include_router(participant_router, prefix="/api/v2", tags=["Participant (Mobile)"])
app.include_router(courses_read_router, prefix="/api/v2", tags=["Courses (Mobile)"])
app.include_router(quizzes_read_router, prefix="/api/v2", tags=["Quizzes (Mobile)"])
app.include_router(leaderboard_router, prefix="/api/v2", tags=["Leaderboard"])
app.include_router(fcm_router, prefix="/api/v2", tags=["FCM Notifications"])
app.include_router(media_router, prefix="/api/v2", tags=["Media"])

@app.get("/api/health")
async def health_check():
    """Minimal health check endpoint for monitoring."""
    return {"status": "ok", "message": "Firefly LMS V2 Backend is running."}
