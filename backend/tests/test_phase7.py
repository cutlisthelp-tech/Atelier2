"""Phase 7 tests — the Wardrobe module's promise: "Best Outfit From My
Closet" returns real ranked outfits from photographed items only, and the
alternatives #2-#4 are real distinct outfits, never padded.

The five-fixture wardrobe assembles four real candidates, so the full
strategy set is exercised against reality for the first time.
"""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app

FIXTURES = Path(__file__).parent / "fixtures"

LOCATION = {"latitude": 33.5731, "longitude": -7.5898, "label": "Casablanca"}

STYLE = {
    "fit_preference": "regular",
    "aesthetics": [],
    "banned_colors": [],
    "banned_brands": [],
    "budget_ceiling": None,
}

FIVE = ["garment_checkered.jpg", "garment_jeans.jpg", "garment_sneakers.jpg",
        "garment_tshirt.jpg", "garment_shorts.jpg"]
THREE = ["garment_checkered.jpg", "garment_jeans.jpg", "garment_sneakers.jpg"]


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
    body_a = client.post(
        "/analysis/body",
        files={"file": ("a.jpg", (FIXTURES / "body_person.jpg").read_bytes(), "image/jpeg")},
        data={"height_cm": "178"},
    ).json()
    body_b = client.post(
        "/analysis/body",
        files={"file": ("b.jpg", (FIXTURES / "body_yoga.jpg").read_bytes(), "image/jpeg")},
        data={"height_cm": "178"},
    ).json()
    color = client.post(
        "/analysis/appearance",
        files={"file": ("f.jpg", (FIXTURES / "face_portrait.jpg").read_bytes(), "image/jpeg")},
    ).json()
    wardrobe = {f: _garment(client, f) for f in FIVE + ["garment_hanger.jpg"]}
    return {"body_a": body_a, "body_b": body_b, "color": color, "wardrobe": wardrobe}


def _request(profiles, body, names):
    return {
        "occasion": "casual lunch",
        "location": dict(LOCATION),
        "body_profile": body,
        "color_profile": profiles["color"],
        "style_profile": STYLE,
        "wardrobe": [profiles["wardrobe"][n] for n in names],
    }


def test_closet_returns_four_real_alternatives(client, profiles):
    resp = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], FIVE))
    assert resp.status_code == 200, resp.text
    outfits = resp.json()["outfits"]

    strategies = [o["strategy"] for o in outfits]
    assert strategies == ["best_match", "safer", "trend_forward", "bold"]

    # #1 is the top score; #2-#4 are curated strategies (safer/trend/bold),
    # not a strict score ranking.
    assert outfits[0]["score"] == max(o["score"] for o in outfits)

    wardrobe_ids = set(FIVE)
    keys = set()
    for outfit in outfits:
        ids = frozenset(g["id"] for g in outfit["garments"])
        assert ids <= wardrobe_ids, "outfits come only from photographed items"
        keys.add(ids)
    assert len(keys) == 4, "four distinct real outfits, no padding"


def test_alternatives_are_deterministic(client, profiles):
    first = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], FIVE)).json()
    second = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], FIVE)).json()
    assert first["outfits"] == second["outfits"]


def test_alternatives_never_padded(client, profiles):
    resp = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], THREE))
    assert resp.status_code == 200, resp.text
    assert [o["strategy"] for o in resp.json()["outfits"]] == ["best_match"]


def test_personalization_closet(client, profiles):
    a = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], FIVE)).json()
    b = client.post("/recommend/outfit", json=_request(profiles, profiles["body_b"], FIVE)).json()
    assert a["outfits"][0]["score"] != b["outfits"][0]["score"]


def test_unplaceable_item_is_reported_not_guessed(client, profiles):
    names = FIVE + ["garment_hanger.jpg"]
    resp = client.post("/recommend/outfit", json=_request(profiles, profiles["body_a"], names))
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert any(u["id"] == "garment_hanger.jpg" for u in body["excluded"]["unplaceable"])
    assert [o["strategy"] for o in body["outfits"]] == [
        "best_match", "safer", "trend_forward", "bold",
    ]
