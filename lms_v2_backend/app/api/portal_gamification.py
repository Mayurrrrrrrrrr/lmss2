import oracledb
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile
from app.api.tasks import _eligible_participants

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

class BoosterOptionInput(BaseModel):
    text: str = Field(min_length=1, max_length=1000)
    is_correct: bool = False

class BoosterQuestionInput(BaseModel):
    text: str = Field(min_length=1, max_length=2000)
    image_path: str | None = None
    options: list[BoosterOptionInput] = Field(min_length=2, max_length=8)

class BoosterAnswersInput(BaseModel):
    answers: dict[int, int]

class MilestoneInput(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    type: str = Field(pattern="^(streak_days|course_count)$")
    threshold: int = Field(gt=0)
    xp_reward: int = Field(ge=0, le=100000)
    icon: str = Field(default="🏆", max_length=50)

class KudosInput(BaseModel):
    user_id: int
    points: int = Field(gt=0, le=1000)
    description: str = Field(min_length=1, max_length=1000)


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

async def _apply_milestones(cursor, user_id: int):
    await cursor.execute("SELECT NVL(current_streak,0) FROM user_streaks WHERE user_id=:user_id", user_id=user_id)
    row = await cursor.fetchone(); streak = int(row[0]) if row else 0
    await cursor.execute("""SELECT COUNT(*) FROM (SELECT c.id,COUNT(DISTINCT ch.id) total_chapters,
                          COUNT(DISTINCT CASE WHEN progress.is_completed=1 THEN ch.id END) completed
                          FROM courses c JOIN assignments a ON a.item_type='course' AND a.item_id=c.id AND a.user_id=:user_id
                          JOIN modules m ON m.course_id=c.id AND m.deleted_at IS NULL JOIN chapters ch ON ch.module_id=m.id AND ch.deleted_at IS NULL
                          LEFT JOIN user_progress progress ON progress.chapter_id=ch.id AND progress.user_id=:user_id
                          GROUP BY c.id) WHERE total_chapters>0 AND completed>=total_chapters""", user_id=user_id)
    completed_courses = int((await cursor.fetchone())[0])
    await cursor.execute("SELECT id,type,threshold,xp_reward,title FROM milestones ORDER BY threshold")
    for milestone_id, kind, threshold, xp_reward, title in await cursor.fetchall():
        achieved = streak >= int(threshold) if kind == "streak_days" else completed_courses >= int(threshold)
        if not achieved: continue
        await cursor.execute("SELECT COUNT(*) FROM user_milestones WHERE user_id=:user_id AND milestone_id=:milestone_id", user_id=user_id, milestone_id=milestone_id)
        if int((await cursor.fetchone())[0]) == 0:
            await cursor.execute("INSERT INTO user_milestones(user_id,milestone_id,achieved_at) VALUES(:user_id,:milestone_id,SYSTIMESTAMP)", user_id=user_id, milestone_id=milestone_id)
            if int(xp_reward or 0) > 0:
                await cursor.execute("INSERT INTO xp_transactions(user_id,type,points,reference_id,description,created_at) VALUES(:user_id,'milestone',:points,:reference_id,:description,SYSTIMESTAMP)", user_id=user_id, points=xp_reward, reference_id=milestone_id, description=f"Milestone reached: {title}")

@router.get("/daily-booster")
async def daily_booster(user: UserProfile = Depends(require_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT score,xp_earned FROM daily_booster_attempts WHERE user_id=:user_id AND \"DATE\"=TRUNC(SYSDATE)", user_id=user.id)
        attempt = await cursor.fetchone()
        if attempt: return {"available": False, "score": attempt[0], "xp_earned": attempt[1], "message": "Daily booster already completed."}
        await cursor.execute("""SELECT id,text,image_path FROM (SELECT q.id,q.text,q.image_path FROM questions q
                              WHERE q.deleted_at IS NULL AND (q.quiz_id=0 OR q.quiz_id IN (SELECT quiz_id FROM brain_booster_linked_quizzes))
                              AND NOT EXISTS (SELECT 1 FROM daily_booster_question_logs l WHERE l.user_id=:user_id AND l.question_id=q.id)
                              ORDER BY DBMS_RANDOM.VALUE) FETCH FIRST 3 ROWS ONLY""", user_id=user.id)
        questions = await cursor.fetchall()
        if len(questions) < 3:
            await cursor.execute("""SELECT id,text,image_path FROM (SELECT q.id,q.text,q.image_path FROM questions q
                                  WHERE q.deleted_at IS NULL AND (q.quiz_id=0 OR q.quiz_id IN (SELECT quiz_id FROM brain_booster_linked_quizzes))
                                  ORDER BY DBMS_RANDOM.VALUE) FETCH FIRST 3 ROWS ONLY""")
            questions = await cursor.fetchall()
        result=[]
        for qid,text,image_path in questions:
            await cursor.execute("SELECT id,text FROM (SELECT id,text FROM options WHERE question_id=:question_id ORDER BY DBMS_RANDOM.VALUE)", question_id=qid)
            result.append({"id":qid,"text":text,"image_path":image_path,"options":[{"id":r[0],"text":r[1]} for r in await cursor.fetchall()]})
        return {"available": bool(result), "questions": result}

@router.post("/daily-booster")
async def submit_daily_booster(body: BoosterAnswersInput, user: UserProfile = Depends(require_participant), conn=Depends(get_db_connection)):
    if not body.answers or len(body.answers)>3: raise HTTPException(422, "Submit between one and three booster answers")
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id FROM daily_booster_attempts WHERE user_id=:user_id AND \"DATE\"=TRUNC(SYSDATE) FOR UPDATE", user_id=user.id)
        if await cursor.fetchone(): raise HTTPException(409, "Daily booster already completed")
        score=0
        for question_id,option_id in body.answers.items():
            await cursor.execute("""SELECT o.is_correct FROM options o JOIN questions q ON q.id=o.question_id
                                  WHERE o.id=:option_id AND o.question_id=:question_id AND q.deleted_at IS NULL
                                  AND (q.quiz_id=0 OR q.quiz_id IN (SELECT quiz_id FROM brain_booster_linked_quizzes))""", option_id=option_id, question_id=question_id)
            row=await cursor.fetchone()
            if not row: raise HTTPException(422, "An answer does not belong to the supplied booster question")
            score += 1 if row[0] else 0
        xp=score*15
        await cursor.execute("INSERT INTO daily_booster_attempts(user_id,\"DATE\",score,xp_earned,created_at) VALUES(:user_id,TRUNC(SYSDATE),:score,:xp,SYSTIMESTAMP)", user_id=user.id, score=score, xp=xp)
        for question_id in body.answers:
            await cursor.execute("INSERT INTO daily_booster_question_logs(user_id,question_id,answered_date) VALUES(:user_id,:question_id,TRUNC(SYSDATE))", user_id=user.id, question_id=question_id)
        await cursor.execute("""MERGE INTO user_streaks s USING(SELECT :user_id user_id FROM dual) src ON(s.user_id=src.user_id)
                              WHEN MATCHED THEN UPDATE SET current_streak=CASE WHEN s.last_activity_date=TRUNC(SYSDATE) THEN s.current_streak WHEN s.last_activity_date=TRUNC(SYSDATE)-1 THEN s.current_streak+1 ELSE 1 END,
                              longest_streak=GREATEST(s.longest_streak,CASE WHEN s.last_activity_date=TRUNC(SYSDATE) THEN s.current_streak WHEN s.last_activity_date=TRUNC(SYSDATE)-1 THEN s.current_streak+1 ELSE 1 END),last_activity_date=TRUNC(SYSDATE),updated_at=SYSTIMESTAMP
                              WHEN NOT MATCHED THEN INSERT(user_id,current_streak,longest_streak,last_activity_date,updated_at) VALUES(:user_id,1,1,TRUNC(SYSDATE),SYSTIMESTAMP)""", user_id=user.id)
        if xp>0: await cursor.execute("INSERT INTO xp_transactions(user_id,type,points,reference_id,description,created_at) VALUES(:user_id,'daily_booster',:xp,0,'Daily Booster completed',SYSTIMESTAMP)", user_id=user.id, xp=xp)
        await _apply_milestones(cursor,user.id); await conn.commit(); return {"score":score,"total":len(body.answers),"xp_earned":xp}

@router.get("/trainer/booster")
async def trainer_booster(user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id,text,image_path FROM questions WHERE quiz_id=0 AND deleted_at IS NULL ORDER BY id")
        questions=[]
        for qid,text,image in await cursor.fetchall():
            await cursor.execute("SELECT id,text,is_correct FROM options WHERE question_id=:id ORDER BY id", id=qid)
            questions.append({"id":qid,"text":text,"image_path":image,"options":[{"id":r[0],"text":r[1],"is_correct":bool(r[2])} for r in await cursor.fetchall()]})
        await cursor.execute("SELECT q.id,q.title FROM brain_booster_linked_quizzes b JOIN quizzes q ON q.id=b.quiz_id ORDER BY q.title")
        linked=[{"id":r[0],"title":r[1]} for r in await cursor.fetchall()]
        await cursor.execute("SELECT id,title FROM quizzes WHERE deleted_at IS NULL AND id NOT IN (SELECT quiz_id FROM brain_booster_linked_quizzes)" + ("" if user.role=='admin' else " AND created_by=:owner") + " ORDER BY title", {} if user.role=='admin' else {"owner":user.id})
        return {"questions":questions,"linked_quizzes":linked,"available_quizzes":[{"id":r[0],"title":r[1]} for r in await cursor.fetchall()]}

@router.post("/trainer/booster/questions", status_code=201)
async def create_booster_question(body: BoosterQuestionInput, user: UserProfile = Depends(require_gamification_manager), conn=Depends(get_db_connection)):
    if sum(1 for o in body.options if o.is_correct)!=1: raise HTTPException(422,"Exactly one option must be correct")
    async with conn.cursor() as cursor:
        out=cursor.var(oracledb.NUMBER);await cursor.execute("INSERT INTO questions(quiz_id,text,image_path) VALUES(0,:text,:image) RETURNING id INTO :out",text=body.text,image=body.image_path,out=out);qid=int(out.getvalue()[0])
        for o in body.options: await cursor.execute("INSERT INTO options(question_id,text,is_correct) VALUES(:qid,:text,:correct)",qid=qid,text=o.text,correct=int(o.is_correct))
        await conn.commit();return {"id":qid}

@router.delete("/trainer/booster/questions/{question_id}")
async def delete_booster_question(question_id:int,user:UserProfile=Depends(require_gamification_manager),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("UPDATE questions SET deleted_at=SYSTIMESTAMP WHERE id=:id AND quiz_id=0",id=question_id)
        if cursor.rowcount==0:raise HTTPException(404,"Booster question not found")
        await conn.commit();return {"success":True}

@router.post("/trainer/booster/quizzes/{quiz_id}")
async def link_booster_quiz(quiz_id:int,user:UserProfile=Depends(require_gamification_manager),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT created_by FROM quizzes WHERE id=:id AND deleted_at IS NULL",id=quiz_id);row=await cursor.fetchone()
        if not row or (user.role!='admin' and int(row[0] or 0)!=user.id):raise HTTPException(403,"Quiz unavailable")
        await cursor.execute("SELECT COUNT(*) FROM brain_booster_linked_quizzes WHERE quiz_id=:id",id=quiz_id)
        if int((await cursor.fetchone())[0])==0:await cursor.execute("INSERT INTO brain_booster_linked_quizzes(quiz_id) VALUES(:id)",id=quiz_id)
        await conn.commit();return {"success":True}

@router.delete("/trainer/booster/quizzes/{quiz_id}")
async def unlink_booster_quiz(quiz_id:int,user:UserProfile=Depends(require_gamification_manager),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:await cursor.execute("DELETE FROM brain_booster_linked_quizzes WHERE quiz_id=:id",id=quiz_id);await conn.commit();return {"success":True}

@router.get("/trainer/milestones-kudos")
async def milestones_kudos(user:UserProfile=Depends(require_gamification_manager),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id,title,type,threshold,xp_reward,icon,created_at FROM milestones ORDER BY type,threshold");milestones=[dict(zip(["id","title","type","threshold","xp_reward","icon","created_at"],r)) for r in await cursor.fetchall()]
        await cursor.execute("SELECT x.id,x.user_id,x.points,x.description,x.created_at,u.username,NVL(up.full_name,NVL(u.full_name,u.username)) FROM xp_transactions x JOIN users u ON u.id=x.user_id LEFT JOIN user_profiles up ON up.user_id=u.id WHERE x.type='manual_kudos' ORDER BY x.created_at DESC FETCH FIRST 50 ROWS ONLY")
        return {"milestones":milestones,"kudos":[dict(zip(["id","user_id","points","description","created_at","username","full_name"],r)) for r in await cursor.fetchall()]}

@router.post("/trainer/milestones",status_code=201)
async def create_milestone(body:MilestoneInput,user:UserProfile=Depends(require_gamification_manager),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:out=cursor.var(oracledb.NUMBER);await cursor.execute("INSERT INTO milestones(title,type,threshold,xp_reward,icon,created_at) VALUES(:title,:type,:threshold,:xp_reward,:icon,SYSTIMESTAMP) RETURNING id INTO :out",**body.model_dump(),out=out);await conn.commit();return {"id":int(out.getvalue()[0])}

@router.delete("/trainer/milestones/{milestone_id}")
async def delete_milestone(milestone_id:int,user:UserProfile=Depends(require_gamification_manager),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:await cursor.execute("SELECT COUNT(*) FROM user_milestones WHERE milestone_id=:id",id=milestone_id);count=int((await cursor.fetchone())[0]);
    if count:raise HTTPException(409,"Milestone has achievement history and cannot be deleted")
    async with conn.cursor() as cursor:await cursor.execute("DELETE FROM milestones WHERE id=:id",id=milestone_id);await conn.commit();return {"success":True}

@router.post("/trainer/kudos",status_code=201)
async def award_kudos(body:KudosInput,user:UserProfile=Depends(require_gamification_manager),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        participants=await _eligible_participants(cursor,user)
        if body.user_id not in {int(p['id']) for p in participants}:raise HTTPException(403,"Learner outside permitted audience")
        await cursor.execute("INSERT INTO xp_transactions(user_id,type,points,reference_id,description,created_at) VALUES(:user_id,'manual_kudos',:points,0,:description,SYSTIMESTAMP)",**body.model_dump());await conn.commit();return {"success":True}


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
