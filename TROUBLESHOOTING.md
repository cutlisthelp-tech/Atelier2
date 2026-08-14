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

Expected in Phase 0 — `models/registry.yaml` is intentionally empty. See
`MODEL_SETUP.md`.

## Registry parse error: missing required fields

An entry in `models/registry.yaml` lacks one of the twelve required fields
(docs/BUILD_PLAN.md §4). The error message names the entry and the missing
fields. Fill them with real values or remove the entry — placeholders are
rejected by design.

## Backend tests can't import `app`

Run pytest from `backend/` (its `pytest.ini` sets `pythonpath = .`).
