# API

Base: FastAPI app (`backend/app/main.py`). Version 0.0.0 (Phase 0).

## `GET /health`

Liveness with real values.

```json
{ "status": "ok", "service": "atelier-backend", "version": "0.0.0", "uptime_seconds": 12.345 }
```

## `GET /config/feature-flags`

Current feature flags. All default `false` (docs/BUILD_PLAN.md §1); override
with environment variables.

```json
{ "feature_flags": { "FEATURE_AUTH": false, "FEATURE_SUBSCRIPTIONS": false, "FEATURE_CLOUD_SYNC": false, "FEATURE_SHOPPING": false } }
```

## Error envelope

Domain errors (as phases add endpoints) always use the `docs/PRODUCT_SPEC.md §12`
taxonomy:

```json
{ "error": { "code": "CATALOG_NOT_CONNECTED", "message": "No catalog provider is connected." } }
```

No other endpoints exist yet. Each phase documents its own here as it lands.
