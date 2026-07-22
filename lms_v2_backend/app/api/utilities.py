import csv
import io
import inspect
import re

import oracledb
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import StreamingResponse

from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile

router = APIRouter()
MAX_CSV_SIZE = 2 * 1024 * 1024


async def _page_dict(row):
    content = row[3]
    if hasattr(content, "read"):
        value = content.read()
        content = await value if inspect.isawaitable(value) else value
    return {"id": row[0], "title": row[1], "slug": row[2], "content": content or "", "created_at": row[4]}


async def _quiz_owner(cursor, quiz_id: int, user: UserProfile):
    sql = "SELECT id,title FROM quizzes WHERE id=:quiz_id AND deleted_at IS NULL"
    params = {"quiz_id": quiz_id}
    if user.role != "admin":
        sql += " AND created_by=:owner_id"
        params["owner_id"] = user.id
    await cursor.execute(sql, params)
    row = await cursor.fetchone()
    if not row or user.role not in ("trainer", "admin"):
        raise HTTPException(404, "Quiz not found or not owned by you")
    return row


@router.get("/trainer/quizzes/{quiz_id}/questions/export")
async def export_questions(quiz_id: int, user: UserProfile = Depends(get_current_user), conn=Depends(get_db_connection)):
    output = io.StringIO(newline="")
    writer = csv.writer(output)
    writer.writerow(["Question Text", "Option A", "Option B", "Option C", "Option D", "Correct Index", "Difficulty"])
    async with conn.cursor() as cursor:
        quiz = await _quiz_owner(cursor, quiz_id, user)
        await cursor.execute("SELECT id,text,difficulty FROM questions WHERE quiz_id=:quiz_id AND deleted_at IS NULL ORDER BY id", quiz_id=quiz_id)
        for question_id, text, difficulty in await cursor.fetchall():
            await cursor.execute("SELECT text,is_correct FROM options WHERE question_id=:question_id ORDER BY id", question_id=question_id)
            options = await cursor.fetchall()
            values = [str(row[0] or "") for row in options[:4]]
            values.extend([""] * (4 - len(values)))
            correct = next((index for index, row in enumerate(options[:4]) if bool(row[1])), 0)
            writer.writerow([text, *values, correct, difficulty or ""])
    safe_title = re.sub(r"[^A-Za-z0-9_-]+", "_", str(quiz[1])).strip("_") or "quiz"
    content = "\ufeff" + output.getvalue()
    return StreamingResponse(iter([content.encode("utf-8")]), media_type="text/csv; charset=utf-8",
                             headers={"Content-Disposition": f'attachment; filename="quiz_{safe_title}_questions.csv"'})


@router.post("/trainer/quizzes/{quiz_id}/questions/import")
async def import_questions(quiz_id: int, request: Request, user: UserProfile = Depends(get_current_user), conn=Depends(get_db_connection)):
    raw = await request.body()
    if not raw or len(raw) > MAX_CSV_SIZE:
        raise HTTPException(413, "Choose a non-empty CSV file up to 2 MB")
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise HTTPException(422, "CSV must use UTF-8 encoding") from exc
    reader = csv.reader(io.StringIO(text))
    rows = list(reader)
    if not rows:
        raise HTTPException(422, "CSV is empty")
    header = [item.strip().lower() for item in rows[0]]
    has_header = bool(header and ("question" in header[0] or "option" in " ".join(header)))
    data_rows = rows[1:] if has_header else rows
    parsed, errors = [], []
    correct_map = {"0": 0, "a": 0, "1": 1, "b": 1, "2": 2, "c": 2, "3": 3, "d": 3}
    for line, row in enumerate(data_rows, start=2 if has_header else 1):
        if not row or not any(value.strip() for value in row):
            continue
        if len(row) < 6:
            errors.append(f"Line {line}: expected at least 6 columns")
            continue
        question, options, correct_raw = row[0].strip(), [value.strip() for value in row[1:5]], row[5].strip().lower()
        difficulty = row[6].strip().lower() if len(row) > 6 else None
        if not question or any(not option for option in options):
            errors.append(f"Line {line}: question and all four options are required")
            continue
        if correct_raw not in correct_map:
            errors.append(f"Line {line}: correct index must be 0-3 or A-D")
            continue
        if difficulty not in (None, "", "easy", "medium", "hard"):
            errors.append(f"Line {line}: difficulty must be easy, medium, or hard")
            continue
        parsed.append((question[:4000], [option[:1000] for option in options], correct_map[correct_raw], difficulty or None))
    if errors:
        raise HTTPException(422, {"message": "CSV validation failed", "errors": errors[:50]})
    if not parsed:
        raise HTTPException(422, "CSV contains no valid question rows")
    if len(parsed) > 500:
        raise HTTPException(422, "Import is limited to 500 questions at a time")
    async with conn.cursor() as cursor:
        await _quiz_owner(cursor, quiz_id, user)
        try:
            for question, options, correct, difficulty in parsed:
                out_id = cursor.var(oracledb.NUMBER)
                await cursor.execute("INSERT INTO questions(quiz_id,text,image_path,difficulty) VALUES(:quiz_id,:text,NULL,:difficulty) RETURNING id INTO :out_id", quiz_id=quiz_id, text=question, difficulty=difficulty, out_id=out_id)
                question_id = int(out_id.getvalue()[0])
                for index, option in enumerate(options):
                    await cursor.execute("INSERT INTO options(question_id,text,is_correct) VALUES(:question_id,:text,:correct)", question_id=question_id, text=option, correct=int(index == correct))
            await conn.commit()
        except Exception:
            await conn.rollback()
            raise
    return {"imported": len(parsed), "message": f"Imported {len(parsed)} questions"}


@router.get("/participant/search")
async def participant_search(q: str = "", user: UserProfile = Depends(get_current_user), conn=Depends(get_db_connection)):
    if user.role not in ("participant", "area_manager", "admin"):
        raise HTTPException(403, "Requires participant privileges")
    query = q.strip()
    if len(query) < 2:
        return {"query": query, "results": []}
    pattern = f"%{query.lower()}%"
    async with conn.cursor() as cursor:
        await cursor.execute("""
            SELECT item_type,item_id,title,description FROM (
                SELECT 'course' item_type,c.id item_id,c.title,c.description
                FROM assignments a JOIN courses c ON a.item_type='course' AND c.id=a.item_id
                WHERE a.user_id=:user_id AND c.deleted_at IS NULL AND (LOWER(c.title) LIKE :pattern OR LOWER(NVL(c.description,'')) LIKE :pattern)
                UNION ALL
                SELECT 'quiz',qu.id,qu.title,qu.quiz_description
                FROM assignments a JOIN quizzes qu ON a.item_type='quiz' AND qu.id=a.item_id
                WHERE a.user_id=:user_id AND qu.deleted_at IS NULL AND (LOWER(qu.title) LIKE :pattern OR LOWER(NVL(qu.quiz_description,'')) LIKE :pattern)
            ) ORDER BY item_type,title FETCH FIRST 30 ROWS ONLY
        """, user_id=user.id, pattern=pattern)
        keys = ["type", "id", "title", "description"]
        return {"query": query, "results": [dict(zip(keys, row)) for row in await cursor.fetchall()]}


@router.get("/participant/pages")
async def public_pages(user: UserProfile = Depends(get_current_user), conn=Depends(get_db_connection)):
    if user.role not in ("participant", "area_manager", "trainer", "admin"):
        raise HTTPException(403, "Not permitted")
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id,title,url_slug,html_content,created_at FROM static_pages WHERE is_public=1 ORDER BY title")
        return {"pages": [await _page_dict(row) for row in await cursor.fetchall()]}


@router.get("/participant/pages/{slug}")
async def public_page(slug: str, user: UserProfile = Depends(get_current_user), conn=Depends(get_db_connection)):
    if user.role not in ("participant", "area_manager", "trainer", "admin"):
        raise HTTPException(403, "Not permitted")
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT id,title,url_slug,html_content,created_at FROM static_pages WHERE is_public=1 AND url_slug=:slug", slug=slug)
        row = await cursor.fetchone()
        if not row:
            raise HTTPException(404, "Page not found")
        return await _page_dict(row)
