# Open-Source Components

Everything integrated into Atelier is tracked here with its license. Models are
tracked in `models/registry.yaml` (currently: pose_landmarker_full and
face_landmarker, both Apache-2.0).

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
| mediapipe | Pose + face landmark inference, CPU (Phase 1) | Apache-2.0 |
| opencv-python-headless | Image decode + quality gates; headless = no libGL/X11 (Phase 1) | Apache-2.0 |
| PyYAML | Registry parsing | MIT |
| python-multipart | Multipart image uploads | BSD-3-Clause |
| pytest (dev) | Tests | MIT |
| httpx (dev) | Test client | BSD-3-Clause |

## MediaPipe model weights

Served from `storage.googleapis.com/mediapipe-models` under the
google-ai-edge/mediapipe Apache-2.0 terms. Checksums recorded in
`models/registry.yaml`.

Verify licenses against upstream before adding anything new.
