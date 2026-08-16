"""Phase 8 tests — Find-This-Look: a screenshot returns real tiered matches
against the real wardrobe index, or "no match found".

Every embedding here comes from the real fashionCLIP pipeline on real
fixture photos; tiers are the documented similarity bands, never invented.
"""

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import search_service
from app.services.vector_index import NEAREST_SQL, SEED_SQL, PgVectorIndex

FIXTURES = Path(__file__).parent / "fixtures"

FIVE = ["garment_checkered.jpg", "garment_jeans.jpg", "garment_sneakers.jpg",
        "garment_tshirt.jpg", "garment_shorts.jpg"]


@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c


@pytest.fixture(scope="module")
def index_items(client):
    items = []
    for fname in FIVE:
        resp = client.post(
            "/analysis/garment",
            files={"file": (fname, (FIXTURES / fname).read_bytes(), "image/jpeg")},
        )
        assert resp.status_code == 200, resp.text
        garment = resp.json()["garment"]
        items.append({"id": fname, "embedding": garment["embedding"]})
    return items


def _post(client, query: bytes, items):
    import json

    return client.post(
        "/search/similar",
        files={"file": ("q.jpg", query, "image/jpeg")},
        data={"candidates": json.dumps(items)},
    )


def test_self_match_is_exact_and_first(client, index_items):
    resp = _post(client, (FIXTURES / "garment_checkered.jpg").read_bytes(), index_items)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["state"] == "ok"
    assert body["index"] == "stateless"
    assert body["method"] == "fashionclip_cosine"

    top = body["matches"][0]
    assert top["id"] == "garment_checkered.jpg"
    assert top["similarity"] == 1.0
    assert top["tier"] == "exact_match"

    sims = [m["similarity"] for m in body["matches"]]
    assert sims == sorted(sims, reverse=True)
    for match in body["matches"]:
        assert match["tier"] == search_service.tier_for(match["similarity"])

    # Merchant tiers stay honestly unconnected.
    assert body["catalog"]["same_product_other_merchant"] == "CATALOG_NOT_CONNECTED"
    assert body["catalog"]["budget_alternative"] == "CATALOG_NOT_CONNECTED"


def test_landscape_is_no_match_found(client, index_items):
    resp = _post(client, (FIXTURES / "landscape.jpg").read_bytes(), index_items)
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["state"] == "NO_MATCH_FOUND"
    assert body["matches"] == []
    assert "No match found" in body["message"]


def test_garbage_query_is_poor_image(client, index_items):
    resp = _post(client, b"not-an-image", index_items)
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "POOR_IMAGE"


def test_empty_index_is_insufficient_data(client):
    resp = _post(client, (FIXTURES / "garment_checkered.jpg").read_bytes(), [])
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "INSUFFICIENT_DATA"


def test_malformed_candidates_rejected(client):
    resp = client.post(
        "/search/similar",
        files={"file": ("q.jpg", (FIXTURES / "garment_checkered.jpg").read_bytes(), "image/jpeg")},
        data={"candidates": '[{"id": "x", "embedding": [0.1, 0.2]}]'},
    )
    assert resp.status_code == 422


def test_search_is_deterministic(client, index_items):
    q = (FIXTURES / "garment_jeans.jpg").read_bytes()
    assert _post(client, q, index_items).json() == _post(client, q, index_items).json()


def test_tier_bands_are_documented_and_ordered():
    assert search_service.tier_for(1.0) == "exact_match"
    assert search_service.tier_for(0.92) == "exact_match"
    assert search_service.tier_for(0.91) == "close_match"
    assert search_service.tier_for(0.80) == "close_match"
    assert search_service.tier_for(0.79) == "inspired"
    assert search_service.tier_for(0.68) == "inspired"
    assert search_service.tier_for(0.67) is None


class _StubCursor:
    def __init__(self, rows):
        self._rows = rows
        self.executed = []

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def execute(self, sql, params=None):
        self.executed.append((sql, params))

    def fetchall(self):
        return self._rows


class _StubConn:
    def __init__(self, rows=()):
        self.cursor_obj = _StubCursor(rows)

    def cursor(self):
        return self.cursor_obj

    def commit(self):
        pass


def test_pgvector_adapter_maps_cosine_distance_to_similarity():
    index = PgVectorIndex("postgres://unused")
    index._conn = _StubConn(rows=[("g1", 0.97), ("g2", 0.71)])
    out = index.nearest([0.0] * 512, limit=2)
    assert out == [("g1", 0.97), ("g2", 0.71)]
    sql, params = index._conn.cursor_obj.executed[0]
    assert sql == NEAREST_SQL
    assert params[2] == 2


def test_pgvector_adapter_seeds_with_upsert():
    index = PgVectorIndex("postgres://unused")
    index._conn = _StubConn()
    index.seed([{"id": "g1", "embedding": [0.0] * 512, "meta": {"category": "sweater"}}])
    sql, params = index._conn.cursor_obj.executed[0]
    assert sql == SEED_SQL
    assert params[0] == "g1"
    assert params[1].startswith("[0.0")
