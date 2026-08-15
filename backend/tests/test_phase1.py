"""Phase 1 tests — real fixture photos, real inference, no mocks.

Fixtures are CC0/CC-BY photos with provenance (tests/fixtures/provenance.json).
The darkened variant is derived in-memory from a real photo; nothing here is
synthetic data dressed up as a result.
"""

from pathlib import Path

import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.main import app

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


def _fixture(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


def _darkened(name: str, factor: float = 0.12) -> bytes:
    img = cv2.imdecode(np.frombuffer(_fixture(name), np.uint8), cv2.IMREAD_COLOR)
    img = (img * factor).astype(np.uint8)
    return cv2.imencode(".jpg", img)[1].tobytes()


# -- Body analysis -----------------------------------------------------------

def test_body_person_photo_produces_real_profile(client):
    resp = client.post(
        "/analysis/body",
        files={"file": ("person.jpg", _fixture("body_person.jpg"), "image/jpeg")},
        data={"height_cm": 178},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    m = body["body"]["measurements_cm"]
    assert 30 < m["shoulder"] < 65
    assert 20 < m["hip"] < 60
    assert 60 < m["leg"] < 130
    assert 40 < m["arm"] < 90
    assert m["chest"] is None and m["waist"] is None  # honesty guard
    p = body["body"]["proportions"]
    assert 0.5 < p["torso_to_leg_ratio"] < 2.0
    assert 0.7 < p["shoulder_to_hip_ratio"] < 1.6
    assert 0 < p["vertical_balance"] < 1
    assert body["body"]["body_shape"] in {
        "inverted_triangle", "triangle", "rectangle", "insufficient_data",
    }
    assert len(body["body"]["skeleton"]) == 33
    assert all(0 <= lm["visibility"] <= 1 for lm in body["body"]["skeleton"])
    assert 0 < body["confidence"] <= 1
    assert isinstance(body["flags"], list)


def test_body_second_person_photo_also_works(client):
    resp = client.post(
        "/analysis/body",
        files={"file": ("yoga.jpg", _fixture("body_yoga.jpg"), "image/jpeg")},
        data={"height_cm": 170},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["body"]["measurements_cm"]["height_input"] == 170


def test_landscape_is_no_person(client):
    resp = client.post(
        "/analysis/body",
        files={"file": ("scene.jpg", _fixture("landscape.jpg"), "image/jpeg")},
        data={"height_cm": 178},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "NO_PERSON"


def test_dark_photo_is_poor_image(client):
    resp = client.post(
        "/analysis/body",
        files={"file": ("dark.jpg", _darkened("body_person.jpg"), "image/jpeg")},
        data={"height_cm": 178},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "POOR_IMAGE"


def test_garbage_bytes_are_poor_image(client):
    resp = client.post(
        "/analysis/body",
        files={"file": ("junk.jpg", b"not-an-image-at-all", "image/jpeg")},
        data={"height_cm": 178},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "POOR_IMAGE"


def test_height_out_of_range_is_validation_error(client):
    resp = client.post(
        "/analysis/body",
        files={"file": ("person.jpg", _fixture("body_person.jpg"), "image/jpeg")},
        data={"height_cm": 42},
    )
    assert resp.status_code == 422
    assert "error" not in resp.json()  # plain validation, not a §12 state


# -- Appearance analysis -------------------------------------------------------

def test_face_photo_produces_real_color_profile(client):
    resp = client.post(
        "/analysis/appearance",
        files={"file": ("face.jpg", _fixture("face_portrait.jpg"), "image/jpeg")},
    )
    assert resp.status_code == 200, resp.text
    color = resp.json()["color"]
    assert color["skin_undertone"] in {"cool", "warm", "neutral"}
    assert color["skin_depth"] in {"light", "medium", "deep"}
    assert color["overall_contrast"] in {"low", "medium", "high"}
    assert color["season"] in {"winter", "summer", "spring", "autumn"}
    assert color["palette"]
    assert all(swatch["hex"].startswith("#") for swatch in color["palette"])
    body = resp.json()
    assert 0 < body["confidence"] <= 1


def test_landscape_appearance_is_no_person(client):
    resp = client.post(
        "/analysis/appearance",
        files={"file": ("scene.jpg", _fixture("landscape.jpg"), "image/jpeg")},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "NO_PERSON"


def test_dark_face_is_poor_image(client):
    resp = client.post(
        "/analysis/appearance",
        files={"file": ("dark.jpg", _darkened("face_portrait.jpg"), "image/jpeg")},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "POOR_IMAGE"


# -- Model status ---------------------------------------------------------------

def test_models_endpoint_reports_registered_models(client):
    resp = client.get("/models")
    assert resp.status_code == 200
    models = {m["name"]: m for m in resp.json()["models"]}
    assert "pose_landmarker_full" in models
    assert "face_landmarker" in models
    assert models["pose_landmarker_full"]["installed"] is True
    assert models["face_landmarker"]["installed"] is True
