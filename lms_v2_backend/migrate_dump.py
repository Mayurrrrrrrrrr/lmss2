import oracledb
import os
import re
from dotenv import load_dotenv

load_dotenv('.env')

wallet_dir = os.path.join(os.getcwd(), 'wallet')

def get_oracle_connection():
    return oracledb.connect(
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        dsn=os.getenv('DB_DSN'),
        wallet_location=wallet_dir,
        wallet_password="Firefly@2026"
    )

def parse_mysql_values(values_str):
    import ast
    values_str = re.sub(r'(?i)\bNULL\b', 'None', values_str)
    try:
        data = ast.literal_eval('[' + values_str + ']')
        return data
    except Exception as e:
        print(f"Error parsing row: {e}")
        return []

def extract_schemas_and_inserts(dump_file, target_tables):
    inserts = {table: [] for table in target_tables}
    schemas = {table: [] for table in target_tables}
    
    current_table = None
    
    with open(dump_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            
            # Match CREATE TABLE `table`
            ct_match = re.match(r'CREATE TABLE `([^`]+)`', line, re.IGNORECASE)
            if ct_match:
                table = ct_match.group(1).lower()
                if table in target_tables:
                    current_table = table
                else:
                    current_table = None
                continue
                
            # If inside CREATE TABLE, extract columns
            if current_table and line.startswith('`'):
                col_match = re.match(r'`([^`]+)`', line)
                if col_match:
                    schemas[current_table].append(col_match.group(1))
                    
            if line.startswith(') ENGINE='):
                current_table = None
                
            # Match INSERT INTO
            if line.startswith('INSERT INTO'):
                match = re.match(r'INSERT INTO `?([^` ]+)`? (?:.*? )?VALUES\s*(.*);', line, re.IGNORECASE)
                if match:
                    table = match.group(1).lower()
                    if table in target_tables:
                        values_str = match.group(2)
                        parsed_tuples = parse_mysql_values(values_str)
                        inserts[table].extend(parsed_tuples)
                        
    return schemas, inserts

def migrate():
    target_tables = ['users', 'user_profiles', 'stores', 'designations', 'departments']
    dump_file = r'C:\Users\mayur\.gemini\antigravity\scratch\lms-new\lms_dump.sql'
    
    print("Parsing MySQL dump...")
    schemas, inserts = extract_schemas_and_inserts(dump_file, target_tables)
    
    print("Connecting to Oracle...")
    conn = get_oracle_connection()
    cursor = conn.cursor()
    
    # Fix the date format for Oracle so it parses MySQL dates like '2023-01-01 10:00:00' correctly!
    cursor.execute("ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'")
    cursor.execute("ALTER SESSION SET NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'")
    
    for table in target_tables:
        rows = inserts.get(table, [])
        cols = schemas.get(table, [])
        
        if not rows or not cols:
            print(f"No data or schema found for {table}, skipping.")
            continue
            
        print(f"Migrating {len(rows)} rows into {table}...")
        
        # Build INSERT statement with explicit column names
        col_names = ', '.join(cols)
        binds = ', '.join([':' + str(i+1) for i in range(len(cols))])
        sql = f"INSERT INTO {table} ({col_names}) VALUES ({binds})"
        
        try:
            cursor.execute(f"DELETE FROM {table}")
            conn.commit()
            cursor.executemany(sql, rows)
            conn.commit()
            print(f"Successfully migrated {table}!")
        except Exception as e:
            print(f"Failed to migrate {table}: {e}")
            conn.rollback()

    conn.close()
    print("Migration complete!")

if __name__ == '__main__':
    migrate()
