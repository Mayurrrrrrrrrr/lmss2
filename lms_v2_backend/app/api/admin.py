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
        return {"success": True, "users": [
            {"id": r[0], "username": r[1], "full_name": r[2], "role": r[3], "created_at": r[4]}
            for r in rows
        ]}

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
        return {"success": True, "participants": [
            {"id": r[0], "username": r[1], "full_name": r[2], "role": r[3], "created_at": r[4]}
            for r in rows
        ]}

@router.get("/stores")
async def get_stores(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, store_code, store_name, city, created_at FROM stores ORDER BY id")
        rows = await cursor.fetchall()
        return {"success": True, "stores": [
            {
                "id": r[0], "store_code": r[1], "store_name": r[2],
                "city": r[3], "location": r[3], "created_at": r[4]
            }
            for r in rows
        ]}

@router.get("/designations")
async def get_designations(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, designation_name, created_at FROM designations ORDER BY id")
        rows = await cursor.fetchall()
        return {"success": True, "designations": [
            {"id": r[0], "designation_name": r[1], "name": r[1], "created_at": r[2]}
            for r in rows
        ]}

@router.get("/departments")
async def get_departments(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, department_name, created_at FROM departments ORDER BY id")
        rows = await cursor.fetchall()
        return {"success": True, "departments": [
            {"id": r[0], "department_name": r[1], "name": r[1], "created_at": r[2]}
            for r in rows
        ]}

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
            SELECT u.id, u.username, p.full_name, u.role, u.created_at,
                   p.store_code, p.city, p.designation, p.department,
                   (SELECT COUNT(*) FROM user_profiles sub WHERE sub.reporting_manager_id = u.id) AS subordinate_count
            FROM users u
            LEFT JOIN user_profiles p ON u.id = p.user_id
            WHERE u.role IN ('participant', 'area_manager')
            ORDER BY u.created_at DESC
        """)
        rows = await cursor.fetchall()
        return [
            {
                "id": r[0],
                "username": r[1],
                "full_name": r[2] or "",
                "role": r[3],
                "created_at": r[4],
                "store_code": r[5] or "",
                "city": r[6] or "",
                "designation": r[7] or "",
                "department": r[8] or "",
                "subordinate_count": int(r[9] or 0)
            }
            for r in rows
        ]

@router.get("/team")
async def get_team_members(
    manager_id: int,
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT u.id, u.username, p.full_name, u.role, p.store_code, p.city, p.designation, p.department
            FROM users u
            JOIN user_profiles p ON u.id = p.user_id
            WHERE p.reporting_manager_id = :manager_id
            ORDER BY p.full_name
        """, manager_id=manager_id)
        rows = await cursor.fetchall()
        return [
            {
                "id": r[0],
                "username": r[1],
                "full_name": r[2] or "",
                "role": r[3],
                "store_code": r[4] or "",
                "city": r[5] or "",
                "designation": r[6] or "",
                "department": r[7] or ""
            }
            for r in rows
        ]

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


@router.get("/pages")
async def get_pages(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, url_slug, title, html_content, is_public, created_at FROM static_pages ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "slug": r[1], "title": r[2], "content": str(r[3]), "is_active": bool(r[4]), "created_at": r[5]} for r in rows]


@router.post("/pages")
async def create_page(
    page: dict,
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        # Get next ID
        await cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM static_pages")
        next_id = (await cursor.fetchone())[0]
        await cursor.execute("""
            INSERT INTO static_pages (id, url_slug, title, html_content, is_public, created_by)
            VALUES (:1, :2, :3, :4, :5, :6)
        """, (next_id, page.get("slug"), page.get("title"), page.get("content"), 1 if page.get("is_active", True) else 0, current_user.id))
        await conn.commit()
        return {"success": True, "id": next_id}


@router.get("/logs")
async def get_logs(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT e.id, e.created_at, e.error_level, e.message, u.username
            FROM system_errors e
            LEFT JOIN users u ON e.user_id = u.id
            ORDER BY e.created_at DESC
            FETCH FIRST 50 ROWS ONLY
        """)
        rows = await cursor.fetchall()
        return [
            {
                "id": r[0],
                "timestamp": r[1],
                "level": r[2],
                "message": r[3],
                "user": r[4] or "system"
            }
            for r in rows
        ]


@router.get("/recycle")
async def get_recycle(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        # Courses
        await cursor.execute("SELECT id, title, created_by, deleted_at FROM courses WHERE deleted_at IS NOT NULL")
        courses_rows = await cursor.fetchall()
        courses = [{"id": r[0], "type": "course", "title": r[1], "trainer": str(r[2]), "deleted_at": r[3], "extra_info": ""} for r in courses_rows]

        # Modules
        await cursor.execute("SELECT m.id, m.title, c.title, m.deleted_at FROM modules m JOIN courses c ON m.course_id = c.id WHERE m.deleted_at IS NOT NULL")
        modules_rows = await cursor.fetchall()
        modules = [{"id": r[0], "type": "module", "title": r[1], "trainer": "", "deleted_at": r[3], "extra_info": f"Course: {r[2]}"} for r in modules_rows]

        # Chapters
        await cursor.execute("SELECT ch.id, ch.title, m.title, ch.deleted_at FROM chapters ch JOIN modules m ON ch.module_id = m.id WHERE ch.deleted_at IS NOT NULL")
        chapters_rows = await cursor.fetchall()
        chapters = [{"id": r[0], "type": "chapter", "title": r[1], "trainer": "", "deleted_at": r[3], "extra_info": f"Module: {r[2]}"} for r in chapters_rows]

        return courses + modules + chapters


import psutil
import app.core.database as db_module

@router.get("/diagnostics")
async def get_diagnostics(
    current_user: UserProfile = Depends(require_admin)
):
    # Oracle pool diagnostics
    pool_opened = 0
    pool_busy = 0
    if db_module._pool:
        try:
            pool_opened = db_module._pool.opened
            pool_busy = db_module._pool.busy
        except Exception:
            pass

    # CPU and memory diagnostics
    cpu_percent = psutil.cpu_percent()
    virtual_mem = psutil.virtual_memory()
    
    return {
        "success": True,
        "database": {
            "status": "connected" if db_module._pool else "disconnected",
            "opened_connections": pool_opened,
            "busy_connections": pool_busy,
        },
        "system": {
            "cpu_usage_percent": cpu_percent,
            "memory_usage_percent": virtual_mem.percent,
            "memory_available_mb": round(virtual_mem.available / (1024 * 1024), 2),
        }
    }
