"""Runtime configuration. Feature flags default OFF per docs/BUILD_PLAN.md §1
and flip on only after Phases 0–8 are proven."""

import os

APP_NAME = "atelier-backend"
APP_VERSION = "0.0.0"  # Phase 0 — no shipped capability yet

FEATURE_FLAGS = (
    "FEATURE_AUTH",
    "FEATURE_SUBSCRIPTIONS",
    "FEATURE_CLOUD_SYNC",
    "FEATURE_SHOPPING",
)


def feature_flags() -> dict[str, bool]:
    return {name: os.environ.get(name, "false").lower() == "true" for name in FEATURE_FLAGS}
