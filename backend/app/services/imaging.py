"""Shared image decoding and quality gates.

BUILD_PLAN §5: image bytes live in request memory only — never written to
disk, never logged. Every function here is pure over an in-memory buffer.
"""

import cv2
import numpy as np

from app.errors import AtelierError, FailureState

# Laplacian variance below this is too soft to measure from (tuned on the
# committed fixture set; see backend/tests).
SHARP_MIN = 40.0
# Luminance window for a usable exposure.
LUMA_MIN = 40.0
LUMA_MAX = 235.0


def decode(image_bytes: bytes) -> np.ndarray:
    arr = np.frombuffer(image_bytes, dtype=np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        raise AtelierError(
            FailureState.POOR_IMAGE,
            "That file could not be read as a photo. Try a JPEG or PNG.",
        )
    return img


def sharpness(img: np.ndarray) -> float:
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def mean_luminance(img: np.ndarray) -> float:
    return float(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).mean())


def quality_gate(img: np.ndarray) -> tuple[float, float]:
    """Reject unusable captures up front; return (sharpness, luminance)."""
    sharp = sharpness(img)
    luma = mean_luminance(img)
    if sharp < SHARP_MIN:
        raise AtelierError(
            FailureState.POOR_IMAGE,
            "The photo is too blurry to measure from. Retake it steady and in light.",
        )
    if luma < LUMA_MIN:
        raise AtelierError(
            FailureState.POOR_IMAGE,
            "The photo is too dark to analyze. Move into better light and retake.",
        )
    if luma > LUMA_MAX:
        raise AtelierError(
            FailureState.POOR_IMAGE,
            "The photo is overexposed. Step out of direct harsh light and retake.",
        )
    return sharp, luma


def sharpness_score(sharp: float) -> float:
    return float(min(1.0, sharp / (SHARP_MIN * 4.0)))


def exposure_score(luma: float) -> float:
    return float(max(0.0, 1.0 - abs(luma - 127.5) / 127.5))
