# Model Setup

Six models are registered and verified (Phase 1 + 2). Weights live in
`backend/.model_cache/` (gitignored) and are managed by the backend Model
Manager (`backend/app/models/manager.py`): Discover → Download → Verify
(SHA-256) → Install → Load → Report.

## Registered models (`models/registry.yaml`)

| Model | Task | Runtime | Hardware | License | Status |
|---|---|---|---|---|---|
| pose_landmarker_full | 33-point body skeleton (IMAGE, num_poses=2) | mediapipe 1.0.1 | cpu | Apache-2.0 | installed, tested on real photos |
| face_landmarker | 478-point face mesh incl. iris (IMAGE, num_faces=2) | mediapipe 1.0.1 | cpu | Apache-2.0 | installed, tested on real photos |
| selfie_multiclass_256x256 | 6-class person parsing; clothing class masks garment colors (Phase 2) | mediapipe 1.0.1 | cpu | Apache-2.0 | installed, tested on real photos |
| fashion_clip_vision_onnx | Fashion image encoder, ViT-B-16, 512-dim (ONNX int8) | onnxruntime 1.28.0 | cpu | Apache-2.0 | installed, tested on real photos |
| fashion_clip_text_onnx | Paired text encoder for zero-shot prompts (ONNX int8) | onnxruntime 1.28.0 | cpu | Apache-2.0 | installed, tested on real photos |
| fashion_clip_tokenizer | BPE tokenizer for the prompt sets | tokenizers 0.23.1 | cpu | Apache-2.0 | installed, tested |

Phase 1 models were re-verified on 2026-08-14 per AGENTS.md rule 3: MediaPipe
Tasks is Apache-2.0, actively maintained (pip release current), weights are
freely downloadable, and CPU inference runs in under a second per image.
`num_poses` / `num_faces` = 2 so a second person becomes an honest
`MULTIPLE_PEOPLE` failure state instead of a silent pick.

Phase 2 models were verified on 2026-08-14 per AGENTS.md rule 3:
Marqo-fashionCLIP is Apache-2.0 with an active repository
(github.com/marqo-ai/marqo-FashionCLIP), public Hugging Face weights
including author-published ONNX int8 exports, and sharp, well-calibrated
zero-shot classification on real fixtures at CPU speed — so int8 was kept
over fp16. No PyTorch dependency: onnxruntime + tokenizers only.

## Evaluated and rejected (Phase 2)

- **FASHN Human Parser** — strong 18-class garment parsing, but ships under
  the NVIDIA Source Code License for SegFormer, which is not commercially
  safe under AGENTS.md rule 3. Rejected despite quality.
- **Marqo-fashionSigLIP** — Apache-2.0 and reportedly stronger on retrieval,
  but its weights load through `trust_remote_code`/open_clip hub paths that
  pull a PyTorch runtime (~1 GB). Kept as the documented upgrade candidate
  once embeddings feed pgvector search (Phase 8).

## Deferred, recorded

- **Person segmentation** — selfie_multiclass covers the Phase 2 need
  (clothing mask on worn photos). A salient-object model (U2Net-class) for
  busy flat-lay backgrounds enters with Phase 7/8.
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

- Phase 2: fashion-tuned embedding model — **done**: Marqo-fashionCLIP ONNX
  (see above).
- Phase 3: personal outfit recommendation — **zero models added**. Ranking is
  deterministic configuration + pure functions; weather is an external API
  (see `DATA_SOURCES.md`), not a model.
- Phase 4: virtual try-on — hosted API, not a local model.
