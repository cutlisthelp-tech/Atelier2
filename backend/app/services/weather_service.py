"""Phase 3 weather context from Open-Meteo (real, keyless).

On any failure the service reports the honest WEATHER_UNAVAILABLE state;
the ranking engine then scores without the Weather factor. A canned
fallback temperature would be fake data and is never produced here.
"""

import os

import httpx

DEFAULT_BASE_URL = "https://api.open-meteo.com"
_TIMEOUT = httpx.Timeout(connect=5.0, read=8.0, write=5.0, pool=5.0)
_ATTEMPTS = 3

# The egress path stalls on cold connects after idle; a shared keep-alive
# client means only the first call pays that cost.
_client: httpx.AsyncClient | None = None


def _get_client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(timeout=_TIMEOUT)
    return _client

# WMO 4677 weather-code labels (Open-Meteo returns these codes verbatim).
WMO_LABELS: dict[int, str] = {
    0: "clear sky",
    1: "mainly clear",
    2: "partly cloudy",
    3: "overcast",
    45: "fog",
    48: "depositing rime fog",
    51: "light drizzle",
    53: "moderate drizzle",
    55: "dense drizzle",
    61: "light rain",
    63: "moderate rain",
    65: "heavy rain",
    71: "light snow",
    73: "moderate snow",
    75: "heavy snow",
    80: "light rain showers",
    81: "moderate rain showers",
    82: "violent rain showers",
    95: "thunderstorm",
    96: "thunderstorm with slight hail",
    99: "thunderstorm with heavy hail",
}


def weather_label(code: int) -> str:
    return WMO_LABELS.get(code, f"wmo code {code}")


async def current_weather(latitude: float, longitude: float) -> dict:
    """Fetch current conditions; on any failure return the honest state."""
    base = os.environ.get("WEATHER_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    url = f"{base}/v1/forecast"
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "current": "temperature_2m,precipitation,weather_code,wind_speed_10m",
    }
    message = ""
    client = _get_client()
    for _ in range(_ATTEMPTS):
        try:
            resp = await client.get(url, params=params)
            if resp.status_code != 200:
                message = f"Open-Meteo answered HTTP {resp.status_code}."
                continue
            body = resp.json()
            current = body["current"]
            temperature = float(current["temperature_2m"])
            precipitation = float(current["precipitation"])
            code = int(current["weather_code"])
            wind = float(current["wind_speed_10m"])
            observed_at = str(current["time"])
            return {
                "state": "ok",
                "temperature_c": round(temperature, 1),
                "precipitation_mm": round(precipitation, 1),
                "weather_code": code,
                "weather_label": weather_label(code),
                "wind_kmh": round(wind, 1),
                "observed_at": observed_at,
            }
        except Exception as exc:  # network, timeout, malformed payload
            message = f"Open-Meteo could not be reached ({type(exc).__name__})."
    return _unavailable(message)


def _unavailable(message: str) -> dict:
    return {"state": "WEATHER_UNAVAILABLE", "message": message}
