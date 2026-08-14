# Open-Source Components

Everything integrated into Atelier is tracked here with its license. Models are
tracked separately in `models/registry.yaml` (currently empty).

## App dependencies (`app/pubspec.yaml`)

| Package | Purpose | License |
|---|---|---|
| Flutter SDK | App framework | BSD-3-Clause |
| yaml | Parse the model registry | BSD-3-Clause |
| device_info_plus | Real device data for the Diagnostics screen | BSD-3-Clause |
| http | Backend health probe from Diagnostics | BSD-3-Clause |
| flutter_lints (dev) | Static analysis rules | BSD-3-Clause |

## Backend dependencies (`backend/requirements.txt`)

| Package | Purpose | License |
|---|---|---|
| FastAPI | API gateway | MIT |
| Uvicorn | ASGI server | BSD-3-Clause |
| pytest (dev) | Tests | MIT |
| httpx (dev) | Test client | BSD-3-Clause |

Verify licenses against upstream before adding anything new.
