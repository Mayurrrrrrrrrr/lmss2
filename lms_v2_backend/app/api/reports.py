from datetime import date, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query
from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile
from app.api.tasks import _manager_team_ids

router = APIRouter()

async def require_report_viewer(user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if user.role not in ("trainer", "admin", "area_manager"):
        raise HTTPException(403, "Requires trainer, admin, or manager privileges")
    return user

async def _visible_ids(cursor, user: UserProfile) -> set[int]:
    if user.role == "admin":
        await cursor.execute("SELECT id FROM users WHERE LOWER(role)='participant'")
    elif user.role == "area_manager":
        return await _manager_team_ids(cursor, user.id)
    else:
        await cursor.execute("""SELECT DISTINCT a.user_id FROM assignments a
                              LEFT JOIN courses c ON a.item_type='course' AND c.id=a.item_id
                              LEFT JOIN quizzes q ON a.item_type='quiz' AND q.id=a.item_id
                              WHERE c.created_by=:owner OR q.created_by=:owner""", owner=user.id)
    return {int(row[0]) for row in await cursor.fetchall()}

def _id_clause(ids: set[int]):
    params = {f"uid_{i}": value for i, value in enumerate(sorted(ids))}
    return "(" + ",".join(f":uid_{i}" for i in range(len(ids))) + ")", params

@router.get("/reports/options")
async def report_options(user: UserProfile = Depends(require_report_viewer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        ids = await _visible_ids(cursor, user)
        if not ids: return {"stores": [], "cities": [], "managers": [], "courses": []}
        clause, params = _id_clause(ids)
        await cursor.execute(f"SELECT DISTINCT store_code FROM user_profiles WHERE user_id IN {clause} AND store_code IS NOT NULL ORDER BY store_code", params); stores=[r[0] for r in await cursor.fetchall()]
        await cursor.execute(f"SELECT DISTINCT city FROM user_profiles WHERE user_id IN {clause} AND city IS NOT NULL ORDER BY city", params); cities=[r[0] for r in await cursor.fetchall()]
        await cursor.execute(f"SELECT DISTINCT reporting_manager_name FROM user_profiles WHERE user_id IN {clause} AND reporting_manager_name IS NOT NULL ORDER BY reporting_manager_name", params); managers=[r[0] for r in await cursor.fetchall()]
        owner_clause = "" if user.role == "admin" else " AND c.created_by=:owner"
        course_params = {} if user.role == "admin" else {"owner": user.id}
        await cursor.execute("SELECT c.id,c.title FROM courses c WHERE c.deleted_at IS NULL"+owner_clause+" ORDER BY c.title", course_params)
        return {"stores": stores, "cities": cities, "managers": managers, "courses": [{"id":r[0],"title":r[1]} for r in await cursor.fetchall()]}

@router.get("/reports")
async def reports(
    date_from: date = Query(default_factory=lambda: date.today()-timedelta(days=30)),
    date_to: date = Query(default_factory=date.today), store_code: str | None = None, city: str | None = None,
    manager_name: str | None = None, course_id: int | None = None,
    user: UserProfile = Depends(require_report_viewer), conn=Depends(get_db_connection)
):
    if date_from > date_to or (date_to-date_from).days > 366: raise HTTPException(422, "Choose a valid date range up to 366 days")
    async with conn.cursor() as cursor:
        ids = await _visible_ids(cursor, user)
        if not ids: return {"summary": {}, "courses": [], "quizzes": [], "roleplays": [], "users": []}
        id_clause, params = _id_clause(ids)
        filters = []
        if store_code: filters.append("up.store_code=:store_code"); params["store_code"]=store_code
        if city: filters.append("up.city=:city"); params["city"]=city
        if manager_name: filters.append("up.reporting_manager_name=:manager_name"); params["manager_name"]=manager_name
        profile_filter = "" if not filters else " AND " + " AND ".join(filters)

        course_params = dict(params)
        course_filter = ""
        if course_id is not None: course_filter=" AND c.id=:course_id"; course_params["course_id"]=course_id
        if user.role == "trainer": course_filter += " AND c.created_by=:owner"; course_params["owner"]=user.id
        await cursor.execute(f"""SELECT a.id,c.id,c.title,u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code,up.city,
                              up.reporting_manager_name,a.assigned_date,a.deadline_date,COUNT(DISTINCT ch.id),
                              COUNT(DISTINCT CASE WHEN progress.is_completed=1 THEN ch.id END),MAX(progress.updated_at)
                              FROM assignments a JOIN courses c ON a.item_type='course' AND c.id=a.item_id JOIN users u ON u.id=a.user_id
                              LEFT JOIN user_profiles up ON up.user_id=u.id LEFT JOIN modules m ON m.course_id=c.id AND m.deleted_at IS NULL
                              LEFT JOIN chapters ch ON ch.module_id=m.id AND ch.deleted_at IS NULL
                              LEFT JOIN user_progress progress ON progress.chapter_id=ch.id AND progress.user_id=u.id
                              WHERE u.id IN {id_clause} AND c.deleted_at IS NULL {profile_filter} {course_filter}
                              GROUP BY a.id,c.id,c.title,u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code,up.city,
                                       up.reporting_manager_name,a.assigned_date,a.deadline_date ORDER BY MAX(progress.updated_at) DESC NULLS LAST""", course_params)
        ckeys=["assignment_id","course_id","course_title","user_id","username","full_name","store_code","city","manager_name","assigned_date","deadline_date","total_chapters","completed_chapters","last_activity"]
        courses=[dict(zip(ckeys,r)) for r in await cursor.fetchall()]
        for row in courses: row["progress_percent"] = round(100*int(row["completed_chapters"] or 0)/int(row["total_chapters"] or 1)); row["status"]="Completed" if row["total_chapters"] and row["completed_chapters"]>=row["total_chapters"] else "In progress"

        dated = dict(params); dated.update({"date_from": date_from, "date_to": date_to})
        user_dated = dict(dated)
        quiz_owner = ""
        if user.role == "trainer": quiz_owner=" AND q.created_by=:owner"; dated["owner"]=user.id
        await cursor.execute(f"""SELECT q.id,q.title,u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code,up.city,
                              up.reporting_manager_name,qa.score,qa.total,qa.start_time,qa.end_time,a.course_id
                              FROM assignments a JOIN quizzes q ON a.item_type='quiz' AND q.id=a.item_id JOIN users u ON u.id=a.user_id
                              LEFT JOIN user_profiles up ON up.user_id=u.id LEFT JOIN quiz_attempts qa ON qa.quiz_id=q.id AND qa.user_id=u.id
                              AND TRUNC(qa.end_time) BETWEEN :date_from AND :date_to
                              WHERE u.id IN {id_clause} AND q.deleted_at IS NULL {profile_filter} {quiz_owner}
                              ORDER BY qa.end_time DESC NULLS LAST""", dated)
        qkeys=["quiz_id","quiz_title","user_id","username","full_name","store_code","city","manager_name","score","total","start_time","end_time","course_id"]
        quizzes=[dict(zip(qkeys,r)) for r in await cursor.fetchall()]
        for row in quizzes: row["percentage"] = round(100*int(row["score"] or 0)/int(row["total"] or 1)) if row["end_time"] else None; row["status"]="Attempted" if row["end_time"] else "Pending"

        await cursor.execute(f"""SELECT rp.id,rp.scenario_topic,rp.week_no,rp.day,u.id,NVL(up.full_name,NVL(u.full_name,u.username)),
                              up.store_code,up.city,up.reporting_manager_name,rp.status,rp.observer_score,rp.created_at,rp.participant_remarks,rp.debrief_notes
                              FROM roleplay_sessions rp JOIN users u ON u.id=rp.user_id LEFT JOIN user_profiles up ON up.user_id=u.id
                              WHERE u.id IN {id_clause} {profile_filter} ORDER BY rp.created_at DESC""", params)
        rkeys=["id","scenario_topic","week_no","day","user_id","full_name","store_code","city","manager_name","status","observer_score","created_at","participant_remarks","debrief_notes"]
        roleplays=[dict(zip(rkeys,r)) for r in await cursor.fetchall()]

        await cursor.execute(f"""SELECT u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code,up.city,up.reporting_manager_name,
                              u.last_active,MAX(ll.login_time),COUNT(ll.id)
                              FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id LEFT JOIN login_logs ll ON ll.user_id=u.id
                              AND TRUNC(ll.login_time) BETWEEN :date_from AND :date_to WHERE u.id IN {id_clause} {profile_filter}
                              GROUP BY u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code,up.city,up.reporting_manager_name,u.last_active
                              ORDER BY MAX(ll.login_time) DESC NULLS LAST""", user_dated)
        ukeys=["user_id","username","full_name","store_code","city","manager_name","last_active","last_login","login_count"]
        users=[dict(zip(ukeys,r)) for r in await cursor.fetchall()]
        active=lambda days:sum(1 for row in users if row["last_active"] and row["last_active"].date()>=date.today()-timedelta(days=days-1))
        summary={"participants":len(users),"daily_active":active(1),"weekly_active":active(7),"monthly_active":active(30),
                 "course_assignments":len(courses),"course_completions":sum(1 for r in courses if r["status"]=="Completed"),
                 "quiz_attempts":sum(1 for r in quizzes if r["status"]=="Attempted"),"roleplays_completed":sum(1 for r in roleplays if str(r["status"]).lower()=="completed")}
        return {"summary":summary,"courses":courses,"quizzes":quizzes,"roleplays":roleplays,"users":users}
