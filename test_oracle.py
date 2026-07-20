import oracledb
import os

try:
    oracle_conn = oracledb.connect(
        user="ADMIN",
        password="Firefly@2026",
        dsn="(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ap-hyderabad-1.oraclecloud.com))(connect_data=(service_name=gc95999bab870f9_lmsdb_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
    )
    print("SUCCESS: Connected to Oracle DB on port 1522!")
    oracle_conn.close()
except Exception as e:
    print(f"FAILED on 1522: {e}")

try:
    oracle_conn = oracledb.connect(
        user="ADMIN",
        password="Firefly@2026",
        dsn="(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1521)(host=adb.ap-hyderabad-1.oraclecloud.com))(connect_data=(service_name=gc95999bab870f9_lmsdb_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
    )
    print("SUCCESS: Connected to Oracle DB on port 1521!")
    oracle_conn.close()
except Exception as e:
    print(f"FAILED on 1521: {e}")
