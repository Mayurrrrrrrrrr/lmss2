import logging
from google import genai
from app.core.database import get_db

logger = logging.getLogger(__name__)

async def generate_executive_summary(metrics: dict, trainer_id: int) -> str:
    """
    Generates a motivational summary of trainer KPIs using Google Gemini 2.5 Flash.
    """
    gemini_key = None
    try:
        async with get_db() as db:
            async with db.cursor() as cursor:
                await cursor.execute("SELECT gemini_api_key FROM trainer_integrations WHERE trainer_id = :tid", tid=trainer_id)
                row = await cursor.fetchone()
                if row and row[0]:
                    gemini_key = row[0]
    except Exception as e:
        logger.error(f"Error fetching Gemini API key for trainer {trainer_id}: {e}")

    if not gemini_key:
        logger.warning(f"Gemini API key missing for trainer {trainer_id}. Returning generic summary.")
        return "Your team is performing adequately. (AI Summaries are disabled until you configure your Gemini API Key in the integrations dashboard)."
        
    try:
        client = genai.Client(api_key=gemini_key)
        
        prompt = f"""
        You are an expert Learning Management System (LMS) data analyst. 
        Review the following trainer metrics for their student cohort and provide a highly professional, 
        concise 3-sentence executive summary. Do not use markdown headers or bullet points.
        
        Trainer Metrics:
        - Total Active Assignments: {metrics.get('total_assignments', 0)}
        - Average Course Progress: {metrics.get('avg_progress', 0)}%
        - Average Quiz Score: {metrics.get('avg_score', 0)}%
        """
        
        # We explicitly use flash per legacy V1 specs for fast generation speeds
        response = client.models.generate_content(
            model='gemini-2.5-flash',
            contents=prompt,
        )
        return response.text.strip()
    except Exception as e:
        logger.error(f"Failed to generate AI summary via GenAI: {e}")
        return "Failed to generate AI summary at this time. Please try again later."
