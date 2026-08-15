# Implementation Status

Source of truth for what is *verified working*, per `docs/BUILD_PLAN.md §1`
— a phase is done only when its Definition of Done is demonstrated, not when
it compiles.

## Phase 0 — Infrastructure, feature flags, Model Manager skeleton, Diagnostics

**Status: VERIFIED — 2026-08-14**

Definition of Done: *app boots, every screen shows an honest empty state, zero
mock data anywhere.* (See commit history for the Phase 0 evidence record.)

## Phase 1 — Body + Appearance + Style Profile

**Status: VERIFIED — 2026-08-14**

Definition of Done: *a real photo produces a real BodyProfile + ColorProfile
with confidence, or an honest failure state.*

Evidence:

- `pytest` — 14/14 passed on **real CC0/CC-BY fixture photos** (provenance in
  `backend/tests/fixtures/`): person photo → real BodyProfile (shoulder/hip/
  torso/leg/arm measurements calibrated to entered height, real proportions,
  33-point skeleton, confidence 0.757, chest/waist honestly `null`); portrait
  → real ColorProfile (undertone/depth/contrast → season + palette,
  confidence 0.984); landscape → `NO_PERSON`; darkened photo → `POOR_IMAGE`;
  garbage bytes → `POOR_IMAGE`; height out of range → plain 422.
- Live `uvicorn` smoke — `GET /health`, `GET /models`, `POST /analysis/body`
  (real BodyProfile), `POST /analysis/appearance` on a landscape (honest
  `NO_PERSON`) all returned exactly those payloads.
- `flutter analyze` — no issues. `flutter test` — 9/9 passed: consent gate
  blocks scanning until granted, result screen renders real numbers and the
  honest `null`s, failure screen shows the §12 code, Style Profile
  round-trips through local JSON, diagnostics reports both registered models.
- `flutter build apk --debug` — `app-debug.apk` produced. On-device camera
  capture happens on the maintainer's Android/Termux flow; not claimed here.
- Mock-data audit — zero hardcoded scores/measurements in code paths; every
  number shown comes from a real model run or the user's own input.

Honest limits of this verification:

- Inference runs on **backend CPU** (recorded decision + on-device upgrade
  path in `ARCHITECTURE.md`), not on the phone.
- Camera capture itself is not exercised in Codespace; the pipeline is
  verified end-to-end from real photos through the same endpoints the app
  calls.
- Chest/waist measurements remain `null` by design — not inferable from a
  single 2D capture.

## Known deferrals (recorded, not silent)

On-device inference migration; full streaming Constellation Scan animation;
chest/waist depth measurements; Style Profile remote sync (Phase 9);
salient-object segmentation for busy flat-lay backgrounds (Phase 7/8);
garment embedding storage + pgvector indexing (Phase 8); full Wardrobe
module — Phase 3 persists analysis JSON only (Phase 7 owns the module);
Marqo-fashionSigLIP upgrade (Phase 8).

## Phase 2 — Garment Analysis

**Status: VERIFIED — 2026-08-15**

Definition of Done: *a garment photo returns real category/color/attributes,
or "Unknown".*

Evidence:

- Models re-verified per AGENTS.md rule 3 before integration:
  Marqo-fashionCLIP (Apache-2.0, active repo, public ONNX int8 weights,
  CPU-fast) selected; FASHN Human Parser rejected (NVIDIA SegFormer license);
  FashionSigLIP recorded as upgrade. Four new registry entries with real
  SHA-256 checksums; backend Model Manager lifecycle unchanged.
- `pytest` — 20/20 passed on **real fixture photos** (provenance in
  `backend/tests/fixtures/`): worn checkered sweater → real category
  `sweater` 0.818, real colors from the selfie_multiclass clothing mask
  (charcoal/white/gray), fit `oversized` (matches the photo's own Commons
  description), 512-dim embedding, confidence 0.846; dresses-on-hangers →
  garment present but category honestly `null` (0.445) with real colors;
  landscape → `INSUFFICIENT_DATA`; darkened photo → `POOR_IMAGE`; garbage
  bytes → `POOR_IMAGE`.
- Live `uvicorn` smoke — `POST /analysis/garment` on both fixtures and the
  landscape returned exactly the test payloads; `GET /models` reports all six
  models installed.
- `flutter analyze` — no issues. `flutter test` — 13/13 passed: garment
  result screen renders real attributes, `UNKNOWN` plus the why for
  unconfident attributes, §12 failure codes; WARDROBE tab opens the garment
  scan; missing camera reported honestly.
- `flutter build apk --debug` — `app-debug.apk` produced.
- Mock-data audit — zero fabricated values; prompt sets and color-name rules
  are documented configuration, every displayed number comes from a real
  model run.

Honest limits of this verification:

- Camera capture happens on the maintainer's Android/Termux flow; the
  pipeline is verified end-to-end from real photos through the same endpoint
  the app calls.
- Pattern/material/fit are honest zero-shot reads with per-attribute
  thresholds — expect `Unknown` often on flat-lays. That is the DoD working.

## Phase 3 — Personal Outfit Recommendation

**Status: VERIFIED — 2026-08-15**

Definition of Done — BUILD_PLAN §2 *One Test*: real photo → real analysis →
real occasion + place → real weather → real available garments → candidate
outfits → scored for THIS person → Best Outfit → explanation tied to real
score components. §3 *Personalization Test*: the same wardrobe/occasion/place
must not score identically for 3 distinct real profiles, for different
reasons.

Evidence:

- `pytest` — 29/29 passed. Nine new Phase 3 tests call the **real**
  `/analysis/*` endpoints on **real fixture photos** (two new CC BY-SA
  fixtures — jeans, sneakers — with provenance in
  `backend/tests/fixtures/`) to build the wardrobe, then call
  `/recommend/outfit`: live Open-Meteo weather (`state == "ok"`, structural
  asserts only — real weather moves), best_match outfit assembled from the
  photographed sweater + jeans + sneakers, `why` bullets bound to real score
  components, active effective weights sum to 100, `score == Σ contribution`,
  `shopping.state == CATALOG_NOT_CONNECTED`, the unidentifiable hanger photo
  reported as `unplaceable` (never guessed into a slot).
- §3 personalization verified: three real profiles (body photo A, body photo
  B, and A without appearance + a different style profile) produce three
  distinct scores, and the *reasons* differ — A vs B on the body-driven
  proportion factor, A vs C on appearance activity and fit preference.
- Honesty under failure: `WEATHER_BASE_URL` pointed at a genuinely
  unreachable address → `WEATHER_UNAVAILABLE`, weather factor inactive,
  recommendation still returned; `banned_colors` emptying the pool → 422
  `INSUFFICIENT_DATA`; trend/budget/user_preference reported inactive with
  real reasons and their weights redistributed.
- Live `uvicorn` smoke — real analyses on fixtures → real
  `POST /recommend/outfit` → 200 with live Casablanca weather (22.3 °C,
  partly cloudy) and a 71.1 best_match outfit; a second server with an
  unreachable weather URL returned the honest `WEATHER_UNAVAILABLE` path.
- `flutter analyze` — no issues. `flutter test` — 20/20 passed: store
  round-trips, HOME prerequisite states computed from real stored data,
  result rendering from contract-shaped payloads, envelope parsing into
  typed success/failure. `flutter build apk --debug` — `app-debug.apk`
  produced.
- Deterministic ranking: pure scoring functions, double-call identical
  output; explanations are templates bound to real contributions, not an LLM.

Honest limits of this verification:

- Weather in tests is **live** Open-Meteo — success-path asserts are
  structural because real weather changes.
- Trend, Budget and User Preference factors are inactive by design (no trend
  feed, no prices on photographed garments, no feedback log yet).
- **Ranked alternatives #2–#4 (Safer / Trend / Bold)**: the full selection
  mechanism is implemented and tested (strategy labels, determinism,
  no-padding rule), but the fixture wardrobe assembles exactly ONE outfit,
  so end-to-end tests demonstrate #1 only — outfits are never padded to
  four (locked honesty decision). A real multi-outfit demonstration needs a
  larger wardrobe: it lands with the Phase 7 Wardrobe module (richer item
  set + fixtures), not as a Phase 3 retrofit.
- Outfits are assembled from the user's photographed wardrobe only — no
  merchant catalog is connected (rule 4); `SHOP THIS LOOK` renders
  `CATALOG_NOT_CONNECTED`.
- Camera capture remains the maintainer's Android/Termux flow; the pipeline
  is verified end-to-end from real photos through the same endpoints the app
  calls.

## Phases 4–10

Not started. No feature flags are enabled.
