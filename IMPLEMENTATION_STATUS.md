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
person segmentation model; chest/waist depth measurements; Style Profile
remote sync (Phase 9).

## Phases 2–10

Not started. No feature flags are enabled.
