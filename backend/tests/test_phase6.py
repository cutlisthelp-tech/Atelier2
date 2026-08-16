"""Phase 6 tests — context depth: ranking measurably shifts when the
occasion or the weather changes (BUILD_PLAN §3 applied to context).

Weather comes from a local stub of the Open-Meteo contract (same pattern as
the Phase 4 provider stub): controlled HOT/COLD/MILD/RAINY states, while every
score is still computed from real fixture analyses. Wardrobes are chosen so
the context signal is the decider — never padded, never faked.
"""

import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import occasion_service as occ
from app.services import ranking_service

FIXTURES = Path(__file__).parent / "fixtures"

WEATHER_STATES = {
    "hot": {"temperature_2m": 35.0, "precipitation": 0.0, "weather_code": 0, "wind_speed_10m": 5.0},
    "cold": {"temperature_2m": 5.0, "precipitation": 0.0, "weather_code": 1, "wind_speed_10m": 5.0},
    "mild": {"temperature_2m": 21.0, "precipitation": 0.0, "weather_code": 2, "wind_speed_10m": 5.0},
    "rainy": {"temperature_2m": 12.0, "precipitation": 4.0, "weather_code": 61, "wind_speed_10m": 20.0},
}


def _start_weather(mode: str) -> HTTPServer:
    current = WEATHER_STATES[mode]

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def do_GET(self):
            doc = {"current": dict(current, time="2026-08-16T12:00")}
            data = json.dumps(doc).encode()
            self.send_response(200)
            self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

    server = HTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


@pytest.fixture()
def weather(monkeypatch):
    servers: list[HTTPServer] = []

    def _set(mode: str) -> None:
        server = _start_weather(mode)
        servers.append(server)
        monkeypatch.setenv("WEATHER_BASE_URL", f"http://127.0.0.1:{server.server_port}")

    yield _set
    for server in servers:
        server.shutdown()


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


def _garment(client, fname: str) -> dict:
    resp = client.post(
        "/analysis/garment",
        files={"file": (fname, (FIXTURES / fname).read_bytes(), "image/jpeg")},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    garment = body["garment"]
    garment.pop("embedding", None)
    garment.pop("clothing_mask_share", None)
    return {"id": fname, "garment": garment, "confidence": body["confidence"], "flags": body["flags"]}


@pytest.fixture(scope="module")
def profiles(client):
    body = client.post(
        "/analysis/body",
        files={"file": ("p.jpg", (FIXTURES / "body_person.jpg").read_bytes(), "image/jpeg")},
        data={"height_cm": "178"},
    ).json()
    analyzed = {
        "sweater": _garment(client, "garment_checkered.jpg"),
        "jeans": _garment(client, "garment_jeans.jpg"),
        "sneakers": _garment(client, "garment_sneakers.jpg"),
        "tshirt": _garment(client, "garment_tshirt.jpg"),
        "shorts": _garment(client, "garment_shorts.jpg"),
    }
    return {"body": body, "wardrobe": analyzed}


STYLE = {
    "fit_preference": "oversized",
    "aesthetics": [],
    "banned_colors": [],
    "banned_brands": [],
    "budget_ceiling": None,
}

LOCATION = {"latitude": 33.5731, "longitude": -7.5898, "label": "Casablanca"}


def _request(profiles, occasion: str, ids: list[str]) -> dict:
    return {
        "occasion": occasion,
        "location": dict(LOCATION),
        "body_profile": profiles["body"],
        "color_profile": None,
        "style_profile": STYLE,
        "wardrobe": [profiles["wardrobe"][i] for i in ids],
    }


def _factor(resp, name):
    return next(f for f in resp["factors"] if f["name"] == name)


def _best_ids(resp):
    return sorted(g["id"] for g in resp["outfits"][0]["garments"])


# -- Weather depth ---------------------------------------------------------------

def test_weather_shifts_the_ranking(client, profiles, weather):
    """Same wardrobe, same occasion: HOT ranks the summer pair first,
    COLD ranks the warm pair first — a measurable, weather-driven flip."""
    ids = ["sweater", "jeans", "shorts", "sneakers"]

    weather("hot")
    hot = client.post("/recommend/outfit", json=_request(profiles, "casual lunch", ids))
    assert hot.status_code == 200, hot.text
    hot = hot.json()

    weather("cold")
    cold = client.post("/recommend/outfit", json=_request(profiles, "casual lunch", ids))
    assert cold.status_code == 200, cold.text
    cold = cold.json()

    assert _best_ids(hot) != _best_ids(cold)
    assert "garment_shorts.jpg" in _best_ids(hot)
    assert "garment_jeans.jpg" in _best_ids(cold)

    # The shift is driven by the Weather factor, visibly.
    w_hot = _factor(hot, "weather")
    w_cold = _factor(cold, "weather")
    assert w_hot["score"] != w_cold["score"]


def test_severity_scales_the_weather_weight(client, profiles, weather):
    ids = ["sweater", "jeans", "shorts", "sneakers"]

    weather("mild")
    mild = client.post("/recommend/outfit", json=_request(profiles, "casual lunch", ids)).json()
    weather("cold")
    cold = client.post("/recommend/outfit", json=_request(profiles, "casual lunch", ids)).json()
    weather("rainy")
    rainy = client.post("/recommend/outfit", json=_request(profiles, "casual lunch", ids)).json()

    w_mild = _factor(mild, "weather")
    w_cold = _factor(cold, "weather")
    w_rainy = _factor(rainy, "weather")
    assert w_cold["effective_weight"] > w_mild["effective_weight"]
    assert w_rainy["effective_weight"] > w_mild["effective_weight"]
    assert w_cold["base_weight"] == w_mild["base_weight"] == 6.0

    for resp in (mild, cold, rainy):
        active = [f for f in resp["factors"] if f["active"]]
        assert abs(sum(f["effective_weight"] for f in active) - 100.0) <= 0.4


def test_context_determinism(client, profiles, weather):
    ids = ["sweater", "jeans", "shorts", "sneakers"]
    weather("cold")
    first = client.post("/recommend/outfit", json=_request(profiles, "casual lunch", ids)).json()
    second = client.post("/recommend/outfit", json=_request(profiles, "casual lunch", ids)).json()
    assert first == second


# -- Occasion depth ----------------------------------------------------------------

def test_occasion_shifts_the_ranking(client, profiles, weather):
    """Dinner ranks the warm smart pair first; gym ranks the sporty pair
    first — the occasion table (now with formality depth) is the decider."""
    ids = ["sweater", "jeans", "tshirt", "shorts", "sneakers"]
    weather("mild")

    dinner = client.post("/recommend/outfit", json=_request(profiles, "dinner", ids))
    assert dinner.status_code == 200, dinner.text
    dinner = dinner.json()
    gym = client.post("/recommend/outfit", json=_request(profiles, "gym", ids))
    assert gym.status_code == 200, gym.text
    gym = gym.json()

    assert _best_ids(dinner) != _best_ids(gym)
    assert "garment_checkered.jpg" in _best_ids(dinner)
    assert "garment_tshirt.jpg" in _best_ids(gym)

    o_dinner = _factor(dinner, "occasion")
    o_gym = _factor(gym, "occasion")
    assert o_dinner["score"] != o_gym["score"]

    # Honesty contract (§6): every why-line traces a real factor that
    # cleared the 4.0 contribution threshold.
    traces = {
        "Right for": "occasion",
        "Fit tracks": "body_fit",
        "Silhouette": "proportion",
        "Matches your stated": "style",
        "Colors hold": "color_harmony",
        "palette": "appearance",
        "Suited to": "weather",
    }
    for resp in (dinner, gym):
        for line in resp["outfits"][0]["why"]:
            for prefix, name in traces.items():
                if prefix in line:
                    assert _factor(resp, name)["contribution"] >= 4.0


def test_formality_tables_are_complete_and_ordered():
    assert set(occ.OCCASION_FORMALITY) == set(occ.OCCASIONS)
    assert all(0.0 <= v <= 1.0 for v in occ.OCCASION_FORMALITY.values())
    # Loud patterns clash with formal reads, not with the gym.
    assert occ.formality_piece("formal", "graphic", "oversized") < 0.6
    assert occ.formality_piece("gym", "graphic", "oversized") >= 0.9
    assert occ.formality_piece("formal", "solid", "regular") == 1.0


def test_severity_rule_is_documented_and_bounded():
    assert occ.weather_severity({"state": "ok", "temperature_c": 21.0, "precipitation_mm": 0.0}) == 0.0
    assert occ.weather_severity({"state": "ok", "temperature_c": 36.0, "precipitation_mm": 0.0}) == 1.0
    assert occ.weather_severity({"state": "ok", "temperature_c": 5.0, "precipitation_mm": 0.0}) > 0.9
    assert occ.weather_severity({"state": "WEATHER_UNAVAILABLE"}) == 0.0
    weights = ranking_service.context_weights(
        {"state": "ok", "temperature_c": 5.0, "precipitation_mm": 0.0}
    )
    assert weights["weather"] == pytest.approx(12.0)
