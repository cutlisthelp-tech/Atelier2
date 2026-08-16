# Development

## Layout

- `app/` — Flutter client (Android target)
- `backend/` — FastAPI backend
- `models/registry.yaml` — canonical model registry (symlinked into `app/assets/models/`)
- `docs/` — constitution: PRODUCT_SPEC, DESIGN_SYSTEM, BUILD_PLAN

## Toolchain

- Flutter 3.47.0 stable (`flutter doctor` must show Flutter + Android toolchain green)
- Android SDK 36 with platform-tools and build-tools
- Python 3.12+

## Backend

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
# mediapipe pulls opencv-contrib-python (GUI build, needs libGL) which shadows
# the headless build the backend requires — restore it:
.venv/bin/pip install --force-reinstall --no-deps opencv-python-headless
.venv/bin/pytest                      # tests
.venv/bin/uvicorn app.main:app --reload
```

Endpoints: `GET /health`, `GET /config/feature-flags`. See `API.md`.

## App

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter run                            # on a connected device
flutter build apk --debug
```

Feature flags (all default false): `--dart-define=FEATURE_AUTH=true` etc.
Backend URL for Diagnostics: `--dart-define=BACKEND_URL=http://<host>:8000`

## Rules that bite if ignored

- Never commit `.env`, keys, raw user images, or build artifacts (`.gitignore` covers them).
- No mock data. If a provider isn't connected, show the `docs/PRODUCT_SPEC.md §12` state.
- One phase at a time. One commit per verified phase.
