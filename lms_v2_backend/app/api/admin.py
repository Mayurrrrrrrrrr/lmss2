import psutil
from fastapi import APIRouter, Depends, HTTPException, status
from typing import Any
import oracledb
from app.core.security import require_admin
from app.core.database import get_db_connection
import app.core.database as db
from app.schemas.user import UserProfile

router = APIRouter()

@router.get("/dashboard")
async def get_dashboard(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
) -> Any:
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT COUNT(*) FROM users")
        total_users = (await cursor.fetchone())[0]

        await cursor.execute("SELECT COUNT(*) FROM users WHERE created_at >= TRUNC(SYSDATE, 'MM')")
        new_users_month = (await cursor.fetchone())[0]

        await cursor.execute("SELECT COUNT(*) FROM courses WHERE deleted_at IS NULL")
        total_courses = (await cursor.fetchone())[0]

        await cursor.execute("SELECT COUNT(*) FROM quizzes WHERE deleted_at IS NULL")
        total_quizzes = (await cursor.fetchone())[0]

        await cursor.execute("SELECT COUNT(*) FROM stores")
        total_stores = (await cursor.fetchone())[0]

        await cursor.execute("SELECT COUNT(*) FROM designations")
        total_designations = (await cursor.fetchone())[0]

        await cursor.execute("SELECT COUNT(*) FROM departments")
        total_departments = (await cursor.fetchone())[0]

        await cursor.execute("SELECT COUNT(*) FROM user_badges")
        total_certificates = (await cursor.fetchone())[0]

        await cursor.execute("""
            SELECT u.username, p.full_name, u.role, u.last_active
            FROM users u
            LEFT JOIN user_profiles p ON u.id = p.user_id
            WHERE u.last_active IS NOT NULL
            ORDER BY u.last_active DESC
            FETCH FIRST 10 ROWS ONLY
        """)
        login_rows = await cursor.fetchall()
        recent_logins = [
            {
                "username": r[0],
                "full_name": r[1] or r[0],
                "role": r[2],
                "login_time": r[3]
            }
            for r in login_rows
        ]

        return {
            "total_users": total_users,
            "new_users_month": new_users_month,
            "total_courses": total_courses,
            "total_quizzes": total_quizzes,
            "total_stores": total_stores,
            "total_designations": total_designations,
            "total_departments": total_departments,
            "total_certificates": total_certificates,
            "recent_logins": recent_logins
        }

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

@router.post("/participants/update")
async def update_participant(
    payload: dict,
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    user_id = payload.get("id")
    full_name = payload.get("full_name")
    store_code = payload.get("store_code")
    city = payload.get("city")
    designation = payload.get("designation")
    department = payload.get("department")
    role = payload.get("role", "participant")

    async with conn.cursor() as cursor:
        if role:
            await cursor.execute("UPDATE users SET role = :role WHERE id = :id", role=role, id=user_id)
            
        await cursor.execute("""
            MERGE INTO user_profiles p
            USING (SELECT :user_id AS user_id FROM dual) src
            ON (p.user_id = src.user_id)
            WHEN MATCHED THEN
                UPDATE SET full_name = :full_name, store_code = :store_code, city = :city, designation = :designation, department = :department
            WHEN NOT MATCHED THEN
                INSERT (user_id, full_name, store_code, city, designation, department)
                VALUES (:user_id, :full_name, :store_code, :city, :designation, :department)
        """, user_id=user_id, full_name=full_name, store_code=store_code, city=city, designation=designation, department=department)
        
        await conn.commit()
        return {"success": True, "message": "Participant profile updated successfully"}

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
        await cursor.execute("SELECT id, store_code, store_name, city FROM stores ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "code": r[1], "name": r[2], "city": r[3]} for r in rows]

@router.get("/designations")
async def get_designations(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, title, department FROM designations ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "title": r[1], "department": r[2]} for r in rows]

@router.get("/departments")
async def get_departments(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, name FROM departments ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "name": r[1]} for r in rows]

@router.get("/pages")
async def get_pages(
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id, url_slug, title, html_content, is_public, created_at FROM static_pages ORDER BY id")
        rows = await cursor.fetchall()
        return [{"id": r[0], "slug": r[1], "title": r[2], "content": str(r[3]), "is_active": bool(r[4]), "created_at": r[5]} for r in rows]

@router.get("/page_content")
async def get_page_by_slug(
    slug: str,
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT id, url_slug, title, html_content, is_public, created_at
            FROM static_pages
            WHERE url_slug = :slug OR TO_CHAR(id) = :slug
        """, slug=slug)
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Page not found")
        return {
            "success": True,
            "page": {
                "id": row[0],
                "slug": row[1],
                "title": row[2],
                "content": str(row[3]) if row[3] else "",
                "is_public": bool(row[4]),
                "created_at": row[5]
            }
        }

@router.post("/pages")
async def create_page(
    page: dict,
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT NVL(MAX(id), 0) + 1 FROM static_pages")
        next_id = (await cursor.fetchone())[0]
        await cursor.execute("""
            INSERT INTO static_pages (id, url_slug, title, html_content, is_public, created_by)
            VALUES (:1, :2, :3, :4, :5, :6)
        """, (next_id, page.get("slug"), page.get("title"), page.get("content"), 1 if page.get("is_active", True) else 0, current_user.id))
        await conn.commit()
        return {"success": True, "id": next_id}

@router.put("/pages/{page_id}")
async def update_page(
    page_id: int,
    page: dict,
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            UPDATE static_pages SET url_slug=:slug,title=:title,html_content=:content,is_public=:is_public
            WHERE id=:page_id
        """, slug=page.get("slug"), title=page.get("title"), content=page.get("content"),
            is_public=1 if page.get("is_active", True) else 0, page_id=page_id)
        await conn.commit()
        return {"success": True}

@router.delete("/pages/{page_id}")
async def delete_page(
    page_id: int,
    current_user: UserProfile = Depends(require_admin),
    conn: oracledb.AsyncConnection = Depends(get_db_connection)
):
    async with conn.cursor() as cursor:
        await cursor.execute("DELETE FROM static_pages WHERE id=:page_id", page_id=page_id)
        await conn.commit()
        return {"success": True}

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
        await cursor.execute("SELECT id, title, created_by, deleted_at FROM courses WHERE deleted_at IS NOT NULL")
        courses_rows = await cursor.fetchall()
        courses = [{"id": r[0], "type": "course", "title": r[1], "trainer": str(r[2]), "deleted_at": r[3], "extra_info": ""} for r in courses_rows]

        await cursor.execute("SELECT m.id, m.title, c.title, m.deleted_at FROM modules m JOIN courses c ON m.course_id = c.id WHERE m.deleted_at IS NOT NULL")
        modules_rows = await cursor.fetchall()
        modules = [{"id": r[0], "type": "module", "title": r[1], "trainer": r[2], "deleted_at": r[3], "extra_info": f"Course: {r[2]}"} for r in modules_rows]

        await cursor.execute("SELECT ch.id, ch.title, c.title, ch.deleted_at FROM chapters ch JOIN modules m ON ch.module_id = m.id JOIN courses c ON m.course_id = c.id WHERE ch.deleted_at IS NOT NULL")
        chapters_rows = await cursor.fetchall()
        chapters = [{"id": r[0], "type": "chapter", "title": r[1], "trainer": r[2], "deleted_at": r[3], "extra_info": f"Course: {r[2]}"} for r in chapters_rows]

        return courses + modules + chapters

@router.get("/diagnostics")
async def get_diagnostics(
    current_user: UserProfile = Depends(require_admin)
):
    cpu_percent = psutil.cpu_percent(interval=None)
    mem = psutil.virtual_memory()

    db_opened = db._pool.get_opened_count() if db._pool else 0
    db_busy = db._pool.get_busy_count() if db._pool else 0

    return {
        "cpu_usage_percent": cpu_percent,
        "memory_used_mb": round(mem.used / (1024 * 1024), 2),
        "memory_total_mb": round(mem.total / (1024 * 1024), 2),
        "memory_percent": mem.percent,
        "db_connections_busy": db_busy,
        "db_connections_opened": db_opened,
        "db_status": "Healthy (Oracle ADB)" if db._pool else "Disconnected"
    }
