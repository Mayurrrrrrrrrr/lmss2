import asyncio
import json
import logging
import re
from typing import Any

from fastapi import HTTPException
from google import genai

from app.core.config import settings
from app.core.database import get_db

logger = logging.getLogger(__name__)
MODEL = "gemini-2.5-flash"


async def trainer_ai_key(cursor, trainer_id: int) -> str:
    await cursor.execute("SELECT gemini_api_key FROM trainer_integrations WHERE trainer_id=:trainer_id", trainer_id=trainer_id)
    row = await cursor.fetchone()
    key = str(row[0]).strip() if row and row[0] else settings.GEMINI_API_KEY.strip()
    if not key:
        raise HTTPException(409, "Configure a Gemini API key in Email & AI Settings first")
    return key


async def generate_text(prompt: str, api_key: str, *, max_output_tokens: int = 1024) -> str:
    def call() -> str:
        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model=MODEL,
            contents=prompt,
            config={"max_output_tokens": max_output_tokens, "temperature": 0.25},
        )
        return (response.text or "").strip()

    try:
        result = await asyncio.to_thread(call)
        if not result:
            raise ValueError("empty response")
        return result
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Gemini request failed")
        raise HTTPException(502, "AI service is temporarily unavailable") from exc


async def generate_json(prompt: str, api_key: str, *, max_output_tokens: int = 2048) -> Any:
    raw = await generate_text(prompt, api_key, max_output_tokens=max_output_tokens)
    cleaned = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw.strip(), flags=re.I | re.S).strip()
    try:
        return json.loads(cleaned)
    except json.JSONDecodeError as exc:
        logger.warning("Gemini returned invalid JSON: %s", cleaned[:500])
        raise HTTPException(502, "AI returned an invalid structured response; please retry") from exc


async def generate_executive_summary(metrics: dict, trainer_id: int) -> str:
    async with get_db() as db:
        async with db.cursor() as cursor:
            key = await trainer_ai_key(cursor, trainer_id)
    prompt = f"""You are an LMS data analyst. Write a professional three-sentence executive summary with no headings.
Active assignments: {metrics.get('total_assignments', 0)}
Average course progress: {metrics.get('avg_progress', 0)}%
Average quiz score: {metrics.get('avg_score', 0)}%
State the result, the biggest concern, and one practical next action."""
    return await generate_text(prompt, key, max_output_tokens=256)
