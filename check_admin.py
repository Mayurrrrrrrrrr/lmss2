import oracledb
import os

def main():
    oracle_conn = oracledb.connect(
        user=os.environ.get("DB_USER", "ADMIN"),
        password=os.environ.get("DB_PASSWORD"),
        dsn=os.environ.get("DB_DSN"),
        wallet_location="C:\\Users\\mayur\\.gemini\\antigravity\\scratch\\lms-new\\wallet",
        wallet_password=os.environ.get("DB_PASSWORD")
    )
    cursor = oracle_conn.cursor()
    cursor.execute("SELECT username, role, email_id, email FROM users WHERE role='admin'")
    rows = cursor.fetchall()
    for row in rows:
        print(row)

if __name__ == "__main__":
    main()
