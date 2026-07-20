import oracledb
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Connection pool instance
_pool: oracledb.AsyncConnectionPool | None = None

async def init_db_pool():
    """
    Initialize the asynchronous connection pool using python-oracledb in Thin Mode.
    Thin mode is the default and does not require Oracle Client libraries, 
    significantly saving on RAM and disk space, aligning with the < 1 GB RAM limit.
    """
    global _pool
    try:
        user = settings.DB_USER
        password = settings.DB_PASSWORD
        dsn = settings.DB_DSN
        
        if not all([user, password, dsn]):
            logger.warning("Database credentials (DB_USER, DB_PASSWORD, DB_DSN) not fully configured")
            return

        # python-oracledb defaults to Thin mode; no init_oracle_client() is called.
        _pool = oracledb.create_pool_async(
            user=user,
            password=password,
            dsn=dsn,
            min=1,           # Keep minimum connections low to save memory
            max=5,           # Cap maximum connections to prevent RAM exhaustion
            increment=1,
            wallet_location="/home/ubuntu/wallet",
            wallet_password=password
        )
        logger.info("Oracle DB Async Connection Pool initialized (Thin Mode).")
    except Exception as e:
        logger.error(f"Failed to initialize Oracle DB Pool: {e}")
        raise

async def close_db_pool():
    """
    Close the asynchronous connection pool.
    """
    global _pool
    if _pool:
        await _pool.close()
        logger.info("Oracle DB Async Connection Pool closed.")

async def get_db_connection() -> oracledb.AsyncConnection:
    """
    Dependency to yield an asynchronous database connection from the pool.
    Usage in FastAPI endpoints:
    @app.get("/")
    async def endpoint(conn: oracledb.AsyncConnection = Depends(get_db_connection)):
        ...
    """
    if not _pool:
        raise RuntimeError("Database pool is not initialized.")
        
    async with _pool.acquire() as connection:
        yield connection

from contextlib import asynccontextmanager

@asynccontextmanager
async def get_db():
    if not _pool:
        raise RuntimeError("Database pool is not initialized.")
    async with _pool.acquire() as connection:
        yield connection
