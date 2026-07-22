import json
from html import unescape
from typing import Literal

import oracledb
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile
from app.services.ai_service import generate_json, generate_text, trainer_ai_key

router = APIRouter()


class CourseDescriptionInput(BaseModel):
    title: str = Field(min_length=2, max_length=255)
    audience: str = Field(default="retail and sales professionals", max_length=255)


class GenerateQuestionsInput(BaseModel):
    quiz_id: int
    count: int = Field(default=5, ge=1, le=10)
    save: bool = False


class QuizInput(BaseModel):
    quiz_id: int


class ParticipantInput(BaseModel):
    user_id: int


class KnowledgeGapInput(BaseModel):
    user_id: int | None = None
    store_code: str | None = Field(default=None, max_length=100)


class NudgeInput(BaseModel):
    user_id: int
    context: str | None = Field(default=None, max_length=1000)
    send_notification: bool = False


class AskInput(BaseModel):
    chapter_id: int
    question: str = Field(min_length=2, max_length=500)


class ChapterInput(BaseModel):
    chapter_id: int


class AttemptInput(BaseModel):
    attempt_id: int


async def require_ai_trainer(user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if user.role not in ("trainer", "admin"):
        raise HTTPException(403, "Requires trainer or admin privileges")
    return user


async def require_ai_participant(user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if user.role not in ("participant", "area_manager", "admin"):
        raise HTTPException(403, "Requires participant privileges")
    return user


async def _owned_quiz(cursor, quiz_id: int, user: UserProfile):
    sql = "SELECT id,title,quiz_description,created_by FROM quizzes WHERE id=:quiz_id AND deleted_at IS NULL"
    params = {"quiz_id": quiz_id}
    if user.role != "admin":
        sql += " AND created_by=:owner_id"
        params["owner_id"] = user.id
    await cursor.execute(sql, params)
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(404, "Quiz not found or not owned by you")
    return row


async def _permitted_participant(cursor, participant_id: int, user: UserProfile):
    await cursor.execute("SELECT u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id WHERE u.id=:user_id AND LOWER(u.role)='participant'", user_id=participant_id)
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(404, "Participant not found")
    if user.role != "admin":
        await cursor.execute("""
            SELECT COUNT(*) FROM assignments a LEFT JOIN courses c ON a.item_type='course' AND c.id=a.item_id
            LEFT JOIN quizzes q ON a.item_type='quiz' AND q.id=a.item_id
            WHERE a.user_id=:user_id AND (c.created_by=:trainer_id OR q.created_by=:trainer_id)
        """, user_id=participant_id, trainer_id=user.id)
        if int((await cursor.fetchone())[0]) == 0:
            raise HTTPException(403, "Participant is outside your assigned cohort")
    return row


async def _participant_ai_enabled(cursor):
    await cursor.execute("SELECT setting_value FROM system_settings WHERE setting_key='participant_ai_enabled'")
    row = await cursor.fetchone()
    if row and str(row[0]).strip().lower() in ("0", "false", "no", "disabled"):
        raise HTTPException(403, "Participant AI tools are disabled")


def _plain_html(value) -> str:
    text = str(value or "")
    import re
    return unescape(re.sub(r"<[^>]+>", " ", text))[:6000]


@router.get("/trainer/options")
async def ai_options(user: UserProfile = Depends(require_ai_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        quiz_sql = "SELECT id,title FROM quizzes WHERE deleted_at IS NULL"
        params = {}
        if user.role != "admin":
            quiz_sql += " AND created_by=:owner_id"
            params["owner_id"] = user.id
        quiz_sql += " ORDER BY title"
        await cursor.execute(quiz_sql, params)
        quizzes = [{"id": int(row[0]), "title": row[1]} for row in await cursor.fetchall()]
        await cursor.execute("SELECT u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.store_code FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id WHERE LOWER(u.role)='participant' ORDER BY NVL(up.full_name,NVL(u.full_name,u.username))")
        participants = [{"id": int(row[0]), "username": row[1], "full_name": row[2], "store_code": row[3]} for row in await cursor.fetchall()]
        if user.role != "admin":
            permitted = []
            for participant in participants:
                try:
                    await _permitted_participant(cursor, participant["id"], user)
                    permitted.append(participant)
                except HTTPException:
                    pass
            participants = permitted
        return {"quizzes": quizzes, "participants": participants,
                "store_codes": sorted({p["store_code"] for p in participants if p["store_code"]})}


@router.post("/trainer/course-description")
async def course_description(body: CourseDescriptionInput, user: UserProfile = Depends(require_ai_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        key = await trainer_ai_key(cursor, user.id)
    prompt = f'''Write a professional 2-3 sentence course description for a corporate training LMS.
Course title: "{body.title}"
Audience: {body.audience}
Explain what participants will learn and why it is valuable. Write in second person. Return only the description.'''
    return {"description": await generate_text(prompt, key, max_output_tokens=300)}


@router.post("/trainer/questions")
async def generate_questions(body: GenerateQuestionsInput, user: UserProfile = Depends(require_ai_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        quiz = await _owned_quiz(cursor, body.quiz_id, user)
        key = await trainer_ai_key(cursor, int(quiz[3]))
        prompt = f'''Create exactly {body.count} multiple-choice questions for a corporate training quiz.
Quiz title: {quiz[1]}
Quiz description: {quiz[2] or "Not provided"}
Each question must have exactly four options and one correct answer. Use realistic retail/sales application scenarios.
Return only JSON: {{"questions":[{{"question_text":"...","options":["A","B","C","D"],"correct_index":0,"difficulty":"easy|medium|hard"}}]}}'''
        result = await generate_json(prompt, key, max_output_tokens=3000)
        questions = result.get("questions", []) if isinstance(result, dict) else []
        cleaned = []
        for item in questions[:body.count]:
            options = item.get("options") if isinstance(item, dict) else None
            correct = item.get("correct_index") if isinstance(item, dict) else None
            if not item.get("question_text") or not isinstance(options, list) or len(options) != 4 or not isinstance(correct, int) or correct not in range(4):
                continue
            difficulty = item.get("difficulty") if item.get("difficulty") in ("easy", "medium", "hard") else "medium"
            cleaned.append({"question_text": str(item["question_text"])[:4000], "options": [str(option)[:1000] for option in options], "correct_index": correct, "difficulty": difficulty})
        if not cleaned:
            raise HTTPException(502, "AI did not return valid questions")
        if body.save:
            for item in cleaned:
                out_id = cursor.var(oracledb.NUMBER)
                await cursor.execute("INSERT INTO questions(quiz_id,text,difficulty) VALUES(:quiz_id,:text,:difficulty) RETURNING id INTO :out_id", quiz_id=body.quiz_id, text=item["question_text"], difficulty=item["difficulty"], out_id=out_id)
                question_id = int(out_id.getvalue()[0])
                for index, option in enumerate(item["options"]):
                    await cursor.execute("INSERT INTO options(question_id,text,is_correct) VALUES(:question_id,:text,:correct)", question_id=question_id, text=option, correct=int(index == item["correct_index"]))
            await conn.commit()
        return {"questions": cleaned, "saved": len(cleaned) if body.save else 0}


@router.post("/trainer/tag-difficulty")
async def tag_difficulty(body: QuizInput, user: UserProfile = Depends(require_ai_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        quiz = await _owned_quiz(cursor, body.quiz_id, user)
        await cursor.execute("SELECT id,text FROM questions WHERE quiz_id=:quiz_id AND deleted_at IS NULL AND difficulty IS NULL ORDER BY id", quiz_id=body.quiz_id)
        questions = await cursor.fetchall()
        if not questions:
            return {"tagged": 0, "message": "All questions are already tagged"}
        key = await trainer_ai_key(cursor, int(quiz[3]))
        listing = "\n".join(f"ID {row[0]}: {row[1]}" for row in questions[:100])
        result = await generate_json(f'''Classify each corporate training question as easy, medium, or hard.
Easy is direct recall, medium requires application, hard requires analysis or judgment.
Questions:\n{listing}\nReturn only JSON: {{"results":[{{"id":123,"difficulty":"easy"}}]}}''', key)
        allowed = {int(row[0]) for row in questions}
        tagged = 0
        for item in result.get("results", []) if isinstance(result, dict) else []:
            if item.get("id") in allowed and item.get("difficulty") in ("easy", "medium", "hard"):
                await cursor.execute("UPDATE questions SET difficulty=:difficulty WHERE id=:question_id AND quiz_id=:quiz_id", difficulty=item["difficulty"], question_id=item["id"], quiz_id=body.quiz_id)
                tagged += 1
        await conn.commit()
        return {"tagged": tagged, "total": len(questions)}


@router.post("/trainer/risk-score")
async def risk_score(body: ParticipantInput, user: UserProfile = Depends(require_ai_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        participant = await _permitted_participant(cursor, body.user_id, user)
        key = await trainer_ai_key(cursor, user.id)
        await cursor.execute("SELECT COUNT(*),NVL(TRUNC(SYSDATE)-TRUNC(MAX(login_time)),99) FROM login_logs WHERE user_id=:user_id AND login_time>=SYSTIMESTAMP-INTERVAL '14' DAY", user_id=body.user_id)
        logins, days_absent = await cursor.fetchone()
        await cursor.execute("""
            SELECT NVL(ROUND(AVG(CASE WHEN qa.total>0 THEN qa.score/qa.total*100 END)),0)
            FROM quiz_attempts qa JOIN quizzes q ON q.id=qa.quiz_id
            WHERE qa.user_id=:user_id AND (:is_admin=1 OR q.created_by=:trainer_id)
        """, user_id=body.user_id, is_admin=int(user.role == "admin"), trainer_id=user.id)
        quiz_avg = int((await cursor.fetchone())[0] or 0)
        await cursor.execute("""
            SELECT NVL(ROUND(100*SUM(CASE WHEN NVL(up.is_completed,0)=1 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0)),0)
            FROM assignments a JOIN courses c ON c.id=a.item_id AND a.item_type='course'
            JOIN modules m ON m.course_id=c.id JOIN chapters ch ON ch.module_id=m.id
            LEFT JOIN user_progress up ON up.chapter_id=ch.id AND up.user_id=a.user_id
            WHERE a.user_id=:user_id AND (:is_admin=1 OR c.created_by=:trainer_id)
        """, user_id=body.user_id, is_admin=int(user.role == "admin"), trainer_id=user.id)
        progress = int((await cursor.fetchone())[0] or 0)
        result = await generate_json(f'''Classify this learner as exactly on_track, needs_nudge, or at_risk.
Logins in 14 days: {logins}; days absent: {days_absent}; course progress: {progress}%; quiz average: {quiz_avg}%.
Return only JSON: {{"risk_level":"on_track","reason":"One short factual sentence"}}''', key, max_output_tokens=300)
        level = result.get("risk_level") if result.get("risk_level") in ("on_track", "needs_nudge", "at_risk") else "on_track"
        reason = str(result.get("reason", ""))[:500]
        await cursor.execute("""
            MERGE INTO ai_risk_scores r USING (SELECT :user_id user_id,:trainer_id trainer_id FROM dual) src
            ON (r.user_id=src.user_id AND r.trainer_id=src.trainer_id)
            WHEN MATCHED THEN UPDATE SET risk_level=:risk_level,reason=:reason,calculated_at=SYSTIMESTAMP
            WHEN NOT MATCHED THEN INSERT(user_id,trainer_id,risk_level,reason,calculated_at) VALUES(src.user_id,src.trainer_id,:risk_level,:reason,SYSTIMESTAMP)
        """, user_id=body.user_id, trainer_id=user.id, risk_level=level, reason=reason)
        await conn.commit()
        return {"user_id": body.user_id, "participant": participant[2], "risk_level": level, "reason": reason,
                "metrics": {"logins_14d": int(logins), "days_absent": int(days_absent), "course_progress": progress, "quiz_average": quiz_avg}}


@router.post("/trainer/nudge")
async def nudge(body: NudgeInput, user: UserProfile = Depends(require_ai_trainer), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        participant = await _permitted_participant(cursor, body.user_id, user)
        key = await trainer_ai_key(cursor, user.id)
        result = await generate_json(f'''Write a supportive learning reminder for {participant[2]}.
Context: {body.context or "They have pending learning activity."}
Avoid blame and pressure. Return only JSON: {{"title":"Short title","message":"2-3 sentences","email_subject":"Subject"}}''', key, max_output_tokens=500)
        title = str(result.get("title", "Learning reminder"))[:255]
        message = str(result.get("message", "Please continue your assigned learning."))[:2000]
        if body.send_notification:
            await cursor.execute("""
                INSERT INTO notifications(user_id,type,title,message,link,is_read,created_at,target_type,fcm_sent)
                VALUES(:user_id,'nudge',:title,:message,'/dashboard',0,SYSTIMESTAMP,'learning',0)
            """, user_id=body.user_id, title=title, message=message)
            await conn.commit()
        return {"title": title, "message": message, "email_subject": str(result.get("email_subject", title))[:255], "sent": body.send_notification}


@router.post("/trainer/knowledge-gaps")
async def knowledge_gaps(body: KnowledgeGapInput, user: UserProfile = Depends(require_ai_trainer), conn=Depends(get_db_connection)):
    if not body.user_id and not body.store_code:
        raise HTTPException(422, "Choose a participant or store")
    async with conn.cursor() as cursor:
        key = await trainer_ai_key(cursor, user.id)
        if body.user_id:
            await _permitted_participant(cursor, body.user_id, user)
            await cursor.execute("""
                SELECT q.text,qu.title FROM quiz_attempt_answers a JOIN quiz_attempts qa ON qa.id=a.attempt_id
                JOIN questions q ON q.id=a.question_id JOIN quizzes qu ON qu.id=q.quiz_id
                WHERE qa.user_id=:user_id AND NVL(a.is_correct,0)=0 AND (:is_admin=1 OR qu.created_by=:trainer_id)
                ORDER BY qa.end_time DESC FETCH FIRST 50 ROWS ONLY
            """, user_id=body.user_id, is_admin=int(user.role == "admin"), trainer_id=user.id)
            rows = await cursor.fetchall()
            scope = f"participant {body.user_id}"
            evidence = [{"question": row[0], "quiz": row[1]} for row in rows]
        else:
            await cursor.execute("""
                SELECT NVL(up.full_name,NVL(u.full_name,u.username)),qu.title,COUNT(*) FROM quiz_attempt_answers a
                JOIN quiz_attempts qa ON qa.id=a.attempt_id JOIN users u ON u.id=qa.user_id
                JOIN user_profiles up ON up.user_id=u.id JOIN questions q ON q.id=a.question_id JOIN quizzes qu ON qu.id=q.quiz_id
                WHERE up.store_code=:store_code AND NVL(a.is_correct,0)=0 AND (:is_admin=1 OR qu.created_by=:trainer_id)
                GROUP BY u.id,up.full_name,u.full_name,u.username,qu.title ORDER BY COUNT(*) DESC FETCH FIRST 100 ROWS ONLY
            """, store_code=body.store_code, is_admin=int(user.role == "admin"), trainer_id=user.id)
            rows = await cursor.fetchall()
            scope = f"store {body.store_code}"
            evidence = [{"participant": row[0], "quiz": row[1], "failures": int(row[2])} for row in rows]
        if not evidence:
            return {"scope": scope, "gaps": [], "message": "No failed quiz evidence was found"}
        result = await generate_json(f'''Analyze this failed-quiz evidence for {scope}:\n{json.dumps(evidence, default=str)}
Return the top three actionable knowledge gaps. Return only JSON:
{{"gaps":[{{"subject_area":"...","reason":"under 20 words","recommended_actions":["action 1","action 2"]}}]}}''', key, max_output_tokens=1500)
        return {"scope": scope, "gaps": result.get("gaps", [])}


async def _chapter_access(cursor, chapter_id: int, user_id: int):
    await cursor.execute("""
        SELECT ch.id,ch.title,ch.content_type,ch.content_path,ch.ai_summary,c.id,c.title,c.description,c.created_by
        FROM chapters ch JOIN modules m ON m.id=ch.module_id JOIN courses c ON c.id=m.course_id
        JOIN assignments a ON a.item_type='course' AND a.item_id=c.id AND a.user_id=:user_id
        WHERE ch.id=:chapter_id AND c.deleted_at IS NULL
    """, user_id=user_id, chapter_id=chapter_id)
    row = await cursor.fetchone()
    if not row:
        raise HTTPException(404, "Assigned chapter not found")
    return row


@router.post("/participant/ask")
async def ask_course(body: AskInput, user: UserProfile = Depends(require_ai_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _participant_ai_enabled(cursor)
        chapter = await _chapter_access(cursor, body.chapter_id, user.id)
        key = await trainer_ai_key(cursor, int(chapter[8]))
        content = _plain_html(chapter[3]) if str(chapter[2]).lower() == "html" else ""
    prompt = f'''You are a concise learning assistant. Answer only from this course context.
Course: {chapter[6]} — {chapter[7] or ""}
Chapter: {chapter[1]}
Content excerpt: {content or "Content is video or external; use only the stated course topic."}
Learner question: {body.question}
Answer in 2-4 clear sentences. If unrelated, politely redirect to the chapter.'''
    return {"answer": await generate_text(prompt, key, max_output_tokens=600)}


@router.post("/participant/takeaways")
async def takeaways(body: ChapterInput, user: UserProfile = Depends(require_ai_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _participant_ai_enabled(cursor)
        chapter = await _chapter_access(cursor, body.chapter_id, user.id)
        if chapter[4]:
            try:
                cached = json.loads(str(chapter[4]))
                return {"takeaways": cached, "cached": True}
            except Exception:
                pass
        content = _plain_html(chapter[3]) if str(chapter[2]).lower() == "html" else ""
        if not content:
            raise HTTPException(422, "Text content is unavailable for summarisation")
        key = await trainer_ai_key(cursor, int(chapter[8]))
        result = await generate_json(f'''Extract 4-5 actionable takeaways for a sales professional.
Course: {chapter[6]}; chapter: {chapter[1]}; content: {content}
Return only JSON: {{"takeaways":["sentence 1","sentence 2"]}}''', key, max_output_tokens=800)
        values = [str(item)[:500] for item in result.get("takeaways", [])][:5]
        if not values:
            raise HTTPException(502, "AI did not return takeaways")
        await cursor.execute("UPDATE chapters SET ai_summary=:summary WHERE id=:chapter_id", summary=json.dumps(values), chapter_id=body.chapter_id)
        await conn.commit()
        return {"takeaways": values, "cached": False}


@router.post("/participant/hints")
async def quiz_hints(body: AttemptInput, user: UserProfile = Depends(require_ai_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _participant_ai_enabled(cursor)
        await cursor.execute("""
            SELECT qa.quiz_id,qa.score,qa.total,q.title,q.created_by FROM quiz_attempts qa JOIN quizzes q ON q.id=qa.quiz_id
            WHERE qa.id=:attempt_id AND qa.user_id=:user_id
        """, attempt_id=body.attempt_id, user_id=user.id)
        attempt = await cursor.fetchone()
        if not attempt:
            raise HTTPException(404, "Quiz attempt not found")
        if int(attempt[2] or 0) <= int(attempt[1] or 0):
            return {"hints": [], "message": "Perfect score—nothing needs clarification"}
        key = await trainer_ai_key(cursor, int(attempt[4]))
        await cursor.execute("""
            SELECT q.text,o.text FROM quiz_attempt_answers a JOIN questions q ON q.id=a.question_id
            JOIN options o ON o.question_id=q.id AND o.is_correct=1
            WHERE a.attempt_id=:attempt_id AND NVL(a.is_correct,0)=0 FETCH FIRST 10 ROWS ONLY
        """, attempt_id=body.attempt_id)
        evidence = [{"question": row[0], "correct_answer": row[1]} for row in await cursor.fetchall()]
        if not evidence:
            return {"hints": [], "message": "Detailed answer history is unavailable"}
        result = await generate_json(f'''Explain why each correct answer is correct without revealing unrelated answers.
Quiz: {attempt[3]}; evidence: {json.dumps(evidence, default=str)}
Return at most five items as JSON: {{"hints":[{{"question":"short label","explanation":"1-2 educational sentences"}}]}}''', key, max_output_tokens=1200)
        return {"hints": result.get("hints", [])[:5]}


@router.get("/participant/recommendations")
async def recommendations(refresh: bool = False, user: UserProfile = Depends(require_ai_participant), conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await _participant_ai_enabled(cursor)
        await cursor.execute("""
            SELECT c.id,c.title,c.description,COUNT(DISTINCT ch.id),COUNT(DISTINCT CASE WHEN NVL(up.is_completed,0)=1 THEN ch.id END),c.created_by
            FROM assignments a JOIN courses c ON c.id=a.item_id AND a.item_type='course'
            LEFT JOIN modules m ON m.course_id=c.id LEFT JOIN chapters ch ON ch.module_id=m.id AND ch.deleted_at IS NULL
            LEFT JOIN user_progress up ON up.chapter_id=ch.id AND up.user_id=a.user_id
            WHERE a.user_id=:user_id AND c.deleted_at IS NULL
            GROUP BY c.id,c.title,c.description,c.created_by ORDER BY c.id
        """, user_id=user.id)
        courses = []
        for row in await cursor.fetchall():
            total, done = int(row[3] or 0), int(row[4] or 0)
            courses.append({"id": int(row[0]), "title": row[1], "description": row[2], "progress": round(done * 100 / total) if total else 0, "trainer_id": int(row[5])})
        candidates = [course for course in courses if course["progress"] < 100]
        if not candidates:
            return {"courses": [], "reasoning": "All assigned courses are complete."}
        try:
            key = await trainer_ai_key(cursor, candidates[0]["trainer_id"])
            result = await generate_json(f'''Recommend the best two assigned courses for this learner to continue next.
Courses: {json.dumps(candidates, default=str)}
Prioritize in-progress work and logical progression. Return only JSON:
{{"recommendations":[course_id,course_id],"reasoning":"one sentence"}}''', key, max_output_tokens=500)
            ids = [int(value) for value in result.get("recommendations", []) if int(value) in {item["id"] for item in candidates}][:2]
            reasoning = str(result.get("reasoning", "Based on your current progress."))
        except HTTPException as exc:
            if exc.status_code != 409:
                raise
            ids = [course["id"] for course in candidates[:2]]
            reasoning = "Based on your current progress."
        by_id = {course["id"]: course for course in candidates}
        return {"courses": [by_id[value] for value in ids], "reasoning": reasoning, "cached": False}
