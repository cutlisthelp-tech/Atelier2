# Model Setup

Two models are registered and verified (Phase 1). Weights live in
`backend/.model_cache/` (gitignored) and are managed by the backend Model
Manager (`backend/app/models/manager.py`): Discover → Download → Verify
(SHA-256) → Install → Load → Report.

## Registered models (`models/registry.yaml`)

| Model | Task | Runtime | Hardware | License | Status |
|---|---|---|---|---|---|
| pose_landmarker_full | 33-point body skeleton (IMAGE, num_poses=2) | mediapipe 1.0.1 | cpu | Apache-2.0 | installed, tested on real photos |
| face_landmarker | 478-point face mesh incl. iris (IMAGE, num_faces=2) | mediapipe 1.0.1 | cpu | Apache-2.0 | installed, tested on real photos |

Both were re-verified on 2026-08-14 per AGENTS.md rule 3: MediaPipe Tasks is
Apache-2.0, actively maintained (pip release current), weights are freely
downloadable, and CPU inference runs in under a second per image. `num_poses`
/ `num_faces` = 2 so a second person becomes an honest `MULTIPLE_PEOPLE`
failure state instead of a silent pick.

## Deferred, recorded

- **Person segmentation** — no Phase 1 consumer needs it. It enters the
  registry with the same lifecycle when Wardrobe/Try-On does.
- **On-device inference** — Phase 1 runs on backend CPU because no maintained
  Flutter MediaPipe plugin exists today. The migration path is recorded in
  `ARCHITECTURE.md`.

## How a model enters the project (docs/BUILD_PLAN.md §4)

1. **Search open-source first.** Check repository activity, license, weights
   availability, inference instructions, hardware requirements. Names in
   `docs/PRODUCT_SPEC.md` are starting points, not permanent choices.
2. **Register it** in `models/registry.yaml` with every field real:
   `name, github, revision, license, weights, checksum, runtime, task,
   hardware, installed, tested, notes`. No placeholder values — both the app
   and the backend reject incomplete entries.
3. **Model Manager lifecycle:** Discover → Download → Verify (checksum) →
   Install → Load → Cache → Unload → Report status (Diagnostics screen and
   `GET /models`).
4. **Test on real input** before marking `tested: true`.

## Planned by phase

- Phase 2: fashion-tuned embedding model (FashionCLIP/FashionSigLIP-class).
- Phase 4: virtual try-on — hosted API, not a local model.
