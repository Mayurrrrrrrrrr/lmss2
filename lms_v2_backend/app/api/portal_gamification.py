import oracledb
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile

router = APIRouter()


class BadgeInput(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=2000)
    icon_path: str | None = Field(default=None, max_length=4000)
    badge_trigger: str | None = Field(default=None, max_length=255)


class RewardInput(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=2000)
    xp_cost: int = Field(gt=0)
    stock: int = Field(ge=-1)
    image_url: str | None = Field(default=None, max_length=4000)


class RedemptionStatusInput(BaseModel):
    status: str = Field(pattern="^(Approved|Rejected|Fulfilled)$")


class RedemptionInput(BaseModel):
    reward_id: int = Field(gt=0)


class PointsSettingsInput(BaseModel):
    settings: dict[str, str]


class CertificateConfigInput(BaseModel):
    logo_path: str | None = None
    title: str = "Certificate of Completion"
    subtitle: str = "Honors Division"
    presentation_text: str = "This is proudly presented to"
    body_text: str = "for successfully completing the course training program for"
    signatory: str = "Firefly LMS"
    signatory_title: str = "Authorized Signatory"
    logo_width: int = 120
    logo_top: int = 20
    logo_left: int = 20
    title_top: int = 10
    subtitle_top: int = 25
    recipient_top: int = 10
    text_top: int = 25
    footer_top: int = 40


async def require_gamification_manager(user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if user.role not in ("trainer", "admin"):
        raise HTTPException(403, "Requires trainer or admin privileges")
    return user


async def require_participant(user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if user.role not in ("participant", "area_manager", "admin"):
        raise HTTPException(403, "Requires participant privileges")
    return user


async def _balance(cursor, user_id: int) -> int:
    await cursor.execute("SELECT NVL(SUM(points),0) FROM xp_transactions WHERE user_id=:user_id", user_id=user_id)
    return int((await cursor.fetchone())[0] or 0)


@router.get("/trainer/badges")
async def list_badges(user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT b.id,b.name,b.description,b.icon_path,b.badge_trigger,b.created_at,COUNT(ub.id)
            FROM badges b LEFT JOIN user_badges ub ON ub.badge_id=b.id
            GROUP BY b.id,b.name,b.description,b.icon_path,b.badge_trigger,b.created_at
            ORDER BY b.created_at DESC NULLS LAST,b.id DESC
        """)
        keys = ["id","name","description","icon_path","badge_trigger","created_at","awarded_count"]
        return {"badges": [dict(zip(keys, row)) for row in await cursor.fetchall()]}


@router.post("/trainer/badges", status_code=201)
async def create_badge(body: BadgeInput, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        out_id = cursor.var(oracledb.NUMBER)
        await cursor.execute("""INSERT INTO badges(name,description,icon_path,badge_trigger,created_at)
                              VALUES(:name,:description,:icon_path,:badge_trigger,SYSTIMESTAMP) RETURNING id INTO :out_id""",
                             **body.model_dump(), out_id=out_id)
        await conn.commit()
        return {"id": int(out_id.getvalue()[0])}


@router.put("/trainer/badges/{badge_id}")
async def update_badge(badge_id: int, body: BadgeInput, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""UPDATE badges SET name=:name,description=:description,icon_path=:icon_path,badge_trigger=:badge_trigger
                              WHERE id=:badge_id""", **body.model_dump(), badge_id=badge_id)
        if cursor.rowcount == 0: raise HTTPException(404, "Badge not found")
        await conn.commit(); return {"success": True}


@router.delete("/trainer/badges/{badge_id}")
async def delete_badge(badge_id: int, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT
            (SELECT COUNT(*) FROM user_badges WHERE badge_id=:badge_id)+
            (SELECT COUNT(*) FROM courses WHERE course_badge_id=:badge_id)+
            (SELECT COUNT(*) FROM quizzes WHERE quiz_badge_id=:badge_id) FROM dual""", badge_id=badge_id)
        if int((await cursor.fetchone())[0]) > 0: raise HTTPException(409, "Badge has already been awarded and cannot be deleted")
        await cursor.execute("DELETE FROM badges WHERE id=:badge_id", badge_id=badge_id)
        if cursor.rowcount == 0: raise HTTPException(404, "Badge not found")
        await conn.commit(); return {"success": True}


@router.get("/trainer/points-settings")
async def points_settings(user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT setting_key,setting_value,description FROM points_configuration ORDER BY setting_key")
        return {"settings": [{"key": r[0], "value": r[1], "description": r[2]} for r in await cursor.fetchall()]}


@router.put("/trainer/points-settings")
async def update_points_settings(body: PointsSettingsInput, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        for key, value in body.settings.items():
            await cursor.execute("UPDATE points_configuration SET setting_value=:value WHERE setting_key=:key", value=str(value), key=key)
            if cursor.rowcount == 0: raise HTTPException(422, f"Unknown points setting: {key}")
        await conn.commit(); return {"success": True}


@router.get("/trainer/rewards")
async def trainer_rewards(user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id,title,description,xp_cost,image_url,stock,created_at FROM rewards ORDER BY xp_cost,id")
        rewards = [dict(zip(["id","title","description","xp_cost","image_url","stock","created_at"], r)) for r in await cursor.fetchall()]
        await cursor.execute("""SELECT rd.id,rd.user_id,rd.reward_id,rd.status,rd.redeemed_at,rd.updated_at,
                              rw.title,rw.xp_cost,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code
                              FROM redemptions rd JOIN rewards rw ON rw.id=rd.reward_id JOIN users u ON u.id=rd.user_id
                              LEFT JOIN user_profiles up ON up.user_id=u.id ORDER BY rd.redeemed_at DESC,rd.id DESC""")
        keys = ["id","user_id","reward_id","status","redeemed_at","updated_at","reward_title","xp_cost","username","full_name","store_code"]
        return {"rewards": rewards, "redemptions": [dict(zip(keys, r)) for r in await cursor.fetchall()]}


@router.post("/trainer/rewards", status_code=201)
async def create_reward(body: RewardInput, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        out_id = cursor.var(oracledb.NUMBER)
        await cursor.execute("""INSERT INTO rewards(title,description,xp_cost,image_url,stock,created_at)
                              VALUES(:title,:description,:xp_cost,:image_url,:stock,SYSTIMESTAMP) RETURNING id INTO :out_id""",
                             **body.model_dump(), out_id=out_id)
        await conn.commit(); return {"id": int(out_id.getvalue()[0])}


@router.delete("/trainer/rewards/{reward_id}")
async def delete_reward(reward_id: int, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT COUNT(*) FROM redemptions WHERE reward_id=:reward_id", reward_id=reward_id)
        if int((await cursor.fetchone())[0]) > 0: raise HTTPException(409, "Reward has redemption history and cannot be deleted")
        await cursor.execute("DELETE FROM rewards WHERE id=:reward_id", reward_id=reward_id)
        if cursor.rowcount == 0: raise HTTPException(404, "Reward not found")
        await conn.commit(); return {"success": True}


@router.post("/trainer/redemptions/{redemption_id}/status")
async def update_redemption(redemption_id: int, body: RedemptionStatusInput, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT rd.user_id,rd.reward_id,rd.status,rw.xp_cost FROM redemptions rd
                              JOIN rewards rw ON rw.id=rd.reward_id WHERE rd.id=:id FOR UPDATE""", id=redemption_id)
        row = await cursor.fetchone()
        if not row: raise HTTPException(404, "Redemption not found")
        old_status = str(row[2] or "Pending")
        if old_status == "Rejected" and body.status != "Rejected": raise HTTPException(409, "Rejected redemptions cannot be reopened")
        allowed = {"Pending": {"Approved", "Rejected"}, "Approved": {"Fulfilled"}, "Fulfilled": set(), "Rejected": set()}
        if body.status != old_status and body.status not in allowed.get(old_status, set()):
            raise HTTPException(409, f"Cannot change redemption from {old_status} to {body.status}")
        if body.status == "Rejected" and old_status != "Rejected":
            await cursor.execute("""INSERT INTO xp_transactions(user_id,type,points,reference_id,description,created_at)
                                  VALUES(:user_id,'refund',:points,:reference_id,'Refund for rejected redemption',SYSTIMESTAMP)""",
                                 user_id=row[0], points=int(row[3]), reference_id=redemption_id)
            await cursor.execute("UPDATE rewards SET stock=stock+1 WHERE id=:reward_id AND stock>=0", reward_id=row[1])
        await cursor.execute("UPDATE redemptions SET status=:status,updated_at=SYSTIMESTAMP WHERE id=:id", status=body.status, id=redemption_id)
        await conn.commit(); return {"success": True}


@router.get("/rewards")
async def participant_rewards(user: UserProfile = Depends(require_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        balance = await _balance(cursor, user.id)
        await cursor.execute("SELECT id,title,description,xp_cost,image_url,stock,created_at FROM rewards WHERE stock<>0 ORDER BY xp_cost,id")
        rewards = [dict(zip(["id","title","description","xp_cost","image_url","stock","created_at"], r)) for r in await cursor.fetchall()]
        await cursor.execute("""SELECT rd.id,rd.reward_id,rd.status,rd.redeemed_at,rd.updated_at,rw.title,rw.image_url,rw.xp_cost
                              FROM redemptions rd JOIN rewards rw ON rw.id=rd.reward_id WHERE rd.user_id=:user_id
                              ORDER BY rd.redeemed_at DESC,rd.id DESC""", user_id=user.id)
        keys = ["id","reward_id","status","redeemed_at","updated_at","title","image_url","xp_cost"]
        return {"balance": balance, "rewards": rewards, "redemptions": [dict(zip(keys, r)) for r in await cursor.fetchall()]}


@router.post("/rewards/redeem", status_code=201)
async def redeem_reward(body: RedemptionInput, user: UserProfile = Depends(require_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id,title,xp_cost,stock FROM rewards WHERE id=:id FOR UPDATE", id=body.reward_id)
        reward = await cursor.fetchone()
        if not reward: raise HTTPException(404, "Reward not found")
        if int(reward[3]) == 0: raise HTTPException(409, "Reward is out of stock")
        cost = int(reward[2]); balance = await _balance(cursor, user.id)
        if balance < cost: raise HTTPException(409, "Insufficient XP")
        await cursor.execute("""INSERT INTO xp_transactions(user_id,type,points,reference_id,description,created_at)
                              VALUES(:user_id,'redemption',:points,:reward_id,:description,SYSTIMESTAMP)""",
                             user_id=user.id, points=-cost, reward_id=body.reward_id, description=f"Redeemed {reward[1]}")
        out_id = cursor.var(oracledb.NUMBER)
        await cursor.execute("""INSERT INTO redemptions(user_id,reward_id,status,redeemed_at,updated_at)
                              VALUES(:user_id,:reward_id,'Pending',SYSTIMESTAMP,SYSTIMESTAMP) RETURNING id INTO :out_id""",
                             user_id=user.id, reward_id=body.reward_id, out_id=out_id)
        await cursor.execute("UPDATE rewards SET stock=stock-1 WHERE id=:id AND stock>0", id=body.reward_id)
        await conn.commit(); return {"id": int(out_id.getvalue()[0]), "balance": balance - cost}


@router.get("/badges/mine")
async def my_badges(user: UserProfile = Depends(require_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""SELECT b.id,b.name,b.description,b.icon_path,b.badge_trigger,ub.awarded_at
                              FROM user_badges ub JOIN badges b ON b.id=ub.badge_id WHERE ub.user_id=:user_id
                              ORDER BY ub.awarded_at DESC NULLS LAST,ub.id DESC""", user_id=user.id)
        keys = ["id","name","description","icon_path","badge_trigger","awarded_at"]
        return {"badges": [dict(zip(keys, r)) for r in await cursor.fetchall()]}


@router.get("/certificates")
async def certificates(user: UserProfile = Depends(require_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT course_id,course_title,completed_at FROM (
                SELECT c.id course_id,c.title course_title,MAX(up.completed_at) completed_at,
                       COUNT(DISTINCT ch.id) total_chapters,
                       COUNT(DISTINCT CASE WHEN up.is_completed=1 THEN ch.id END) completed_chapters
                FROM courses c JOIN assignments a ON a.item_type='course' AND a.item_id=c.id AND a.user_id=:user_id
                JOIN modules m ON m.course_id=c.id AND m.deleted_at IS NULL
                JOIN chapters ch ON ch.module_id=m.id AND ch.deleted_at IS NULL
                LEFT JOIN user_progress up ON up.chapter_id=ch.id AND up.user_id=:user_id
                WHERE c.deleted_at IS NULL GROUP BY c.id,c.title
            ) WHERE total_chapters>0 AND completed_chapters>=total_chapters ORDER BY completed_at DESC NULLS LAST
        """, user_id=user.id)
        return {"certificates": [{"course_id": r[0], "course_title": r[1], "completed_at": r[2]} for r in await cursor.fetchall()]}


@router.get("/certificates/{course_id}")
async def certificate_data(course_id: int, user: UserProfile = Depends(require_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT c.title,NVL(up.full_name,NVL(u.full_name,u.username)),MAX(progress.completed_at),
                   COUNT(DISTINCT ch.id),COUNT(DISTINCT CASE WHEN progress.is_completed=1 THEN ch.id END),
                   cc.logo_path,cc.title,cc.subtitle,cc.presentation_text,cc.body_text,cc.signatory,cc.signatory_title,
                   cc.logo_width,cc.logo_top,cc.logo_left,cc.title_top,cc.subtitle_top,cc.recipient_top,cc.text_top,cc.footer_top
            FROM courses c JOIN assignments a ON a.item_type='course' AND a.item_id=c.id AND a.user_id=:user_id
            JOIN users u ON u.id=:user_id LEFT JOIN user_profiles up ON up.user_id=u.id
            JOIN modules m ON m.course_id=c.id AND m.deleted_at IS NULL JOIN chapters ch ON ch.module_id=m.id AND ch.deleted_at IS NULL
            LEFT JOIN user_progress progress ON progress.chapter_id=ch.id AND progress.user_id=:user_id
            LEFT JOIN certificate_configs cc ON cc.course_id=c.id WHERE c.id=:course_id AND c.deleted_at IS NULL
            GROUP BY c.title,NVL(up.full_name,NVL(u.full_name,u.username)),cc.logo_path,cc.title,cc.subtitle,cc.presentation_text,
                     cc.body_text,cc.signatory,cc.signatory_title,cc.logo_width,cc.logo_top,cc.logo_left,cc.title_top,
                     cc.subtitle_top,cc.recipient_top,cc.text_top,cc.footer_top
        """, user_id=user.id, course_id=course_id)
        row = await cursor.fetchone()
        if not row or int(row[4]) < int(row[3]): raise HTTPException(403, "Complete every course chapter before accessing its certificate")
        keys = ["course_title","recipient_name","completed_at","total_chapters","completed_chapters","logo_path","title","subtitle",
                "presentation_text","body_text","signatory","signatory_title","logo_width","logo_top","logo_left","title_top",
                "subtitle_top","recipient_top","text_top","footer_top"]
        result = dict(zip(keys, row))
        defaults = CertificateConfigInput().model_dump()
        for key, value in defaults.items():
            if result.get(key) is None: result[key] = value
        return result


@router.get("/trainer/courses/{course_id}/certificate-config")
async def get_certificate_config(course_id: int, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT created_by FROM courses WHERE id=:id AND deleted_at IS NULL", id=course_id)
        course = await cursor.fetchone()
        if not course: raise HTTPException(404, "Course not found")
        if user.role == "trainer" and int(course[0] or 0) != user.id: raise HTTPException(403, "You can only configure your own course")
        await cursor.execute("""SELECT logo_path,title,subtitle,presentation_text,body_text,signatory,signatory_title,logo_width,
                              logo_top,logo_left,title_top,subtitle_top,recipient_top,text_top,footer_top FROM certificate_configs
                              WHERE course_id=:course_id""", course_id=course_id)
        row = await cursor.fetchone(); keys = list(CertificateConfigInput.model_fields)
        return dict(zip(keys, row)) if row else CertificateConfigInput().model_dump()


@router.put("/trainer/courses/{course_id}/certificate-config")
async def save_certificate_config(course_id: int, body: CertificateConfigInput, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT created_by FROM courses WHERE id=:id AND deleted_at IS NULL", id=course_id)
        course = await cursor.fetchone()
        if not course: raise HTTPException(404, "Course not found")
        if user.role == "trainer" and int(course[0] or 0) != user.id: raise HTTPException(403, "You can only configure your own course")
        values = body.model_dump(); values["course_id"] = course_id
        columns = list(CertificateConfigInput.model_fields)
        await cursor.execute("SELECT id FROM certificate_configs WHERE course_id=:course_id", course_id=course_id)
        if await cursor.fetchone():
            await cursor.execute("UPDATE certificate_configs SET " + ",".join(f"{c}=:{c}" for c in columns) + ",updated_at=SYSTIMESTAMP WHERE course_id=:course_id", values)
        else:
            await cursor.execute("INSERT INTO certificate_configs(course_id," + ",".join(columns) + ",created_at,updated_at) VALUES(:course_id," + ",".join(f":{c}" for c in columns) + ",SYSTIMESTAMP,SYSTIMESTAMP)", values)
        await conn.commit(); return {"success": True}


@router.delete("/trainer/courses/{course_id}/certificate-config")
async def reset_certificate_config(course_id: int, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT created_by FROM courses WHERE id=:id", id=course_id); course = await cursor.fetchone()
        if not course: raise HTTPException(404, "Course not found")
        if user.role == "trainer" and int(course[0] or 0) != user.id: raise HTTPException(403, "You can only configure your own course")
        await cursor.execute("DELETE FROM certificate_configs WHERE course_id=:course_id", course_id=course_id)
        await conn.commit(); return {"success": True}
