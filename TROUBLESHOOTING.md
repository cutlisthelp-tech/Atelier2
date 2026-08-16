# Troubleshooting

## `flutter doctor` shows Android toolchain issues

Ensure `ANDROID_SDK_ROOT` points at the SDK and licenses are accepted:

```bash
sdkmanager --licenses
flutter doctor
```

## Diagnostics shows "Backend URL not configured."

Expected by default. Pass `--dart-define=BACKEND_URL=http://<host>:8000` when
running the app against a live backend.

## Diagnostics shows "No models registered."

The bundled `models/registry.yaml` asset is missing or empty on this checkout.
See `MODEL_SETUP.md`.

## Registry parse error: missing required fields

An entry in `models/registry.yaml` lacks one of the twelve required fields
(docs/BUILD_PLAN.md §4). The error message names the entry and the missing
fields. Fill them with real values or remove the entry — placeholders are
rejected by design.

## Backend tests can't import `app`

Run pytest from `backend/` (its `pytest.ini` sets `pythonpath = .`).

## `ImportError: libGL.so.1` when importing cv2

`mediapipe` transitively installs `opencv-contrib-python` (GUI build), whose
`cv2` files shadow the headless build this backend requires. Restore it:

```bash
.venv/bin/pip install --force-reinstall --no-deps opencv-python-headless
```

## `OSError: libEGL.so.1` when mediapipe loads its native library

`libmediapipe.so` links against EGL/GLES. Install them system-wide
(`sudo apt-get install -y libegl1 libgl1 libgles2`), or, where sudo is
unavailable, extract the `libegl1` / `libegl-mesa0` / `libgles2` debs into a
local directory and point `LD_LIBRARY_PATH` at it when running pytest or
uvicorn.
