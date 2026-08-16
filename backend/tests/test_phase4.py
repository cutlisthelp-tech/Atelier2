"""Phase 4 tests — virtual try-on honesty contract.

Real fixture photos drive every pipeline stage (pose, garment analysis,
fashionCLIP confidence). The hosted provider itself is the only external
dependency; where the contract demands provider behavior, a local HTTP stub
plays the role of the FASHN API (a test double for the vendor, never a fake
result — every number in the response is computed from real images).
"""

import base64
import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.errors import AtelierError, FailureState
from app.main import app
from app.services import vton_service

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


def _fixture(name: str) -> bytes:
    return (FIXTURES / name).read_bytes()


PERSON = "body_person.jpg"
GARMENT = "garment_checkered.jpg"


def _post(client, person: bytes, garment: bytes):
    return client.post(
        "/tryon/render",
        files={
            "person": ("person.jpg", person, "image/jpeg"),
            "garment": ("garment.jpg", garment, "image/jpeg"),
        },
    )


# -- Input honesty ---------------------------------------------------------------

def test_landscape_person_is_no_person(client, monkeypatch):
    monkeypatch.delenv("FASHN_API_KEY", raising=False)
    resp = _post(client, _fixture("landscape.jpg"), _fixture(GARMENT))
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "NO_PERSON"


def test_garbage_person_is_poor_image(client, monkeypatch):
    monkeypatch.delenv("FASHN_API_KEY", raising=False)
    resp = _post(client, b"not-an-image-at-all", _fixture(GARMENT))
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "POOR_IMAGE"


def test_unidentifiable_garment_is_insufficient_data(client, monkeypatch):
    monkeypatch.delenv("FASHN_API_KEY", raising=False)
    resp = _post(client, _fixture(PERSON), _fixture("garment_hanger.jpg"))
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INSUFFICIENT_DATA"


def test_accessory_categories_are_unsupported():
    for category in ("bag", "hat", "scarf", "belt"):
        with pytest.raises(AtelierError) as exc:
            vton_service.assert_supported_category(category)
        assert exc.value.state == FailureState.VTON_UNSUPPORTED_GARMENT
    with pytest.raises(AtelierError) as exc:
        vton_service.assert_supported_category(None)
    assert exc.value.state == FailureState.INSUFFICIENT_DATA
    # Clothing and shoes pass.
    for category in ("sweater", "jeans", "sneakers", "dress"):
        vton_service.assert_supported_category(category)


def test_no_key_is_honest_model_missing(client, monkeypatch):
    monkeypatch.delenv("FASHN_API_KEY", raising=False)
    resp = _post(client, _fixture(PERSON), _fixture(GARMENT))
    assert resp.status_code == 503
    body = resp.json()
    assert body["error"]["code"] == "MODEL_MISSING"
    assert "FASHN_API_KEY" in body["error"]["message"]


def test_health_reports_vton_state(client, monkeypatch):
    monkeypatch.delenv("FASHN_API_KEY", raising=False)
    vton = client.get("/health").json()["vton"]
    assert vton == {"provider": "fashn", "configured": False}
    monkeypatch.setenv("FASHN_API_KEY", "test-key")
    assert client.get("/health").json()["vton"]["configured"] is True


# -- Provider contract (local stub stands in for the FASHN API) --------------------

def _start_stub(mode: str, payload: bytes | None = None) -> HTTPServer:
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):  # keep test output clean
            pass

        def _json(self, code: int, doc: dict):
            data = json.dumps(doc).encode()
            self.send_response(code)
            self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_POST(self):
            if self.path != "/v1/run":
                self._json(404, {"error": "NotFound"})
                return
            if mode == "rate_limited":
                self._json(429, {"error": "RateLimitExceeded"})
            elif mode == "unauthorized":
                self._json(401, {"error": "UnauthorizedAccess"})
            else:
                self._json(200, {"id": "job-1", "error": None})

        def do_GET(self):
            if not self.path.startswith("/v1/status/"):
                self._json(404, {"error": "NotFound"})
                return
            uri = "data:image/jpeg;base64," + base64.b64encode(payload).decode()
            self._json(
                200, {"id": "job-1", "status": "completed", "output": [uri], "error": None}
            )

    server = HTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


@pytest.fixture()
def stub_env(monkeypatch):
    """Point the adapter at a local stub with a test key."""
    servers: list[HTTPServer] = []

    def _start(mode: str, payload: bytes | None = None) -> None:
        server = _start_stub(mode, payload)
        servers.append(server)
        monkeypatch.setenv("FASHN_API_KEY", "test-key")
        monkeypatch.setenv("FASHN_BASE_URL", f"http://127.0.0.1:{server.server_port}")

    yield _start
    for server in servers:
        server.shutdown()


def test_render_returns_labeled_real_confidence(client, stub_env):
    # The stub "renders" the garment photo itself: similarity must be ~1.
    stub_env("completed", _fixture(GARMENT))
    resp = _post(client, _fixture(PERSON), _fixture(GARMENT))
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["render"]["method"] == "image_based_vton"
    assert body["render"]["provider"] == "fashn"
    assert body["render"]["mime"] == "image/jpeg"
    image = base64.b64decode(body["render"]["image"])
    assert image[:3] == b"\xff\xd8\xff"  # a real JPEG
    assert body["garment"]["category"] == "sweater"
    assert body["confidence"] > 0.9
    assert body["flags"] == []


def test_unrelated_render_is_flagged_low_confidence(client, stub_env):
    # A landscape "render" shares nothing with the sweater → honest flag.
    stub_env("completed", _fixture("landscape.jpg"))
    resp = _post(client, _fixture(PERSON), _fixture(GARMENT))
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["confidence"] < vton_service.CONFIDENCE_FLOOR
    assert "LOW_CONFIDENCE" in body["flags"]


def test_render_confidence_is_deterministic(client, stub_env):
    stub_env("completed", _fixture(GARMENT))
    first = _post(client, _fixture(PERSON), _fixture(GARMENT)).json()["confidence"]
    second = _post(client, _fixture(PERSON), _fixture(GARMENT)).json()["confidence"]
    assert first == second


def test_provider_throttle_is_rate_limited(client, stub_env):
    stub_env("rate_limited")
    resp = _post(client, _fixture(PERSON), _fixture(GARMENT))
    assert resp.status_code == 503
    assert resp.json()["error"]["code"] == "RATE_LIMITED"


def test_rejected_key_is_model_missing(client, stub_env):
    stub_env("unauthorized")
    resp = _post(client, _fixture(PERSON), _fixture(GARMENT))
    assert resp.status_code == 503
    assert resp.json()["error"]["code"] == "MODEL_MISSING"
