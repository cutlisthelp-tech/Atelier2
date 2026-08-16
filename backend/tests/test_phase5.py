"""Phase 5 tests — the Size Engine runs on real measurements only.

The body profile comes from a real /analysis/body run on a fixture photo;
the size chart is user-shaped input (centimetre rows), the same kind of data
a person copies from a real product page. Expected values are derived from
the real returned measurements, never invented.
"""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


@pytest.fixture(scope="module")
def body_person(client):
    resp = client.post(
        "/analysis/body",
        files={"file": ("p.jpg", (FIXTURES / "body_person.jpg").read_bytes(), "image/jpeg")},
        data={"height_cm": "175"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


@pytest.fixture(scope="module")
def body_yoga(client):
    resp = client.post(
        "/analysis/body",
        files={"file": ("y.jpg", (FIXTURES / "body_yoga.jpg").read_bytes(), "image/jpeg")},
        data={"height_cm": "170"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def _chart(sh: float, arm: float) -> dict:
    """Three real-shaped sizes; M sits exactly at measured + regular ease."""
    return {
        "brand": "test-brand",
        "rows": [
            {"label": "S", "chest_cm": 88.0, "shoulder_cm": sh, "sleeve_cm": arm},
            {"label": "M", "chest_cm": 92.0, "shoulder_cm": sh + 2.0, "sleeve_cm": arm + 2.0},
            {"label": "L", "chest_cm": 96.0, "shoulder_cm": sh + 6.0, "sleeve_cm": arm + 6.0},
        ],
    }


def _post(client, body: dict, chart: dict, category="shirt", fit="regular"):
    return client.post(
        "/size/recommend",
        json={
            "category": category,
            "fit_type": fit,
            "body_profile": body,
            "size_chart": chart,
        },
    )


def test_real_chart_returns_real_size_and_confidence(client, body_person):
    m = body_person["body"]["measurements_cm"]
    resp = _post(client, body_person, _chart(m["shoulder"], m["arm"]))
    assert resp.status_code == 200, resp.text
    body = resp.json()
    # M matches shoulder+sleeve exactly (delta 0 → 1.0 each); chest is in the
    # chart but not measurable → coverage 2/3 → 0.7*1 + 0.3*(2/3) = 0.9.
    assert body["recommended"]["label"] == "M"
    assert body["recommended"]["score"] == 1.0
    assert body["confidence"] == 0.9
    assert body["flags"] == []
    assert body["fit_type"] == "regular"
    assert body["brand"] == "test-brand"
    assert [s["label"] for s in body["sizes"]] == ["S", "M", "L"]
    assert body["sizes"][1]["score"] == 1.0
    assert body["sizes"][0]["score"] < body["sizes"][1]["score"]

    regions = {r["region"]: r for r in body["regions"]}
    assert regions["chest"]["measured_cm"] is None
    assert regions["chest"]["status"] == "not_measurable"
    assert regions["chest"]["chart_cm"] == 92.0
    assert regions["shoulder"]["status"] == "matched"
    assert regions["shoulder"]["measured_cm"] == m["shoulder"]
    assert regions["sleeve"]["delta_cm"] == 0.0
    assert "chest" in body["note"]


def test_deterministic_double_call(client, body_person):
    m = body_person["body"]["measurements_cm"]
    first = _post(client, body_person, _chart(m["shoulder"], m["arm"])).json()
    second = _post(client, body_person, _chart(m["shoulder"], m["arm"])).json()
    assert first == second


def test_personalization_two_real_bodies_differ(client, body_person, body_yoga):
    m = body_person["body"]["measurements_cm"]
    chart = _chart(m["shoulder"], m["arm"])
    a = _post(client, body_person, chart).json()
    b = _post(client, body_yoga, chart).json()
    assert a["sizes"] != b["sizes"], "the same chart must not score identically for two real bodies"


def test_fit_type_moves_the_match(client, body_person):
    m = body_person["body"]["measurements_cm"]
    regular = _post(client, body_person, _chart(m["shoulder"], m["arm"]), fit="regular").json()
    oversized = _post(client, body_person, _chart(m["shoulder"], m["arm"]), fit="oversized").json()
    assert regular["sizes"] != oversized["sizes"]


def test_chest_waist_only_chart_is_insufficient_data(client, body_person):
    chart = {
        "rows": [
            {"label": "S", "chest_cm": 88.0, "waist_cm": 70.0},
            {"label": "M", "chest_cm": 92.0, "waist_cm": 74.0},
        ],
    }
    resp = _post(client, body_person, chart, category="dress")
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INSUFFICIENT_DATA"


def test_single_row_chart_is_no_size_chart(client, body_person):
    resp = _post(client, body_person, {"rows": [{"label": "M", "shoulder_cm": 45.0}]})
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "NO_SIZE_CHART"


def test_empty_chart_is_no_size_chart(client, body_person):
    resp = _post(client, body_person, {"rows": []})
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "NO_SIZE_CHART"


def test_shoes_are_honestly_unsizable(client, body_person):
    chart = _chart(44.0, 60.0)
    resp = _post(client, body_person, chart, category="sneakers")
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INSUFFICIENT_DATA"


def test_unknown_category_rejected(client, body_person):
    resp = _post(client, body_person, _chart(44.0, 60.0), category="spacesuit")
    assert resp.status_code == 422
