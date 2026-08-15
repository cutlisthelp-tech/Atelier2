"""Failure-state taxonomy from docs/PRODUCT_SPEC.md §12.

Every domain service returns either a typed result with confidence, or one of
these states. Never a fabricated substitute.
"""

from enum import StrEnum


class FailureState(StrEnum):
    NO_PERSON = "NO_PERSON"
    MULTIPLE_PEOPLE = "MULTIPLE_PEOPLE"
    POOR_IMAGE = "POOR_IMAGE"
    INSUFFICIENT_DATA = "INSUFFICIENT_DATA"
    LOW_CONFIDENCE = "LOW_CONFIDENCE"
    MODEL_MISSING = "MODEL_MISSING"
    MODEL_FAILED = "MODEL_FAILED"
    GPU_MEMORY_ERROR = "GPU_MEMORY_ERROR"
    RATE_LIMITED = "RATE_LIMITED"
    NO_SIZE_CHART = "NO_SIZE_CHART"
    VTON_UNSUPPORTED_GARMENT = "VTON_UNSUPPORTED_GARMENT"
    PRODUCT_UNAVAILABLE = "PRODUCT_UNAVAILABLE"
    CATALOG_NOT_CONNECTED = "CATALOG_NOT_CONNECTED"
    STALE_CATALOG_DATA = "STALE_CATALOG_DATA"
    WEATHER_UNAVAILABLE = "WEATHER_UNAVAILABLE"
    NETWORK_ERROR = "NETWORK_ERROR"


class AtelierError(Exception):
    """Domain error carrying a §12 failure state."""

    def __init__(self, state: FailureState, message: str) -> None:
        self.state = state
        self.message = message
        super().__init__(f"{state}: {message}")


def error_envelope(state: FailureState, message: str) -> dict:
    return {"error": {"code": state.value, "message": message}}
