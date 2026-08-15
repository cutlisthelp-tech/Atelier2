# Architecture

Per `docs/PRODUCT_SPEC.md §3`:

```
Mobile App (Flutter)  →  API Gateway (FastAPI)  →  Domain Services
  →  Repositories  →  ML / External Providers
```

The UI never talks to a model directly. Every result is typed, carries a
confidence value, or is one of the failure states in `docs/PRODUCT_SPEC.md §12`
(`backend/app/errors.py` is the shared taxonomy).

## What exists today (Phase 1 + 2)

- **Flutter shell** — five tabs (HOME · DISCOVER · TRY ON · WARDROBE · PROFILE), honest empty states, semantic design tokens (`app/lib/theme/tokens.dart`), glass reserved for the nav bar.
- **Body Scan flow** — biometric consent gate (explicit, stored locally, blocks scanning until granted) → camera capture → `POST /analysis/body` (+ `/analysis/appearance` on the same capture) → result screen with the real skeleton overlay, real measurements in the Data typeface, real palette swatches, visible confidence. Failures render the exact §12 state.
- **Garment Scan flow (Phase 2)** — WARDROBE tab entry → camera capture → `POST /analysis/garment` → result screen with real category/colors/pattern/fit/material, `Unknown` spelled out where the model is not confident. No consent gate: garments are not biometric data. Nothing is persisted yet — wardrobe storage arrives with Phase 7.
- **Style Profile** — real user input (height, fit, aesthetics, bans, budget) persisted locally as JSON (`path_provider`); Phase 9 migrates to remote sync.
- **Model Manager** — app side: Discover + Report from the canonical registry. Backend side (`backend/app/models/manager.py`): the full Download → Verify (SHA-256) → Install → Load → Report lifecycle over `backend/.model_cache/`.
- **Model registry** (`models/registry.yaml`) — canonical; six verified entries (pose, face, selfie_multiclass, fashionCLIP vision/text/tokenizer).
- **FastAPI** — health, feature flags, `/analysis/body`, `/analysis/appearance`, `/analysis/garment`, `/models`.
- **No database.** Postgres/pgvector enters only when a phase requires it (visual search, accounts). The 512-dim garment embedding is returned to the client and stored by nothing yet.

## Phase 1 decision: inference on backend CPU

`docs/PRODUCT_SPEC.md §5` prefers on-device inference. Phase 1 runs on the
backend CPU instead, for a recorded reason: no maintained Flutter MediaPipe
plugin exists today (checked 2026-08-14), while MediaPipe Tasks Python is
active and Apache-2.0. **Upgrade path:** when a maintained on-device runtime
lands, move pose/face detection into the app; the typed contracts
(`ScanOutcome`, §12 failure states) stay identical, so screens and tests are
untouched. Privacy guardrails hold either way: images travel in request
memory only — never written to disk, never logged (BUILD_PLAN §5).

## Phase 2 decision: ONNX fashion embeddings, no PyTorch

Marqo-fashionCLIP ships author-published ONNX int8 exports; loading them with
onnxruntime keeps the garment pipeline on the same modest CPU box as Phase 1
(~150 MB of weights instead of a ~1 GB PyTorch stack). Zero-shot prompt sets
are fixed configuration; text embeddings are computed once per process and
cached. The category taxonomy doubles as the presence check, and every
attribute carries its own confidence threshold below which the honest answer
is `Unknown` — never a guess. FashionSigLIP (stronger on retrieval, PyTorch
runtime) is the recorded upgrade for Phase 8 visual search.

## Deliberate boundaries

- Orchestrator LLM (later phases) narrates; it never computes a number.
- Measurements are deterministic geometry from landmarks, calibrated by the
  user-entered height. Chest/waist depth is returned `null`, never guessed.
- Ranking (Phase 3) is a deterministic weighted service, not the LLM.
- VTON (Phase 4) uses a hosted API — no self-hosted GPU.
