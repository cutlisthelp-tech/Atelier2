# API

Base: FastAPI app (`backend/app/main.py`). Version 0.0.0 (Phase 1).

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

## `POST /analysis/body` — Phase 1

Multipart form: `file` (JPEG/PNG, ≤15 MB, never persisted or logged) and
`height_cm` (100–250). Runs pose landmark detection on backend CPU.

Success `200`:

```json
{
  "body": {
    "measurements_cm": { "height_input": 178.0, "shoulder": 34.3, "hip": 23.3,
      "torso": 56.5, "leg": 96.6, "arm": 47.0, "chest": null, "waist": null },
    "proportions": { "torso_to_leg_ratio": 0.584, "shoulder_to_hip_ratio": 1.472,
      "vertical_balance": 0.369 },
    "body_shape": "inverted_triangle",
    "skeleton": [ { "x": 0.33, "y": 0.17, "visibility": 0.999 } ],
    "visible_landmarks": 27
  },
  "confidence": 0.757,
  "flags": []
}
```

`chest` and `waist` are always `null`: a single 2D capture cannot support
them, and Atelier does not estimate what it cannot measure. `flags` carries
`LOW_CONFIDENCE` when the result is still returned but below the trust floor.

Failures `422` (input-derived): `NO_PERSON`, `MULTIPLE_PEOPLE`, `POOR_IMAGE`,
`INSUFFICIENT_DATA`. Failures `503` (service-side): `MODEL_MISSING`,
`MODEL_FAILED`. Height out of range is a plain `422` validation error.

## `POST /analysis/appearance` — Phase 1

Multipart form: `file` only. Face landmarks → deterministic color analysis.

Success `200`:

```json
{
  "color": {
    "skin_undertone": "warm", "skin_depth": "medium",
    "overall_contrast": "medium", "season": "autumn",
    "palette": [ { "name": "Rust", "hex": "#A44A3F" } ]
  },
  "confidence": 0.984,
  "flags": []
}
```

Failure codes follow the same contract as `/analysis/body`; too few usable
skin samples is `INSUFFICIENT_DATA`.

## `GET /models` — Phase 1

Backend Model Manager status report from `models/registry.yaml`.

```json
{ "models": [ { "name": "pose_landmarker_full", "task": "pose_landmarks",
  "runtime": "mediapipe", "hardware": "cpu", "license": "Apache-2.0",
  "installed": true, "loaded": false } ] }
```

## Error envelope

Domain errors always use the `docs/PRODUCT_SPEC.md §12` taxonomy:

```json
{ "error": { "code": "NO_PERSON", "message": "No person detected. Step back so your full body is in the frame." } }
```
