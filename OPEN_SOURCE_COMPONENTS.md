# Open-Source Components

Everything integrated into Atelier is tracked here with its license. Models are
tracked in `models/registry.yaml` (currently: pose_landmarker_full,
face_landmarker, selfie_multiclass_256x256, fashion_clip_vision_onnx,
fashion_clip_text_onnx, fashion_clip_tokenizer — all Apache-2.0).

## App dependencies (`app/pubspec.yaml`)

| Package | Purpose | License |
|---|---|---|
| Flutter SDK | App framework | BSD-3-Clause |
| yaml | Parse the model registry | BSD-3-Clause |
| device_info_plus | Real device data for the Diagnostics screen | BSD-3-Clause |
| http | Backend calls (analysis, health/model probes) | BSD-3-Clause |
| camera | Capture the body-scan photo (Phase 1) | BSD-3-Clause |
| path_provider | Local JSON storage for consent + Style Profile (Phase 1) | BSD-3-Clause |
| flutter_lints (dev) | Static analysis rules | BSD-3-Clause |

## Backend dependencies (`backend/requirements.txt`)

| Package | Purpose | License |
|---|---|---|
| FastAPI | API gateway | MIT |
| Uvicorn | ASGI server | BSD-3-Clause |
| mediapipe | Pose + face landmark inference, CPU (Phase 1); clothing mask for garment colors (Phase 2) | Apache-2.0 |
| opencv-python-headless | Image decode + quality gates; headless = no libGL/X11 (Phase 1) | Apache-2.0 |
| onnxruntime | Marqo-fashionCLIP vision/text encoders, CPU (Phase 2) | MIT |
| tokenizers | BPE tokenizer for marqo-fashionCLIP (Phase 2) | Apache-2.0 |
| PyYAML | Registry parsing | MIT |
| python-multipart | Multipart image uploads | BSD-3-Clause |
| pytest (dev) | Tests | MIT |
| httpx (dev) | Test client | BSD-3-Clause |

## MediaPipe model weights

Served from `storage.googleapis.com/mediapipe-models` under the
google-ai-edge/mediapipe Apache-2.0 terms. Checksums recorded in
`models/registry.yaml`.

## Fashion embedding weights (Phase 2)

Marqo-fashionCLIP (ViT-B-16, 512-dim) ONNX int8 exports + BPE tokenizer,
served from Hugging Face `Marqo/marqo-fashionCLIP` (Apache-2.0, revision
44f4c655). Checksums recorded in `models/registry.yaml`.

Evaluated and rejected: **FASHN Human Parser** — ships under the NVIDIA
Source Code License for SegFormer, which is not commercially safe
(AGENTS.md rule 3). **Marqo-fashionSigLIP** remains an upgrade candidate
(Apache-2.0) but needs a PyTorch runtime; recorded in `MODEL_SETUP.md`.

Verify licenses against upstream before adding anything new.
