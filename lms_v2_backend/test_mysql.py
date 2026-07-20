import pymysql

try:
    conn = pymysql.connect(
        host='localhost',
        user='root',
        password='asjhb5465%&55fss',
        database='lms',
        cursorclass=pymysql.cursors.DictCursor
    )
    with conn.cursor() as cursor:
        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()
        print("MySQL Connection successful! Tables:")
        for table in tables:
            print(table)
    conn.close()
except Exception as e:
    print(f"MySQL Connection failed: {e}")
