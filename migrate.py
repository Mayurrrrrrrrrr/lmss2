import pymysql
import oracledb
import os
import sys

import bcrypt

default_password_hash = bcrypt.hashpw("Pass123".encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def main():
    print("Connecting to Old MySQL (via SSH tunnel)...")
    try:
        mysql_conn = pymysql.connect(
            host='127.0.0.1',
            user='root',
            password='asjhb5465%&55fss',
            database='lms',
            port=3307,
            cursorclass=pymysql.cursors.DictCursor
        )
    except Exception as e:
        print(f"Failed to connect to MySQL: {e}")
        sys.exit(1)

    print("Connecting to New Oracle ADB...")
    try:
        oracle_conn = oracledb.connect(
            user=os.environ.get("DB_USER"),
            password=os.environ.get("DB_PASSWORD"),
            dsn=os.environ.get("DB_DSN"),
            wallet_location="C:\\Users\\mayur\\.gemini\\antigravity\\scratch\\lms-new\\wallet",
            wallet_password=os.environ.get("DB_PASSWORD")
        )
        oracle_cursor = oracle_conn.cursor()
    except Exception as e:
        print(f"Failed to connect to Oracle: {e}")
        sys.exit(1)

    try:
        with mysql_conn.cursor() as my_cursor:
            # 1. Migrate Users & User Profiles
            print("\n--- Migrating Users ---")
            my_cursor.execute("SELECT u.*, p.full_name, p.mobile_number, p.email_id, p.store_code, p.city, p.reporting_manager_name, p.reporting_manager_id, p.profile_pic, p.designation, p.department, p.joining_date FROM users u LEFT JOIN user_profiles p ON u.id = p.user_id")
            users = my_cursor.fetchall()
            
            users_migrated = 0
            for u in users:
                # Upsert into Oracle
                oracle_cursor.execute("""
                    MERGE INTO users t
                    USING (SELECT :id AS id FROM dual) s
                    ON (t.id = s.id)
                    WHEN MATCHED THEN UPDATE SET
                        username = :username, password = :password, role = :role, is_first_login = :is_first_login,
                        full_name = :full_name, mobile_number = :mobile_number, email_id = :email_id,
                        store_code = :store_code, city = :city, reporting_manager_name = :reporting_manager_name,
                        reporting_manager_id = :reporting_manager_id, profile_pic = :profile_pic,
                        designation = :designation, department = :department, created_at = :created_at,
                        last_active = :last_active
                    WHEN NOT MATCHED THEN INSERT (
                        id, username, password, role, is_first_login, full_name, mobile_number, email_id,
                        store_code, city, reporting_manager_name, reporting_manager_id, profile_pic,
                        designation, department, created_at, last_active
                    ) VALUES (
                        :id, :username, :password, :role, :is_first_login, :full_name, :mobile_number, :email_id,
                        :store_code, :city, :reporting_manager_name, :reporting_manager_id, :profile_pic,
                        :designation, :department, :created_at, :last_active
                    )
                """, {
                    'id': u['id'],
                    'username': u['username'],
                    'password': default_password_hash,  # Setting everyone to Pass123
                    'role': u['role'],
                    'is_first_login': u['is_first_login'] if u['is_first_login'] is not None else 1,
                    'full_name': u['full_name'],
                    'mobile_number': u['mobile_number'],
                    'email_id': u['email_id'],
                    'store_code': u['store_code'],
                    'city': u['city'],
                    'reporting_manager_name': u['reporting_manager_name'],
                    'reporting_manager_id': u['reporting_manager_id'],
                    'profile_pic': u['profile_pic'],
                    'designation': u['designation'],
                    'department': u['department'],
                    'created_at': u['created_at'],
                    'last_active': u['last_active']
                })
                users_migrated += 1
            oracle_conn.commit()
            print(f"Migrated {users_migrated} users.")

            # 2. Migrate Courses
            print("\n--- Migrating Courses ---")
            my_cursor.execute("SELECT * FROM courses")
            courses = my_cursor.fetchall()
            for c in courses:
                oracle_cursor.execute("""
                    MERGE INTO courses t
                    USING (SELECT :id AS id FROM dual) s
                    ON (t.id = s.id)
                    WHEN MATCHED THEN UPDATE SET
                        title = :title, description = :description, thumbnail = :thumbnail, is_active = :is_active
                    WHEN NOT MATCHED THEN INSERT (
                        id, title, description, thumbnail, is_active
                    ) VALUES (
                        :id, :title, :description, :thumbnail, :is_active
                    )
                """, {
                    'id': c['id'],
                    'title': c['title'],
                    'description': c['description'],
                    'thumbnail': c['thumbnail_path'],
                    'is_active': c['is_active']
                })
            oracle_conn.commit()
            print(f"Migrated {len(courses)} courses.")

    except Exception as e:
        print(f"Error during migration: {e}")
        oracle_conn.rollback()
    finally:
        mysql_conn.close()
        oracle_cursor.close()
        oracle_conn.close()
        print("Connections closed.")

if __name__ == '__main__':
    main()
