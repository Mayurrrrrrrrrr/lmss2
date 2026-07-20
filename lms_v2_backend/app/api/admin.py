from fastapi import APIRouter, Depends, HTTPException, status
import oracledb
from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile
from app.schemas.admin import AdminDashboardResponse, DashboardStats, RecentLogin, RecentPage

router = APIRouter()

async def require_admin(current_user: UserProfile = Depends(get_current_user)) -> UserProfile:
    """
    Strict RBAC for Admin-only routes.
    """
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Requires administrator privileges."
        )
    return current_user

@router.get("/dashboard", response_model=AdminDashboardResponse)
async def get_admin_dashboard(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    """
    Replaces /admin/dashboard.php.
    Returns optimized metric summaries using unified SQL queries instead of 
    multiple standalone COUNT() executions like the legacy PHP script.
    """
    async with conn.cursor() as cursor:
        # 1. Unified User Stats Query (Replaces 6 separate PHP queries!)
        await cursor.execute("""
            SELECT 
                COUNT(*) as total_users,
                COUNT(CASE WHEN role = 'trainer' THEN 1 END) as total_trainers,
                COUNT(CASE WHEN role = 'participant' THEN 1 END) as total_participants,
                COUNT(CASE WHEN created_at > TRUNC(SYSDATE) - 7 THEN 1 END) as new_users,
                COUNT(CASE WHEN role = 'trainer' AND created_at > TRUNC(SYSDATE) - 7 THEN 1 END) as new_trainers,
                COUNT(CASE WHEN role = 'participant' AND created_at > TRUNC(SYSDATE) - 7 THEN 1 END) as new_participants
            FROM users
        """)
        u_stats = await cursor.fetchone()
        
        # 2. Unified Course Stats Query (Replaces 2 PHP queries)
        await cursor.execute("""
            SELECT 
                COUNT(*) as total_courses,
                COUNT(CASE WHEN created_at > TRUNC(SYSDATE) - 7 THEN 1 END) as new_courses
            FROM courses
        """)
        c_stats = await cursor.fetchone()
        
        # 3. Unified Pages Stats Query (Replaces 2 PHP queries)
        await cursor.execute("""
            SELECT 
                COUNT(*) as total_pages,
                COUNT(CASE WHEN created_at > TRUNC(SYSDATE) - 7 THEN 1 END) as new_pages
            FROM static_pages
        """)
        p_stats = await cursor.fetchone()

        stats = DashboardStats(
            total_users=u_stats[0] if u_stats else 0,
            total_trainers=u_stats[1] if u_stats else 0,
            total_participants=u_stats[2] if u_stats else 0,
            new_users=u_stats[3] if u_stats else 0,
            new_trainers=u_stats[4] if u_stats else 0,
            new_participants=u_stats[5] if u_stats else 0,
            total_courses=c_stats[0] if c_stats else 0,
            new_courses=c_stats[1] if c_stats else 0,
            total_pages=p_stats[0] if p_stats else 0,
            new_pages=p_stats[1] if p_stats else 0
        )

        # 4. Fetch Recent Logins
        await cursor.execute("""
            SELECT u.username, u.role, ll.login_time
            FROM login_logs ll
            JOIN users u ON ll.user_id = u.id
            ORDER BY ll.login_time DESC
            FETCH FIRST 5 ROWS ONLY
        """)
        login_rows = await cursor.fetchall()
        recent_logins = [
            RecentLogin(username=r[0], role=r[1], login_time=r[2]) for r in login_rows
        ]

        # 5. Fetch Recent Pages
        await cursor.execute("""
            SELECT id, title, url_slug, created_at 
            FROM static_pages 
            ORDER BY created_at DESC 
            FETCH FIRST 6 ROWS ONLY
        """)
        page_rows = await cursor.fetchall()
        recent_pages = [
            RecentPage(id=r[0], title=r[1], url_slug=r[2], created_at=r[3]) for r in page_rows
        ]

    return AdminDashboardResponse(
        success=True,
        stats=stats,
        recent_logins=recent_logins,
        recent_pages=recent_pages
    )

@router.get("/users")
async def get_users(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT u.id, u.username, p.full_name, u.role, u.created_at
            FROM users u
            LEFT JOIN user_profiles p ON u.id = p.user_id
            ORDER BY u.created_at DESC
        """)
        rows = await cursor.fetchall()
        return [{"id": r[0], "username": r[1], "full_name": r[2], "role": r[3], "created_at": r[4]} for r in rows]

@router.get("/participants")
async def get_participants(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT u.id, u.username, p.full_name, u.role, u.created_at
            FROM users u
            LEFT JOIN user_profiles p ON u.id = p.user_id
            WHERE u.role = 
'
participant
'

            ORDER BY u.created_at DESC
        """)
        rows = await cursor.fetchall()
        return [{"id": r[0], "username": r[1], "full_name": r[2], "role": r[3], "created_at": r[4]} for r in rows]

@router.get("/stores")
async def get_stores(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, store_code, store_name, state, city, created_at FROM stores ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "store_code": r[1], "store_name": r[2], "state": r[3], "city": r[4], "created_at": r[5]} for r in rows]

@router.get("/designations")
async def get_designations(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, designation_name, created_at FROM designations ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "name": r[1], "created_at": r[2]} for r in rows]

@router.get("/departments")
async def get_departments(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, department_name, created_at FROM departments ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "name": r[1], "created_at": r[2]} for r in rows]


@router.get("/users")
async def get_users(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT u.id, u.username, p.full_name, u.role, u.created_at
            FROM users u
            LEFT JOIN user_profiles p ON u.id = p.user_id
            ORDER BY u.created_at DESC
        """)
        rows = await cursor.fetchall()
        return [{"id": r[0], "username": r[1], "full_name": r[2], "role": r[3], "created_at": r[4]} for r in rows]

@router.get("/participants")
async def get_participants(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT u.id, u.username, p.full_name, u.role, u.created_at
            FROM users u
            LEFT JOIN user_profiles p ON u.id = p.user_id
            WHERE u.role = 'participant'
            ORDER BY u.created_at DESC
        """)
        rows = await cursor.fetchall()
        return [{"id": r[0], "username": r[1], "full_name": r[2], "role": r[3], "created_at": r[4]} for r in rows]

@router.get("/stores")
async def get_stores(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, store_code, store_name, state, city, created_at FROM stores ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "store_code": r[1], "store_name": r[2], "state": r[3], "city": r[4], "created_at": r[5]} for r in rows]

@router.get("/designations")
async def get_designations(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, designation_name, created_at FROM designations ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "name": r[1], "created_at": r[2]} for r in rows]

@router.get("/departments")
async def get_departments(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, department_name, created_at FROM departments ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "name": r[1], "created_at": r[2]} for r in rows]
