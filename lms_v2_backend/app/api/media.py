from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
import os
import boto3
from typing import Any
from app.core.security import require_user
from app.core.config import settings

router = APIRouter(prefix="/media", tags=["Secure Media"])

@router.get("/stream/{file_path:path}")
async def stream_media(file_path: str, user_id: int = Depends(require_user)) -> Any:
    """
    Secure media streaming endpoint.
    Requires a valid JWT token, preventing direct unauthorized file hotlinking.
    Abstracted to support local disk (temporary) and Oracle Object Storage.
    """
    
    # Future integration: Oracle Object Storage (S3 API compatible)
    if settings.S3_ENDPOINT_URL and settings.S3_ACCESS_KEY_ID:
        try:
            s3 = boto3.client(
                's3', 
                endpoint_url=settings.S3_ENDPOINT_URL,
                aws_access_key_id=settings.S3_ACCESS_KEY_ID,
                aws_secret_access_key=settings.S3_SECRET_ACCESS_KEY,
                region_name=settings.S3_REGION
            )
            # obj = s3.get_object(Bucket=settings.S3_BUCKET_NAME, Key=file_path)
            # return StreamingResponse(obj['Body'].iter_chunks())
        except Exception as e:
            # Fallback to local if object storage fails
            pass

    # Current temporary fallback: serve from local uploads directory
    local_base_path = "/var/www/lms_portal/uploads"
    full_path = os.path.join(local_base_path, file_path)
    
    if not os.path.exists(full_path):
        raise HTTPException(status_code=404, detail="Media file not found.")
        
    return FileResponse(full_path)
