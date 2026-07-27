"""Inspect or update the Android release advertised by the LMS API."""

import argparse
import asyncio
import json

import app.core.database as database
from app.core.database import close_db_pool, init_db_pool


KEYS = (
    "latest_android_version",
    "min_android_version",
    "apk_download_url",
)


async def read_settings() -> dict[str, str | None]:
    async with database._pool.acquire() as connection:
        async with connection.cursor() as cursor:
            await cursor.execute(
                """
                SELECT setting_key, setting_value
                FROM system_settings
                WHERE setting_key IN (
                    'latest_android_version',
                    'min_android_version',
                    'apk_download_url'
                )
                """
            )
            values = {str(row[0]): row[1] for row in await cursor.fetchall()}
    return {key: values.get(key) for key in KEYS}


async def run(version: str, minimum: str, url: str, apply: bool) -> dict:
    await init_db_pool()
    try:
        before = await read_settings()
        requested = {
            "latest_android_version": version,
            "min_android_version": minimum,
            "apk_download_url": url,
        }

        if apply:
            async with database._pool.acquire() as connection:
                async with connection.cursor() as cursor:
                    for key, value in requested.items():
                        await cursor.execute(
                            """
                            MERGE INTO system_settings target
                            USING (
                                SELECT :key AS setting_key, :value AS setting_value
                                FROM dual
                            ) source
                            ON (target.setting_key = source.setting_key)
                            WHEN MATCHED THEN
                                UPDATE SET target.setting_value = source.setting_value
                            WHEN NOT MATCHED THEN
                                INSERT (setting_key, setting_value)
                                VALUES (source.setting_key, source.setting_value)
                            """,
                            key=key,
                            value=value,
                        )
                    await connection.commit()

        after = await read_settings()
        return {
            "ok": after == requested if apply else True,
            "applied": apply,
            "before": before,
            "requested": requested,
            "after": after,
        }
    finally:
        await close_db_pool()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--minimum", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--apply", action="store_true")
    arguments = parser.parse_args()

    result = asyncio.run(
        run(
            version=arguments.version,
            minimum=arguments.minimum,
            url=arguments.url,
            apply=arguments.apply,
        )
    )
    print(json.dumps(result, indent=2))
    if not result["ok"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
