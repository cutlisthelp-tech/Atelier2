# API

Base: FastAPI app (`backend/app/main.py`). Version 0.0.0 (Phase 1 + 2 + 3 + 4).

## `GET /health`

Liveness with real values.

```json
{ "status": "ok", "service": "atelier-backend", "version": "0.0.0", "uptime_seconds": 12.345,
  "vton": { "provider": "fashn", "configured": false } }
```

`vton.configured` reports whether the hosted try-on key (`FASHN_API_KEY`) is
present — the Diagnostics screen surfaces it honestly.

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

## `POST /analysis/garment` — Phase 2

Multipart form: `file` only (≤15 MB, never persisted or logged). Zero-shot
classification with Marqo-fashionCLIP (ONNX int8, CPU) over a fixed taxonomy;
dominant colors from deterministic k-means clustering confined to a MediaPipe
selfie_multiclass clothing mask when someone wears the garment, otherwise a
center-weighted crop (`colors_source` says which).

Success `200`:

```json
{
  "garment": {
    "category": { "value": "sweater", "confidence": 0.818 },
    "colors": [ { "name": "charcoal", "hex": "#2f3234", "share": 0.436 } ],
    "colors_source": "segmentation",
    "clothing_mask_share": 0.3989,
    "pattern": { "value": null, "confidence": 0.31 },
    "fit": { "value": "oversized", "confidence": 0.503 },
    "material": { "value": null, "confidence": 0.29 },
    "embedding": [ 0.012345 ]
  },
  "confidence": 0.846,
  "flags": []
}
```

Honesty contract: `category.value` is `null` when the top category confidence
is below 0.5 (a garment is present but not confidently nameable); each of
`pattern`/`fit`/`material` is `null` below its own 0.35 threshold — never
guessed. Top category below 0.35 means no recognizable garment:
`INSUFFICIENT_DATA`. `embedding` is the 512-dim fashionCLIP vision vector for
later Wardrobe/visual-search reuse; nothing stores it yet.

Color naming is deterministic RGB→name rules (black/white/gray/charcoal/
light gray/brown/beige/red/burgundy/orange/olive/yellow/green/olive green/
teal/navy/light blue/blue/lavender/purple/pink/magenta) on the k-means
centers; `share` is the cluster's share of sampled pixels.

Failures follow the same 422/503 contract as `/analysis/body`.

## `GET /models` — Phase 1

Backend Model Manager status report from `models/registry.yaml`.

```json
{ "models": [ { "name": "pose_landmarker_full", "task": "pose_landmarks",
  "runtime": "mediapipe", "hardware": "cpu", "license": "Apache-2.0",
  "installed": true, "loaded": false } ] }
```

## `POST /recommend/outfit` — Phase 3

JSON body. The backend is stateless: the client sends its real profiles and
its photographed wardrobe verbatim with every request.

Request:

```json
{
  "occasion": "dinner",
  "location": { "latitude": 33.5731, "longitude": -7.5898, "label": "Casablanca" },
  "body_profile": { "…": "/analysis/body response, verbatim" },
  "color_profile": { "…": "/analysis/appearance response, verbatim, or null" },
  "style_profile": {
    "height_cm": 178, "fit_preference": "regular",
    "aesthetics": ["minimal"], "banned_colors": [], "banned_brands": [],
    "budget_ceiling": null
  },
  "wardrobe": [
    { "id": "g-sweater", "garment": { "…": "/analysis/garment `garment` object, embedding stripped" },
      "confidence": 0.846, "flags": [] }
  ]
}
```

`occasion` must be one of the 13 fixed occasions (`casual lunch`,
`university`, `office`, `interview`, `wedding`, `date`, `dinner`, `party`,
`travel`, `beach`, `gym`, `shopping`, `formal`); anything else is a plain
`422` validation error, as is an out-of-range latitude/longitude.

Success `200`:

```json
{
  "context": {
    "occasion": "dinner",
    "place_label": "Casablanca",
    "weather": { "state": "ok", "temperature_c": 22.3, "precipitation_mm": 0.0,
      "weather_code": 2, "weather_label": "partly cloudy", "wind_kmh": 5.0,
      "observed_at": "2026-08-15T04:45" }
  },
  "factors": [
    { "name": "body_fit", "base_weight": 18.0, "effective_weight": 20.0,
      "active": true, "inactive_reason": null, "score": 0.8, "contribution": 16.0 },
    { "name": "trend", "base_weight": 6.0, "effective_weight": 0.0,
      "active": false, "inactive_reason": "no trend feed is connected",
      "score": 0.0, "contribution": 0.0 }
  ],
  "outfits": [
    { "strategy": "best_match", "score": 71.1,
      "garments": [ { "id": "g-sweater", "category": "sweater",
        "colors": [ { "name": "charcoal", "hex": "#2f3234", "share": 0.436 } ],
        "fit": "oversized", "material": null, "pattern": null } ],
      "why": [ "Fit tracks your preference (67% across the pieces)." ] }
  ],
  "excluded": {
    "hard_filters": [ { "id": "g-x", "reason": "banned color: charcoal" } ],
    "unplaceable": [ { "id": "g-hanger", "reason": "category unknown" } ],
    "filters_note": "…"
  },
  "shopping": { "state": "CATALOG_NOT_CONNECTED",
    "message": "No merchant catalog is connected yet…" }
}
```

Transparency rules:

- All **10 ranking factors** (docs/PRODUCT_SPEC.md §6: body_fit 18,
  proportion 14, style 14, color_harmony 12, occasion 10, user_preference 8,
  appearance 8, weather 6, trend 6, budget 4) are reported with base weight,
  effective weight, activity, score and contribution. Trend, Budget and
  User Preference are **inactive by design** in Phase 3 (no trend feed, no
  prices on photographed garments, no feedback log) with those exact reasons;
  effective weights of active factors are redistributed so they always sum
  to 100. `score == Σ contribution`.
- **Weather** comes live from Open-Meteo (see `DATA_SOURCES.md`). If it is
  unreachable the response still succeeds with
  `weather.state = "WEATHER_UNAVAILABLE"` and the weather factor inactive —
  never a canned temperature.
- **Alternatives** (`strategy`: `best_match` / `safer` / `trend_forward` /
  `bold`) are reported only when the wardrobe actually supports them — never
  padded to four.
- Garments with `category.value == null` are excluded as `unplaceable` and
  reported, never guessed into a slot.
- Hard filters run before scoring: `banned_colors` against the real returned
  color names (case-insensitive); `banned_brands` is applied-but-no-data and
  `budget_ceiling` is not applicable to photographed garments — both said so
  in `filters_note`.
- **Phase 6 context depth.** The Occasion factor blends category suitability
  (70%) with a documented formality fit (30%): each occasion carries a
  0..1 formality read, and loud patterns/fits (graphic, camouflage,
  oversized…) are scaled down by it. The Weather factor's base weight scales
  by ×(1 + severity), severity = max(|t − 21°C|/15, precipitation/2mm),
  capped at 1 — harsh conditions genuinely move the ranking; `base_weight`
  in the report stays 6.0 while `effective_weight` carries the scaling.
  Both rules are deterministic configuration (summarized in
  `occasion_service.py`), verified by context-flip tests: HOT vs COLD and
  dinner vs gym reorder the same real wardrobe for different, traceable
  reasons.

Failures: `422` envelope `INSUFFICIENT_DATA` when the wardrobe (after hard
filters) cannot assemble any outfit — the message names what is actually
missing (e.g. shoes). Plain `422` for request validation. `503` only for
genuine service faults.

## `POST /tryon/render` — Phase 4

Multipart form: `person` and `garment` (JPEG/PNG, each ≤15 MB, never
persisted or logged). Runs the real pipelines first — quality gate, pose
(person count), garment analysis (category) — then the hosted FASHN
`tryon-max` renderer, then computes confidence as the fashionCLIP cosine
similarity between the source garment photo and the render.

Success `200`:

```json
{
  "render": {
    "image": "<base64 jpeg>",
    "mime": "image/jpeg",
    "method": "image_based_vton",
    "provider": "fashn"
  },
  "confidence": 0.931,
  "flags": [],
  "garment": { "category": "sweater", "category_confidence": 0.818 }
}
```

Honesty contract (docs/PRODUCT_SPEC.md §7): `method` is always
`image_based_vton` on this path — the API never claims precise physical
simulation. `confidence` is a real computed similarity in [0, 1]; below 0.25
the render is still returned but `flags` carries `LOW_CONFIDENCE`. The
client shows method + confidence permanently (DESIGN_SYSTEM §5).

Failures `422` (input-derived): `POOR_IMAGE`, `NO_PERSON`,
`MULTIPLE_PEOPLE`, `INSUFFICIENT_DATA` (garment not identifiable),
`VTON_UNSUPPORTED_GARMENT` (accessories: bag/hat/scarf/belt). Failures
`503` (service-side): `MODEL_MISSING` (no `FASHN_API_KEY`, or the provider
rejected it), `RATE_LIMITED`, `MODEL_FAILED`, `NETWORK_ERROR`.

## `POST /size/recommend` — Phase 5

JSON body: the client sends the real `/analysis/body` payload verbatim plus a
size chart the user copied from a real product page (centimetre values per
size — user-provided data, never catalog-scraped).

Request:

```json
{
  "category": "shirt",
  "fit_type": "regular",
  "body_profile": { "…": "/analysis/body response, verbatim" },
  "size_chart": {
    "brand": "optional label",
    "rows": [
      { "label": "S", "chest_cm": 88, "shoulder_cm": 44, "sleeve_cm": 60 },
      { "label": "M", "chest_cm": 92, "shoulder_cm": 46, "sleeve_cm": 62 }
    ]
  }
}
```

Success `200`:

```json
{
  "recommended": { "label": "M", "score": 1.0 },
  "confidence": 0.9,
  "flags": [],
  "fit_type": "regular",
  "brand": "optional label",
  "regions": [
    { "region": "chest", "measured_cm": null, "chart_cm": 92,
      "status": "not_measurable", "note": "not measurable from one photo" },
    { "region": "shoulder", "measured_cm": 44.0, "chart_cm": 46.0,
      "delta_cm": 0.0, "status": "matched" }
  ],
  "sizes": [ { "label": "S", "score": 0.5 }, { "label": "M", "score": 1.0 } ],
  "note": "Scored without chest (not measurable from one photo); …"
}
```

Honesty contract:

- Only the real Phase 1 measurements score: shoulder, hip and arm-as-sleeve.
  Chest/waist are `null` by design → excluded from scoring, listed as
  `not_measurable`. `length` is shown but never scored (no honest body
  counterpart).
- Matching happens purely in centimetre space (Brand Size Normalization,
  PRODUCT_SPEC §8): brand labels are opaque; documented garment ease per fit
  type (slim/regular/relaxed/oversized) plus a 4 cm tolerance window per
  region. `confidence = 0.7·score + 0.3·coverage`; below 0.5 the result is
  returned with `LOW_CONFIDENCE`.
- Failures `422`: `NO_SIZE_CHART` (fewer than two sized rows),
  `INSUFFICIENT_DATA` (the chart's regions have no measurable body input —
  e.g. chest/waist-only charts, or footwear, which needs a foot length the
  scan does not measure). Plain `422` for taxonomy/fit/range validation.

## Error envelope

Domain errors always use the `docs/PRODUCT_SPEC.md §12` taxonomy:

```json
{ "error": { "code": "NO_PERSON", "message": "No person detected. Step back so your full body is in the frame." } }
```
