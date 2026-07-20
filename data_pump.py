import mysql.connector
import oracledb
import os

def main():
    print("Connecting to MySQL...")
    mysql_conn = mysql.connector.connect(
        host="127.0.0.1",
        port=3307,
        user="root",
        password="asjhb5465%&55fss",
        database="lms"
    )
    mysql_cursor = mysql_conn.cursor(dictionary=True)
    
    print("Connecting to Oracle ADB...")
    oracle_conn = oracledb.connect(
        user=os.environ.get("DB_USER", "ADMIN"),
        password=os.environ.get("DB_PASSWORD"),
        dsn=os.environ.get("DB_DSN"),
        wallet_location="C:\\Users\\mayur\\.gemini\\antigravity\\scratch\\lms-new\\wallet",
        wallet_password=os.environ.get("DB_PASSWORD")
    )
    oracle_cursor = oracle_conn.cursor()

    tables = ["chapters", "daily_booster_attempts"]
    for table in tables:
        print(f"Migrating table: {table}")
        
        # In Oracle, table names are uppercase
        oracle_table = table.upper()
        
        mysql_cursor.execute(f"SELECT * FROM {table}")
        rows = mysql_cursor.fetchall()
        
        if not rows:
            print("  -> 0 rows.")
            continue
            
        columns = list(rows[0].keys())
        oracle_columns = [col.upper() for col in columns]
        
        # Some tables have triggers or identity, but we can override or just insert
        # For simplicity, we'll try to insert. If it fails due to identity, we'll ignore or handle.
        placeholders = [f":{i+1}" for i in range(len(columns))]
        insert_stmt = f"INSERT INTO {oracle_table} ({', '.join(oracle_columns)}) VALUES ({', '.join(placeholders)})"
        
        success = 0
        for row in rows:
            values = tuple(row[col] for col in columns)
            try:
                oracle_cursor.execute(insert_stmt, values)
                success += 1
            except Exception as e:
                print(f"Row error in {table}: {e}")
                
        print(f"  -> {success}/{len(rows)} rows inserted.")
        oracle_conn.commit()
        
    print("Done!")

if __name__ == "__main__":
    main()
