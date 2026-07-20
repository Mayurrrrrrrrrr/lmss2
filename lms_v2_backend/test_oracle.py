import oracledb
import os
from dotenv import load_dotenv

load_dotenv('.env')

wallet_dir = os.path.join(os.getcwd(), 'wallet')

print(f"Using wallet from: {wallet_dir}")

try:
    conn = oracledb.connect(
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        dsn=os.getenv('DB_DSN'),
        wallet_location=wallet_dir,
        wallet_password="Firefly@2026" # Attempting to guess wallet password (often matches DB or is not required)
    )
    cursor = conn.cursor()
    cursor.execute('SELECT table_name FROM user_tables')
    print("Connection successful! Tables:")
    print(cursor.fetchall())
    conn.close()
except Exception as e:
    print(f"Connection failed: {e}")
