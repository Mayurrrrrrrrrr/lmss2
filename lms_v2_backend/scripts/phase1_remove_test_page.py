"""Back up and remove the confirmed test static page from Oracle."""

import argparse
import asyncio
import json
from datetime import datetime, timezone
from pathlib import Path

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool


async def main(page_id: int, apply: bool) -> None:
    await init_db_pool()
    try:
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                await cursor.execute("""
                    SELECT id,url_slug,title,html_content,is_public,created_by,created_at
                    FROM static_pages WHERE id=:page_id
                """, page_id=page_id)
                row = await cursor.fetchone()
                if not row:
                    print(json.dumps({"ok": True, "message": "Page is already absent", "page_id": page_id}))
                    return

                record = {
                    "id": int(row[0]), "url_slug": row[1], "title": row[2],
                    "html_content": str(row[3]) if row[3] else "",
                    "is_public": int(row[4] or 0), "created_by": row[5],
                    "created_at": row[6],
                }
                if str(record["url_slug"]).strip().lower() != "test" or str(record["title"]).strip().lower() != "test":
                    raise SystemExit("Refusing cleanup: page 11 is no longer the confirmed test page")

                if not apply:
                    print(json.dumps({"ok": True, "dry_run": True, "candidate": record}, indent=2, default=str))
                    return

                stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
                backup_path = Path(f"/home/ubuntu/lms-backups/static-page-{page_id}-{stamp}.json")
                backup_path.parent.mkdir(parents=True, exist_ok=True)
                backup_path.write_text(json.dumps(record, indent=2, default=str), encoding="utf-8")

                await cursor.execute("""
                    DELETE FROM static_pages
                    WHERE id=:page_id AND LOWER(url_slug)='test' AND LOWER(title)='test'
                """, page_id=page_id)
                if cursor.rowcount != 1:
                    await connection.rollback()
                    raise SystemExit("Cleanup did not delete exactly one verified test page")
                await connection.commit()

                await cursor.execute("SELECT COUNT(*) FROM static_pages WHERE id=:page_id", page_id=page_id)
                remaining = int((await cursor.fetchone())[0])
                print(json.dumps({
                    "ok": remaining == 0,
                    "deleted_page_id": page_id,
                    "backup": str(backup_path),
                    "remaining": remaining,
                }, indent=2))
                if remaining:
                    raise SystemExit(1)
    finally:
        await close_db_pool()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--page-id", type=int, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    asyncio.run(main(args.page_id, args.apply))
