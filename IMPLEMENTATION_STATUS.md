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
garment embedding storage + pgvector indexing (Phase 8); wardrobe item
persistence (Phase 7); Marqo-fashionSigLIP upgrade (Phase 8).

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

## Phases 3–10

Not started. No feature flags are enabled.
