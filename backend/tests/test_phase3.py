"""Phase 3 tests — the BUILD_PLAN §2 One Test and §3 Personalization Test.

Every wardrobe/profile payload here is produced at test time by calling the
real /analysis/* endpoints on real, openly licensed fixture photos. Weather
is fetched live from Open-Meteo in the success path; the failure path points
the client at a genuinely unreachable address (nothing is stubbed).
"""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import occasion_service as occ
from app.services import ranking_service

FIXTURES = Path(__file__).parent / "fixtures"


def _fixture(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


@pytest.fixture(scope="module")
def profiles(client):
    body_a = client.post(
        "/analysis/body",
        files={"file": ("body_person.jpg", _fixture("body_person.jpg"), "image/jpeg")},
        data={"height_cm": "178"},
    ).json()
    body_b = client.post(
        "/analysis/body",
        files={"file": ("body_yoga.jpg", _fixture("body_yoga.jpg"), "image/jpeg")},
        data={"height_cm": "178"},
    ).json()
    color = client.post(
        "/analysis/appearance",
        files={"file": ("face_portrait.jpg", _fixture("face_portrait.jpg"), "image/jpeg")},
    ).json()
    wardrobe = []
    for gid, fname in (
        ("g-sweater", "garment_checkered.jpg"),
        ("g-jeans", "garment_jeans.jpg"),
        ("g-sneakers", "garment_sneakers.jpg"),
        ("g-hanger", "garment_hanger.jpg"),
    ):
        resp = client.post(
            "/analysis/garment",
            files={"file": (fname, _fixture(fname), "image/jpeg")},
        ).json()
        garment = resp["garment"]
        garment.pop("embedding", None)
        garment.pop("clothing_mask_share", None)
        wardrobe.append(
            {"id": gid, "garment": garment, "confidence": resp["confidence"], "flags": resp["flags"]}
        )
    data = {"body_a": body_a, "body_b": body_b, "color": color, "wardrobe": wardrobe}
    # Warm the shared weather client so the tests reuse a live connection
    # instead of paying the cold egress stall.
    client.post("/recommend/outfit", json=_request(data, body_a, STYLE_A))
    return data


LOCATION = {"latitude": 33.5731, "longitude": -7.5898, "label": "Casablanca"}

STYLE_A = {
    "fit_preference": "regular",
    "aesthetics": ["minimal"],
    "banned_colors": [],
    "banned_brands": [],
    "budget_ceiling": None,
}


def _request(profiles, body, style, color=True, wardrobe=None):
    return {
        "occasion": "dinner",
        "location": dict(LOCATION),
        "body_profile": body,
        "color_profile": profiles["color"] if color else None,
        "style_profile": style,
        "wardrobe": wardrobe if wardrobe is not None else profiles["wardrobe"],
    }


def _factor(factors, name):
    return next(f for f in factors if f["name"] == name)


def test_one_test_end_to_end(client, profiles):
    """BUILD_PLAN §2: real photo → analysis → occasion+place → real weather →
    real garments → scored outfits → Best Outfit → real-component explanation."""
    resp = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], STYLE_A))
    assert resp.status_code == 200, resp.text
    body = resp.json()

    weather = body["context"]["weather"]
    assert weather["state"] == "ok"
    assert -60.0 <= weather["temperature_c"] <= 60.0
    assert weather["precipitation_mm"] >= 0.0
    assert isinstance(weather["weather_label"], str) and weather["weather_label"]
    assert "T" in weather["observed_at"]

    assert body["context"]["occasion"] == "dinner"
    assert body["context"]["place_label"] == "Casablanca"

    outfits = body["outfits"]
    assert len(outfits) >= 1
    best = outfits[0]
    assert best["strategy"] == "best_match"
    assert best["score"] > 0
    assert best["why"], "explanation must trace real score components"
    for garment in best["garments"]:
        assert garment["category"] in occ.CATEGORIES
        assert garment["colors"]

    active = [f for f in body["factors"] if f["active"]]
    assert abs(sum(f["effective_weight"] for f in active) - 100.0) <= 0.4
    assert abs(best["score"] - sum(f["contribution"] for f in body["factors"])) <= 0.4

    assert body["shopping"]["state"] == "CATALOG_NOT_CONNECTED"

    # The hanger photo has no identifiable category: reported, never guessed.
    hanger = next(e for e in profiles["wardrobe"] if e["id"] == "g-hanger")
    assert hanger["garment"]["category"]["value"] is None
    assert any(u["id"] == "g-hanger" for u in body["excluded"]["unplaceable"])


def test_personalization_three_real_profiles(client, profiles):
    """BUILD_PLAN §3: same wardrobe/occasion/place, three distinct real
    profiles — scores and the reasons behind them must differ."""
    style_c = dict(STYLE_A, fit_preference="relaxed", aesthetics=["streetwear"])
    ra = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], STYLE_A))
    rb = client.post("/recommend/outfit", json=_request(profiles, profiles["body_b"], STYLE_A))
    rc = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], style_c, color=False))
    assert ra.status_code == 200, ra.text
    assert rb.status_code == 200, rb.text
    assert rc.status_code == 200, rc.text
    resp_a, resp_b, resp_c = ra.json(), rb.json(), rc.json()

    a, b, c = resp_a["outfits"][0]["score"], resp_b["outfits"][0]["score"], resp_c["outfits"][0]["score"]
    assert len({round(a, 1), round(b, 1), round(c, 1)}) == 3

    # A vs B differ on the body-driven proportion factor (real ratios differ).
    prop_a = _factor(resp_a["factors"], "proportion")
    prop_b = _factor(resp_b["factors"], "proportion")
    assert prop_a["contribution"] != prop_b["contribution"]

    # A vs C differ on appearance activity and fit preference.
    app_a = _factor(resp_a["factors"], "appearance")
    app_c = _factor(resp_c["factors"], "appearance")
    assert app_a["active"] is True and app_c["active"] is False
    fit_a = _factor(resp_a["factors"], "body_fit")
    fit_c = _factor(resp_c["factors"], "body_fit")
    assert fit_a["score"] != fit_c["score"]


def test_inactive_factors_and_redistribution(client, profiles):
    resp = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], STYLE_A)).json()
    factors = resp["factors"]
    for name, reason in (
        ("trend", "no trend feed is connected"),
        ("budget", "photographed garments carry no prices"),
        ("user_preference", "no feedback has been recorded yet"),
    ):
        f = _factor(factors, name)
        assert f["active"] is False
        assert f["inactive_reason"] == reason
        assert f["effective_weight"] == 0.0
    active_base = sum(f["base_weight"] for f in factors if f["active"])
    for f in factors:
        if f["active"]:
            expected = f["base_weight"] * 100.0 / active_base
            assert abs(f["effective_weight"] - round(expected, 1)) <= 0.1


def test_hard_filters(client, profiles):
    banned = dict(STYLE_A, banned_colors=["charcoal"])
    kept, excluded, _ = ranking_service.hard_filter(profiles["wardrobe"], banned)
    assert [e["id"] for e in excluded] == ["g-sweater"]
    assert "charcoal" in excluded[0]["reason"]
    assert {e["id"] for e in kept} == {"g-jeans", "g-sneakers", "g-hanger"}

    # With the only top banned, no outfit is assemblable: honest 422.
    resp = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], banned))
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INSUFFICIENT_DATA"


def test_wardrobe_too_small(client, profiles):
    small = [e for e in profiles["wardrobe"] if e["id"] == "g-sweater"]
    resp = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], STYLE_A, wardrobe=small))
    assert resp.status_code == 422
    envelope = resp.json()["error"]
    assert envelope["code"] == "INSUFFICIENT_DATA"
    assert "shoes" in envelope["message"]


def test_weather_unavailable_is_honest(client, profiles, monkeypatch):
    monkeypatch.setenv("WEATHER_BASE_URL", "http://127.0.0.1:9")
    resp = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], STYLE_A))
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["context"]["weather"]["state"] == "WEATHER_UNAVAILABLE"
    assert "temperature_c" not in body["context"]["weather"]
    weather_factor = _factor(body["factors"], "weather")
    assert weather_factor["active"] is False
    assert weather_factor["inactive_reason"] == "WEATHER_UNAVAILABLE"


def test_validation_rejects_bad_input(client, profiles):
    bad_occasion = _request(profiles, profiles["body_a"], STYLE_A)
    bad_occasion["occasion"] = "prom night"
    resp = client.post("/recommend/outfit", json=bad_occasion)
    assert resp.status_code == 422
    assert "error" not in resp.json()

    bad_lat = _request(profiles, profiles["body_a"], STYLE_A)
    bad_lat["location"]["latitude"] = 999.0
    resp = client.post("/recommend/outfit", json=bad_lat)
    assert resp.status_code == 422


def test_alternatives_honest_count_and_determinism(client, profiles):
    resp = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], STYLE_A))
    assert resp.status_code == 200, resp.text
    strategies = [o["strategy"] for o in resp.json()["outfits"]]
    assert strategies == ["best_match"], "one assemblable outfit must not be padded"

    weather = {"state": "ok", "temperature_c": 22.0, "precipitation_mm": 0.0,
               "weather_code": 2, "weather_label": "partly cloudy", "wind_kmh": 5.0,
               "observed_at": "2026-08-15T04:45"}
    entries = [e for e in profiles["wardrobe"] if e["id"] != "g-hanger"]
    candidate = {"key": "k", "ids": tuple(e["id"] for e in entries), "entries": entries}
    first = ranking_service.score_outfit(
        entries, occasion="dinner", body_profile=profiles["body_a"],
        color_profile=profiles["color"], style_profile=STYLE_A, weather=weather,
    )
    second = ranking_service.score_outfit(
        entries, occasion="dinner", body_profile=profiles["body_a"],
        color_profile=profiles["color"], style_profile=STYLE_A, weather=weather,
    )
    assert first == second
    assert ranking_service.select_alternatives([candidate], {"k": first})[0]["strategy"] == "best_match"


def test_table_integrity():
    for occasion in occ.OCCASIONS:
        row = occ.OCCASION_CATEGORY_SUITABILITY[occasion]
        assert set(row) == set(occ.CATEGORIES), occasion
        assert all(v in (0.0, 0.5, 1.0) for v in row.values())
    assert set(occ.MATERIAL_TEMP_BANDS) == {
        "cotton", "denim", "leather", "wool knit", "silk/satin", "linen", "synthetic"
    }
    assert len(occ.FIT_SCALE) == 4
    assert sum(ranking_service.BASE_WEIGHTS.values()) == 100.0
