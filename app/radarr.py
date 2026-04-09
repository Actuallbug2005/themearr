import os
import httpx

RADARR_URL = os.getenv("RADARR_URL", "http://localhost:7878")
RADARR_API_KEY = os.getenv("RADARR_API_KEY", "")


async def fetch_movies() -> list[dict]:
    url = f"{RADARR_URL.rstrip('/')}/api/v3/movie"
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(url, params={"apikey": RADARR_API_KEY})
        resp.raise_for_status()
        data = resp.json()

    result = []
    for m in data:
        folder = m.get("path") or m.get("folderName") or ""
        result.append(
            {
                "id": m["id"],
                "title": m["title"],
                "year": m.get("year"),
                "folderName": folder,
            }
        )
    return result
