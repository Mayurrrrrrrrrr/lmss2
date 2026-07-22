"""Read-only audit for administrator impersonation and its RBAC boundary."""

import asyncio
import json
import urllib.error
import urllib.request

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool
from app.core.security import create_access_token


BASE = "http://127.0.0.1:8000/api/v2"


def request(method: str, path: str, token: str) -> tuple[int, dict]:
    req = urllib.request.Request(
        BASE + path,
        method=method,
        data=b"" if method == "POST" else None,
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        try:
            return exc.code, json.loads(body)
        except json.JSONDecodeError:
            return exc.code, {"detail": body}


async def main() -> None:
    await init_db_pool()
    try:
        ids = {}
        async with database._pool.acquire() as connection:
            async with connection.cursor() as cursor:
                for role in ("admin", "trainer", "participant"):
                    await cursor.execute(
                        "SELECT id FROM users WHERE LOWER(role)=:role ORDER BY id FETCH FIRST 1 ROWS ONLY",
                        role=role,
                    )
                    row = await cursor.fetchone()
                    ids[role] = int(row[0]) if row else None
    finally:
        await close_db_pool()

    checks = []
    admin_token = create_access_token({"sub": str(ids["admin"])})
    issued = {}
    for role in ("trainer", "participant"):
        status, body = await asyncio.to_thread(
            request, "POST", f"/auth/impersonate/{ids[role]}", admin_token
        )
        token = body.get("token")
        profile = body.get("user", {})
        ok = status == 200 and token and profile.get("id") == ids[role] and profile.get("role") == role
        checks.append({"name": f"admin_to_{role}", "status": status, "ok": bool(ok)})
        if token:
            issued[role] = token

    for role, token in issued.items():
        status, body = await asyncio.to_thread(request, "GET", "/auth/me", token)
        checks.append({
            "name": f"{role}_token_identity",
            "status": status,
            "ok": status == 200 and body.get("user", {}).get("id") == ids[role],
        })

    status, _ = await asyncio.to_thread(
        request,
        "POST",
        f"/auth/impersonate/{ids['trainer']}",
        issued.get("participant", "invalid"),
    )
    checks.append({"name": "participant_cannot_impersonate", "status": status, "ok": status == 403})

    status, _ = await asyncio.to_thread(
        request, "POST", f"/auth/impersonate/{ids['admin']}", admin_token
    )
    checks.append({"name": "admin_target_rejected", "status": status, "ok": status == 422})

    failed = [check for check in checks if not check["ok"]]
    print(json.dumps({"ok": not failed, "users": ids, "checks": checks, "failed": failed}, indent=2))
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    asyncio.run(main())
