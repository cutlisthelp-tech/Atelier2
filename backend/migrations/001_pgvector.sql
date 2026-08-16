-- Phase 8 vector index (docs/BUILD_PLAN.md §6: pgvector until scale says
-- otherwise). Apply with: psql "$DATABASE_URL" -f 001_pgvector.sql

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS garment_embeddings (
    id        text PRIMARY KEY,
    embedding vector(512) NOT NULL,
    meta      jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Cosine distance index; lists kept small while the corpus is personal-scale.
CREATE INDEX IF NOT EXISTS garment_embeddings_cos
    ON garment_embeddings
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
