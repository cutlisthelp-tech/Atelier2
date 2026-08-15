from fastapi.testclient import TestClient

from app.main import create_app

client = TestClient(create_app())


def test_health_returns_real_status() -> None:
    resp = client.get("/health")
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ok"
    assert body["service"] == "atelier-backend"
    assert isinstance(body["uptime_seconds"], (int, float))
    assert body["uptime_seconds"] >= 0


def test_feature_flags_all_default_false() -> None:
    resp = client.get("/config/feature-flags")
    assert resp.status_code == 200
    flags = resp.json()["feature_flags"]
    assert flags == {
        "FEATURE_AUTH": False,
        "FEATURE_SUBSCRIPTIONS": False,
        "FEATURE_CLOUD_SYNC": False,
        "FEATURE_SHOPPING": False,
    }


def test_failure_taxonomy_covers_product_spec_section_12() -> None:
    from app.errors import FailureState

    expected = {
        "NO_PERSON", "MULTIPLE_PEOPLE", "POOR_IMAGE", "INSUFFICIENT_DATA",
        "LOW_CONFIDENCE", "MODEL_MISSING", "MODEL_FAILED", "GPU_MEMORY_ERROR",
        "RATE_LIMITED", "NO_SIZE_CHART", "VTON_UNSUPPORTED_GARMENT",
        "PRODUCT_UNAVAILABLE", "CATALOG_NOT_CONNECTED", "STALE_CATALOG_DATA",
        "WEATHER_UNAVAILABLE", "NETWORK_ERROR",
    }
    assert {s.value for s in FailureState} == expected


def test_error_envelope_shape() -> None:
    from app.errors import FailureState, error_envelope

    env = error_envelope(FailureState.CATALOG_NOT_CONNECTED, "No catalog provider is connected.")
    assert env == {"error": {"code": "CATALOG_NOT_CONNECTED", "message": "No catalog provider is connected."}}
