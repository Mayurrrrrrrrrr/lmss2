import oracledb
import os

def main():
    print("Connecting to Oracle ADB...")
    oracle_conn = oracledb.connect(
        user=os.environ.get("DB_USER", "ADMIN"),
        password=os.environ.get("DB_PASSWORD"),
        dsn=os.environ.get("DB_DSN"),
        wallet_location="C:\\Users\\mayur\\.gemini\\antigravity\\scratch\\lms-new\\wallet",
        wallet_password=os.environ.get("DB_PASSWORD")
    )
    cursor = oracle_conn.cursor()

    stmts = [
        "ALTER TABLE users ADD (full_name VARCHAR2(255), mobile_number VARCHAR2(50), email_id VARCHAR2(255), email VARCHAR2(255), store_code VARCHAR2(100), city VARCHAR2(100), reporting_manager_name VARCHAR2(255), reporting_manager_id NUMBER, profile_pic VARCHAR2(1000), designation VARCHAR2(100), department VARCHAR2(100), last_active TIMESTAMP, status VARCHAR2(50) DEFAULT 'active')",
        "ALTER TABLE courses ADD (thumbnail VARCHAR2(1000))"
    ]

    for stmt in stmts:
        try:
            cursor.execute(stmt)
            print(f"Executed: {stmt}")
        except Exception as e:
            print(f"Error (maybe column exists): {e}")

    oracle_conn.commit()
    print("Done!")

if __name__ == "__main__":
    main()
