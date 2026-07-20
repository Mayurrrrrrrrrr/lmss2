import oracledb
from fastapi import HTTPException, status
import bcrypt
from app.schemas.user import UserProfile, LoginRequest

def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    except Exception:
        return False

class UserService:
    """
    Asynchronous Service layer handling Oracle DB operations for Users.
    Utilizes the thin client connection provided via dependency injection.
    """
    def __init__(self, conn: oracledb.AsyncConnection):
        self.conn = conn

    async def check_lockout(self, ip_address: str, username: str):
        """
        Mirrors the V1 PHP logic to prevent brute-force attacks.
        Checks if the user has failed 5 or more times in the last 5 minutes.
        """
        # Oracle uses CURRENT_TIMESTAMP - INTERVAL '5' MINUTE for date subtraction
        query = """
            SELECT COUNT(*) 
            FROM login_attempts 
            WHERE ip_address = :ip_address 
              AND username_attempted = :username 
              AND attempt_time > (CURRENT_TIMESTAMP - INTERVAL '5' MINUTE)
        """
        async with self.conn.cursor() as cursor:
            await cursor.execute(query, ip_address=ip_address, username=username)
            row = await cursor.fetchone()
            failures = row[0] if row else 0
            
            if failures >= 5:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Too many login attempts. Please try again after 5 minutes.",
                    headers={"X-Error-Code": "LOCKOUT"}
                )

    async def log_failed_attempt(self, ip_address: str, username: str):
        query = """
            INSERT INTO login_attempts (ip_address, username_attempted, attempt_time) 
            VALUES (:ip_address, :username, CURRENT_TIMESTAMP)
        """
        async with self.conn.cursor() as cursor:
            await cursor.execute(query, ip_address=ip_address, username=username)
            await self.conn.commit()

    async def clear_attempts(self, ip_address: str, username: str):
        query = """
            DELETE FROM login_attempts 
            WHERE ip_address = :ip_address 
              AND username_attempted = :username
        """
        async with self.conn.cursor() as cursor:
            await cursor.execute(query, ip_address=ip_address, username=username)
            await self.conn.commit()

    async def authenticate_user(self, login_req: LoginRequest, ip_address: str) -> UserProfile:
        """
        Validates a user against the Oracle Database.
        Matches exact logic from legacy /api/auth/login.php.
        """
        await self.check_lockout(ip_address, login_req.username)

        query = """
            SELECT u.id, u.username, u.password, u.role, u.is_first_login,
                   COALESCE(p.full_name, u.username) AS full_name,
                   p.email_id, p.mobile_number AS phone, p.designation, p.department
            FROM users u
            LEFT JOIN user_profiles p ON p.user_id = u.id
            WHERE u.username = :username
        """
        async with self.conn.cursor() as cursor:
            await cursor.execute(query, username=login_req.username)
            row = await cursor.fetchone()

            if not row:
                await self.log_failed_attempt(ip_address, login_req.username)
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid username or password.",
                    headers={"X-Error-Code": "INVALID_CREDENTIALS"}
                )

            # Map Oracle row (tuple) to named variables
            (db_id, db_username, db_password, db_role, db_first_login, 
             db_full_name, db_email, db_phone, db_designation, db_dept) = row
            
            # Ensure boolean casting handles Oracle's NUMBER(1) correctly
            is_first_login_bool = bool(db_first_login)

            # Verify password securely via bcrypt
            if not verify_password(login_req.password, db_password):
                await self.log_failed_attempt(ip_address, login_req.username)
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid username or password.",
                    headers={"X-Error-Code": "INVALID_CREDENTIALS"}
                )

            # Success: Clear their penalty box
            await self.clear_attempts(ip_address, login_req.username)

            return UserProfile(
                id=db_id,
                username=db_username,
                full_name=db_full_name,
                email=db_email,
                phone=db_phone,
                designation=db_designation,
                department=db_dept,
                role=db_role,
                is_first_login=is_first_login_bool
            )

    async def get_user_by_id(self, user_id: int) -> UserProfile:
        """
        Fetches a user profile by ID. Used for stateless JWT token validation.
        """
        query = """
            SELECT u.id, u.username, u.password, u.role, u.is_first_login,
                   COALESCE(p.full_name, u.username) AS full_name,
                   p.email_id, p.mobile_number AS phone, p.designation, p.department
            FROM users u
            LEFT JOIN user_profiles p ON p.user_id = u.id
            WHERE u.id = :user_id
        """
        async with self.conn.cursor() as cursor:
            await cursor.execute(query, user_id=user_id)
            row = await cursor.fetchone()

            if not row:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="User not found."
                )

            (db_id, db_username, db_password, db_role, db_first_login, 
             db_full_name, db_email, db_phone, db_designation, db_dept) = row
            
            return UserProfile(
                id=db_id,
                username=db_username,
                full_name=db_full_name,
                email=db_email,
                phone=db_phone,
                designation=db_designation,
                department=db_dept,
                role=db_role,
                is_first_login=bool(db_first_login)
            )
