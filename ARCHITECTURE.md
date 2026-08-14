# Architecture

Per `docs/PRODUCT_SPEC.md §3`:

```
Mobile App (Flutter)  →  API Gateway (FastAPI)  →  Domain Services
  →  Repositories  →  ML / External Providers
```

The UI never talks to a model directly. Every result is typed, carries a
confidence value, or is one of the failure states in `docs/PRODUCT_SPEC.md §12`
(`backend/app/errors.py` is the shared taxonomy).

## What exists today (Phase 0)

- **Flutter shell** — five tabs (HOME · DISCOVER · TRY ON · WARDROBE · PROFILE), honest empty states, semantic design tokens (`app/lib/theme/tokens.dart`), glass reserved for the nav bar.
- **Model Manager skeleton** (`app/lib/services/model_manager.dart`) — Discover + Report stages live; Download/Verify/Install/Load/Cache/Unload arrive with Phase 1's first real model.
- **Model registry** (`models/registry.yaml`) — canonical, intentionally empty.
- **FastAPI skeleton** (`backend/`) — health, feature flags, failure taxonomy. No domain routers: each phase adds its own.
- **No database.** Postgres/pgvector enters only when a phase requires it (visual search, accounts).

## Deliberate boundaries

- Orchestrator LLM (later phases) narrates; it never computes a number.
- Ranking (Phase 3) is a deterministic weighted service, not the LLM.
- VTON (Phase 4) uses a hosted API — no self-hosted GPU.
