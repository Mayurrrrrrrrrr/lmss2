"""Audit or advance Oracle identity sequences beyond migrated primary-key values."""

import argparse
import asyncio
import json
import re

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool


async def main(apply: bool):
    await init_db_pool()
    results = []
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute("""
                    SELECT table_name, column_name, sequence_name
                    FROM user_tab_identity_cols
                    WHERE table_name NOT LIKE 'BIN$%'
                """)
                identity_cols = await cursor.fetchall()

                for table, column, sequence in identity_cols:
                    await cursor.execute(f'SELECT NVL(MAX("{column}"), 0) FROM "{table}"')
                    maximum = int((await cursor.fetchone())[0])

                    await cursor.execute("SELECT last_number FROM user_sequences WHERE sequence_name=:sequence", sequence=sequence)
                    sequence_row = await cursor.fetchone()
                    cached_next = int(sequence_row[0]) if sequence_row else None
                    item = {"table": table, "column": column, "sequence": sequence, "max_id": maximum, "dictionary_next": cached_next}

                    if not apply:
                        item["action"] = "audit_only"
                        results.append(item)
                        continue

                    advances = 0
                    while advances <= 100000:
                        await cursor.execute(f'SELECT "{sequence}".NEXTVAL FROM dual')
                        actual = int((await cursor.fetchone())[0])
                        advances += 1
                        if actual > maximum:
                            item.update({"action": "advanced", "actual_next": actual, "advances": advances})
                            break
                    else:
                        raise RuntimeError(f"Refusing to advance {sequence} more than 100000 values")
                    results.append(item)
    finally:
        await close_db_pool()

    unresolved = [item for item in results if item.get("action") == "unresolved"]
    print(json.dumps({"ok": not unresolved, "applied": apply, "results": results}, indent=2))
    if unresolved:
        raise SystemExit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Advance each identity sequence beyond the table maximum")
    args = parser.parse_args()
    asyncio.run(main(args.apply))
