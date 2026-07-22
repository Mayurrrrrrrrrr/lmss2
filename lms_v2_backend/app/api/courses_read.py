from typing import Any
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, Request, status
import oracledb

from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile


router = APIRouter(prefix="/courses", tags=["Courses"])


def _require_learner(user: UserProfile = Depends(get_current_user)) -> UserProfile:
    if user.role not in {"participant", "area_manager", "admin"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This course view is available to learners only.",
        )
    return user


def _media_url(request: Request, raw_path: Any) -> str | None:
    if not raw_path:
        return None
    value = str(raw_path)
    if value.startswith(("http://", "https://")):
        return value
    clean = value.lstrip("/")
    return str(request.base_url).rstrip("/") + "/api/v2/media/stream/" + quote(clean)


@router.get("/list")
async def list_courses(
    request: Request,
    user: UserProfile = Depends(_require_learner),
    conn: oracledb.AsyncConnection = Depends(get_db_connection),
) -> dict[str, Any]:
    async with conn.cursor() as cursor:
        await cursor.execute(
            """
            SELECT c.id, c.title, c.description, c.thumbnail_path,
                   (SELECT COUNT(*)
                      FROM chapters ch
                      JOIN modules m ON m.id = ch.module_id
                     WHERE m.course_id = c.id
                       AND ch.deleted_at IS NULL
                       AND m.deleted_at IS NULL) AS total_chapters,
                   (SELECT COUNT(*)
                      FROM user_progress up
                      JOIN chapters ch ON ch.id = up.chapter_id
                      JOIN modules m ON m.id = ch.module_id
                     WHERE m.course_id = c.id
                       AND up.user_id = :learner_id
                       AND up.is_completed = 1
                       AND ch.deleted_at IS NULL
                       AND m.deleted_at IS NULL) AS completed_chapters
              FROM courses c
             WHERE c.deleted_at IS NULL
               AND EXISTS (
                   SELECT 1 FROM assignments a
                    WHERE a.item_id = c.id
                      AND a.item_type = 'course'
                      AND a.user_id = :learner_id
               )
             ORDER BY (
                 SELECT MAX(a.assigned_date) FROM assignments a
                  WHERE a.item_id = c.id
                    AND a.item_type = 'course'
                    AND a.user_id = :learner_id
             ) DESC NULLS LAST
            """,
            learner_id=user.id,
        )
        rows = await cursor.fetchall()

    courses = []
    for row in rows:
        total = int(row[4] or 0)
        completed = int(row[5] or 0)
        progress = round(completed * 100 / total) if total else 0
        courses.append(
            {
                "id": int(row[0]),
                "title": row[1] or "",
                "description": row[2] or "",
                "thumbnail_url": _media_url(request, row[3]),
                "total_chapters": total,
                "completed_chapters": completed,
                "progress_percent": progress,
                "is_complete": progress >= 100,
            }
        )
    return {"success": True, "courses": courses}


@router.get("/detail")
async def course_detail(
    course_id: int,
    request: Request,
    user: UserProfile = Depends(_require_learner),
    conn: oracledb.AsyncConnection = Depends(get_db_connection),
) -> dict[str, Any]:
    async with conn.cursor() as cursor:
        await cursor.execute(
            """
            SELECT c.id, c.title, c.description, c.assessment_score
              FROM courses c
             WHERE c.id = :course_id
               AND c.deleted_at IS NULL
               AND EXISTS (
                   SELECT 1 FROM assignments a
                    WHERE a.item_id = c.id
                      AND a.item_type = 'course'
                      AND a.user_id = :learner_id
               )
            """,
            course_id=course_id,
            learner_id=user.id,
        )
        course = await cursor.fetchone()
        if not course:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Course not found or not assigned to you.",
            )

        await cursor.execute(
            """
            SELECT m.id, m.title, m.sequence_order,
                   ch.id, ch.title, ch.content_type, ch.content_path,
                   ch.sequence_order,
                   NVL(up.is_completed, 0), NVL(up.progress_percent, 0)
              FROM modules m
              LEFT JOIN chapters ch
                ON ch.module_id = m.id AND ch.deleted_at IS NULL
              LEFT JOIN user_progress up
                ON up.chapter_id = ch.id AND up.user_id = :learner_id
             WHERE m.course_id = :course_id
               AND m.deleted_at IS NULL
             ORDER BY m.sequence_order, ch.sequence_order
            """,
            learner_id=user.id,
            course_id=course_id,
        )
        content_rows = await cursor.fetchall()

        await cursor.execute(
            """
            SELECT q.id, q.title,
                   (SELECT COUNT(*) FROM quiz_attempts qa
                     WHERE qa.user_id = :learner_id AND qa.quiz_id = q.id),
                   (SELECT score FROM (
                       SELECT qa.score FROM quiz_attempts qa
                        WHERE qa.user_id = :learner_id AND qa.quiz_id = q.id
                        ORDER BY qa.id DESC
                   ) WHERE ROWNUM = 1),
                   (SELECT total FROM (
                       SELECT qa.total FROM quiz_attempts qa
                        WHERE qa.user_id = :learner_id AND qa.quiz_id = q.id
                        ORDER BY qa.id DESC
                   ) WHERE ROWNUM = 1)
              FROM assignments a
              JOIN quizzes q ON q.id = a.item_id
             WHERE a.item_type = 'quiz'
               AND a.course_id = :course_id
               AND a.user_id IS NULL
               AND q.deleted_at IS NULL
             FETCH FIRST 1 ROW ONLY
            """,
            learner_id=user.id,
            course_id=course_id,
        )
        quiz = await cursor.fetchone()

    modules_by_id: dict[int, dict[str, Any]] = {}
    total = completed = 0
    for row in content_rows:
        module_id = int(row[0])
        module = modules_by_id.setdefault(
            module_id,
            {
                "id": module_id,
                "title": row[1] or "",
                "sequence_order": int(row[2] or 0),
                "chapters": [],
            },
        )
        if row[3] is None:
            continue
        total += 1
        is_completed = bool(row[8])
        completed += int(is_completed)
        content_type = row[5] or ""
        module["chapters"].append(
            {
                "id": int(row[3]),
                "title": row[4] or "",
                "content_type": content_type,
                "sequence_order": int(row[7] or 0),
                "media_url": None if content_type == "html" else _media_url(request, row[6]),
                "html_content": str(row[6]) if content_type == "html" and row[6] else None,
                "is_completed": is_completed,
                "progress_percent": int(row[9] or 0),
            }
        )

    overall = round(completed * 100 / total) if total else 0
    return {
        "success": True,
        "course": {
            "id": int(course[0]),
            "title": course[1] or "",
            "description": course[2] or "",
            "assessment_score": int(course[3] or 0),
            "overall_progress": overall,
            "total_chapters": total,
            "completed_chapters": completed,
        },
        "modules": list(modules_by_id.values()),
        "linked_quiz": None
        if not quiz
        else {
            "id": int(quiz[0]),
            "title": quiz[1] or "",
            "attempt_count": int(quiz[2] or 0),
            "last_score": quiz[3],
            "last_total": quiz[4],
        },
    }


@router.get("/chapter_content")
async def chapter_content(
    chapter_id: int,
    user: UserProfile = Depends(_require_learner),
    conn: oracledb.AsyncConnection = Depends(get_db_connection),
) -> dict[str, Any]:
    async with conn.cursor() as cursor:
        await cursor.execute(
            """
            SELECT ch.id, ch.content_type, ch.content_path
              FROM chapters ch
              JOIN modules m ON m.id = ch.module_id
             WHERE ch.id = :chapter_id
               AND ch.deleted_at IS NULL
               AND m.deleted_at IS NULL
               AND EXISTS (
                   SELECT 1 FROM assignments a
                    WHERE a.item_id = m.course_id
                      AND a.item_type = 'course'
                      AND a.user_id = :learner_id
               )
            """,
            chapter_id=chapter_id,
            learner_id=user.id,
        )
        chapter = await cursor.fetchone()
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found or access denied.")
    content_type = chapter[1] or ""
    return {
        "success": True,
        "chapter_id": int(chapter[0]),
        "content_type": content_type,
        "html_content": str(chapter[2]) if content_type == "html" and chapter[2] else None,
    }
