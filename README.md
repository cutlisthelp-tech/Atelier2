# Atelier

Personal fashion intelligence. A visual app — `HOME · DISCOVER · TRY ON · WARDROBE · PROFILE` — that builds a real Personal Fashion Intelligence Profile per user and answers *"how will this look on this person?"*, never *"is this outfit nice in general?"*

- Mobile client: Flutter (`app/`)
- Backend: FastAPI (`backend/`)
- Model registry: `models/registry.yaml`

The constitution is `AGENTS.md` plus `docs/`. Read those before changing anything.

**No fake data, ever.** No invented products, prices, scores, measurements, or confidence values. When a provider isn't connected, the app shows the honest failure state from `docs/PRODUCT_SPEC.md §12`.

## Status

Phase 0 complete: app boots, every screen shows an honest empty state, zero mock data. See `IMPLEMENTATION_STATUS.md`.

## Develop

See `DEVELOPMENT.md`.
