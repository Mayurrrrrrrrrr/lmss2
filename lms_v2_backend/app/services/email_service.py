import aiosmtplib
from email.message import EmailMessage
from app.core.database import get_db
import logging

logger = logging.getLogger(__name__)

async def send_reset_password_email(email_to: str, reset_token: str):
    """
    Sends an async email for password recovery.
    Dynamically fetches tenant SMTP credentials from the database.
    """
    smtp_config = None
    try:
        async with get_db() as db:
            async with db.cursor() as cursor:
                # Fetch the first valid SMTP configuration from any trainer
                await cursor.execute("""
                    SELECT smtp_host, smtp_port, smtp_user, smtp_password, smtp_from_email 
                    FROM trainer_integrations 
                    WHERE smtp_host IS NOT NULL AND smtp_user IS NOT NULL 
                    FETCH FIRST 1 ROWS ONLY
                """)
                smtp_config = await cursor.fetchone()
    except Exception as e:
        logger.error(f"Error fetching SMTP settings from database: {e}")

    if not smtp_config:
        logger.warning(f"No SMTP integrations configured by any trainer. Skipping email to {email_to}")
        return False

    host, port, user, password, from_email = smtp_config

    subject = "Reset Your Password - Firefly LMS"
    body = f"""
    You have requested to reset your password.
    Please use this recovery token in your mobile app: {reset_token}
    
    If you did not request this, please safely ignore this email.
    """

    message = EmailMessage()
    message["From"] = from_email or "noreply@lms.yuktaa.com"
    message["To"] = email_to
    message["Subject"] = subject
    message.set_content(body)

    try:
        await aiosmtplib.send(
            message,
            hostname=host,
            port=port,
            start_tls=True,
            username=user,
            password=password,
        )
        return True
    except Exception as e:
        logger.error(f"Failed to send email to {email_to}: {e}")
        return False
