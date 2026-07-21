from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from app.core.database import get_db_connection
from app.core.security import get_current_user
from app.schemas.user import UserProfile

router=APIRouter()

class AppConfigInput(BaseModel):
    latest_android_version:str=Field(min_length=1,max_length=50)
    min_android_version:str=Field(min_length=1,max_length=50)
    apk_download_url:str|None=Field(default=None,max_length=2000)

async def require_admin_or_trainer(user:UserProfile=Depends(get_current_user)):
    if user.role not in ('admin','trainer'):raise HTTPException(403,'Requires admin or trainer privileges')
    return user

@router.get('/app-config')
async def app_config(conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT setting_key,setting_value FROM system_settings WHERE setting_key IN ('latest_android_version','min_android_version','apk_download_url')")
        values={r[0]:r[1] for r in await cursor.fetchall()}
        return {'latest_android_version':values.get('latest_android_version','1.0.0'),'min_android_version':values.get('min_android_version','1.0.0'),'apk_download_url':values.get('apk_download_url')}

@router.put('/admin/app-config')
async def update_app_config(body:AppConfigInput,user:UserProfile=Depends(get_current_user),conn=Depends(get_db_connection)):
    if user.role!='admin':raise HTTPException(403,'Requires admin privileges')
    async with conn.cursor() as cursor:
        for key,value in body.model_dump().items():
            await cursor.execute("MERGE INTO system_settings s USING(SELECT :key setting_key,:value setting_value FROM dual) src ON(s.setting_key=src.setting_key) WHEN MATCHED THEN UPDATE SET s.setting_value=src.setting_value WHEN NOT MATCHED THEN INSERT(setting_key,setting_value) VALUES(src.setting_key,src.setting_value)",key=key,value=value)
        await conn.commit();return {'success':True}

@router.get('/trainer/app-versions')
async def app_versions(user:UserProfile=Depends(require_admin_or_trainer),conn=Depends(get_db_connection)):
    async with conn.cursor() as cursor:
        await cursor.execute("SELECT setting_value FROM system_settings WHERE setting_key='latest_android_version'");row=await cursor.fetchone();latest=row[0] if row else '1.0.0'
        owner_filter="" if user.role=='admin' else " AND u.id IN(SELECT DISTINCT a.user_id FROM assignments a LEFT JOIN courses c ON a.item_type='course' AND c.id=a.item_id LEFT JOIN quizzes q ON a.item_type='quiz' AND q.id=a.item_id WHERE c.created_by=:owner OR q.created_by=:owner)"
        await cursor.execute("SELECT u.id,u.username,NVL(up.full_name,NVL(u.full_name,u.username)),up.android_app_version,up.last_app_ping FROM users u LEFT JOIN user_profiles up ON up.user_id=u.id WHERE LOWER(u.role)='participant'"+owner_filter+" ORDER BY up.last_app_ping DESC NULLS LAST",{} if user.role=='admin' else {'owner':user.id})
        return {'latest_version':latest,'users':[{'id':r[0],'username':r[1],'full_name':r[2],'app_version':r[3],'last_app_ping':r[4]} for r in await cursor.fetchall()]}
