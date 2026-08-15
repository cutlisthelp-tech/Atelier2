"""Phase 2 tests — real garment photos, real inference, no mocks.

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


# -- Garment analysis ----------------------------------------------------------

def test_worn_garment_produces_real_attributes(client):
    resp = client.post(
        "/analysis/garment",
        files={"file": ("sweater.jpg", _fixture("garment_checkered.jpg"), "image/jpeg")},
    )
    assert resp.status_code == 200, resp.text
    garment = resp.json()["garment"]
    assert garment["category"]["value"] == "sweater"
    assert garment["category"]["confidence"] > 0.5
    assert garment["colors"], "a worn garment photo must yield real colors"
    for color in garment["colors"]:
        assert color["hex"].startswith("#") and len(color["hex"]) == 7
        assert 0 < color["share"] <= 1
        assert color["name"]
    assert garment["colors_source"] in {"segmentation", "center_weighted"}
    for key in ("pattern", "fit", "material"):
        assert set(garment[key]) == {"value", "confidence"}
    embedding = garment["embedding"]
    assert len(embedding) == 512
    assert all(isinstance(x, float) for x in embedding[:10])
    assert 0 < resp.json()["confidence"] <= 1


def test_hanger_garment_category_is_honestly_unknown(client):
    resp = client.post(
        "/analysis/garment",
        files={"file": ("hanger.jpg", _fixture("garment_hanger.jpg"), "image/jpeg")},
    )
    assert resp.status_code == 200, resp.text
    garment = resp.json()["garment"]
    # A garment is present, but the model is not confident enough to name the
    # category — the honest result is value null with a real confidence.
    assert garment["category"]["value"] is None
    assert 0.35 <= garment["category"]["confidence"] < 0.5
    assert garment["colors"]


def test_landscape_is_insufficient_data(client):
    resp = client.post(
        "/analysis/garment",
        files={"file": ("scene.jpg", _fixture("landscape.jpg"), "image/jpeg")},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INSUFFICIENT_DATA"


def test_dark_garment_is_poor_image(client):
    resp = client.post(
        "/analysis/garment",
        files={"file": ("dark.jpg", _darkened("garment_checkered.jpg"), "image/jpeg")},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "POOR_IMAGE"


def test_garbage_bytes_are_poor_image(client):
    resp = client.post(
        "/analysis/garment",
        files={"file": ("junk.jpg", b"not-an-image-at-all", "image/jpeg")},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "POOR_IMAGE"


# -- Model status ---------------------------------------------------------------

def test_models_endpoint_reports_phase2_models(client):
    resp = client.get("/models")
    assert resp.status_code == 200
    models = {m["name"]: m for m in resp.json()["models"]}
    for name in (
        "fashion_clip_vision_onnx",
        "fashion_clip_text_onnx",
        "fashion_clip_tokenizer",
        "selfie_multiclass_256x256",
    ):
        assert name in models
        assert models[name]["installed"] is True
