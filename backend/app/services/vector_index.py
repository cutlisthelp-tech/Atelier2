"""Vector index layer — Phase 8 (PRODUCT_SPEC §9, BUILD_PLAN §6).

Two adapters behind one contract:

- ``PgVectorIndex``: the BUILD_PLAN-sanctioned store (pgvector on Postgres),
  activated only when ``DATABASE_URL`` is configured. Schema lives in
  ``backend/migrations/001_pgvector.sql``.
- ``StatelessCosineIndex``: exact cosine over the embeddings carried in the
  request — the same mathematics pgvector's ``<=>`` operator computes — used
  where no Postgres instance exists. Nothing is approximated or invented.
"""

from __future__ import annotations

import numpy as np

NEAREST_SQL = (
    "SELECT id, 1 - (embedding <=> %s::vector) AS sim "
    "FROM garment_embeddings ORDER BY embedding <=> %s::vector LIMIT %s"
)
SEED_SQL = (
    "INSERT INTO garment_embeddings (id, embedding, meta) "
    "VALUES (%s, %s::vector, %s::jsonb) "
    "ON CONFLICT (id) DO UPDATE SET embedding = EXCLUDED.embedding"
)


class StatelessCosineIndex:
    """Exact brute-force cosine; deterministic by construction."""

    name = "stateless"

    def __init__(self, items: list[dict]):
        self._items = items
        vectors = np.asarray(
            [i["embedding"] for i in items], dtype=np.float32
        )
        norms = np.linalg.norm(vectors, axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        self._unit = vectors / norms

    def nearest(self, vector: list[float], limit: int = 10) -> list[tuple[str, float]]:
        q = np.asarray(vector, dtype=np.float32)
        norm = float(np.linalg.norm(q))
        if norm == 0.0:
            return []
        sims = self._unit @ (q / norm)
        order = np.argsort(-sims, kind="stable")
        out = []
        for idx in order[:limit]:
            out.append((self._items[int(idx)]["id"], float(sims[idx])))
        return out


class PgVectorIndex:
    """pgvector adapter; the driver is imported lazily so environments
    without psycopg (or without any Postgres) never pay for it."""

    name = "pgvector"

    def __init__(self, database_url: str):
        self._url = database_url
        self._conn = None

    def _connect(self):
        if self._conn is None:
            try:
                import psycopg  # noqa: PLC0415 — optional until configured
            except ImportError as exc:
                raise RuntimeError(
                    "DATABASE_URL is set but the psycopg driver is not "
                    "installed (pip install 'psycopg[binary]')."
                ) from exc
            self._conn = psycopg.connect(self._url)
        return self._conn

    def seed(self, items: list[dict]) -> None:
        import json  # noqa: PLC0415

        conn = self._connect()
        with conn.cursor() as cur:
            for item in items:
                vector = "[" + ",".join(str(float(x)) for x in item["embedding"]) + "]"
                cur.execute(
                    SEED_SQL,
                    (item["id"], vector, json.dumps(item.get("meta", {}))),
                )
        conn.commit()

    def nearest(self, vector: list[float], limit: int = 10) -> list[tuple[str, float]]:
        conn = self._connect()
        param = "[" + ",".join(str(float(x)) for x in vector) + "]"
        with conn.cursor() as cur:
            cur.execute(NEAREST_SQL, (param, param, limit))
            return [(row[0], float(row[1])) for row in cur.fetchall()]
