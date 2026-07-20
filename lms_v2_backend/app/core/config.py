from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Literal

class Settings(BaseSettings):
    PROJECT_NAME: str = "Firefly LMS V2"
    ENVIRONMENT: Literal["development", "production", "testing"] = "production"
    API_V1_STR: str = "/api/v1"
    
    # Gamification
    DAILY_BOOSTER_XP: int = 45

    # SMTP Configuration (Mock)
    SMTP_HOST: str = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USER: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = "noreply@lms.yuktaa.com"

    # Gemini AI API Key
    GEMINI_API_KEY: str = ""

    # Oracle / AWS S3 Configuration
    S3_ENDPOINT_URL: str = ""
    S3_ACCESS_KEY_ID: str = ""
    S3_SECRET_ACCESS_KEY: str = ""
    S3_BUCKET_NAME: str = "lms-media-bucket"
    S3_REGION: str = "us-ashburn-1"

    # Firebase Settings
    FIREBASE_CREDENTIALS_PATH: str = "serviceAccountKey.json"

    # Database Settings
    DB_USER: str = ""
    DB_PASSWORD: str = ""
    DB_DSN: str = ""
    
    # Token Settings
    SECRET_KEY: str = "change_this_in_production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30 * 12 * 5 # 5 years approx to match V1 logic

    model_config = SettingsConfigDict(env_file=".env", env_ignore_empty=True, extra="ignore")

settings = Settings()
