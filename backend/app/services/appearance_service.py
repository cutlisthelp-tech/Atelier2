"""Appearance analysis pipeline — Phase 1 (BUILD_PLAN §1).

Real portrait in → real ColorProfile out, or an exact §12 failure state.

Deterministic seasonal-analysis mapping (no learned model, no invention):

1. Sample skin pixels at the cheek and forehead landmarks; discard
   over/under-exposed samples. Fewer than two usable samples →
   INSUFFICIENT_DATA.
2. skin_depth from mean skin luminance (≥170 light, ≥110 medium, else deep).
3. skin_undertone from the chromatic spread of the cheek colour: warm skin
   carries a red-over-green spread larger than its green-over-blue spread;
   cool skin shows the opposite. Within the neutral band → neutral.
4. overall_contrast from the luminance gap between skin and the hair/brow
   region above the forehead (≥70 high, ≥35 medium, else low).
5. season = fixed table over (undertone, contrast, depth) — the classic
   four-season split:
     cool + high contrast            → winter
     cool + low contrast             → summer
     cool + medium contrast          → summer if light, else winter
     warm + light + medium/high      → spring
     warm + otherwise                → autumn
6. The palette returned is the documented palette for that season. Palettes
   are deterministic design constants, not user data.

Landmark indices follow the 478-point MediaPipe face mesh.
"""

import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks import python as mp_tasks
from mediapipe.tasks.python import vision

from app.errors import AtelierError, FailureState
from app.models.manager import RegistryEntryError, manager
from app.services import imaging

MODEL_NAME = "face_landmarker"

CONFIDENCE_FLOOR = 0.5
SKIN_LUMA_FLOOR, SKIN_LUMA_CEIL = 40.0, 240.0

LEFT_CHEEK, RIGHT_CHEEK = 50, 280
FOREHEAD = 10
CHIN = 152
LEFT_BROW, RIGHT_BROW = 66, 296

SEASON_PALETTES: dict[str, list[dict]] = {
    "winter": [
        {"name": "True Black", "hex": "#0B0B0D"},
        {"name": "Royal Navy", "hex": "#1B2A4A"},
        {"name": "Icy Blue", "hex": "#A8C8E0"},
        {"name": "Fuchsia", "hex": "#C4306B"},
        {"name": "Pure White", "hex": "#F4F4F2"},
    ],
    "summer": [
        {"name": "Dusty Rose", "hex": "#C08081"},
        {"name": "Powder Blue", "hex": "#AFC3D6"},
        {"name": "Lavender", "hex": "#B3A6C9"},
        {"name": "Soft Navy", "hex": "#34425C"},
        {"name": "Cool Grey", "hex": "#9A9AA3"},
    ],
    "spring": [
        {"name": "Coral", "hex": "#E8735A"},
        {"name": "Warm Turquoise", "hex": "#3FB8AF"},
        {"name": "Camel", "hex": "#C19A6B"},
        {"name": "Clear Green", "hex": "#4C9141"},
        {"name": "Cream", "hex": "#F3EAD3"},
    ],
    "autumn": [
        {"name": "Rust", "hex": "#A44A3F"},
        {"name": "Olive", "hex": "#6B6B3A"},
        {"name": "Mustard", "hex": "#C89B3C"},
        {"name": "Chocolate", "hex": "#4B3621"},
        {"name": "Terracotta", "hex": "#B66A50"},
    ],
}


def _create_landmarker(model_path: str):
    options = vision.FaceLandmarkerOptions(
        base_options=mp_tasks.BaseOptions(model_asset_path=model_path),
        running_mode=vision.RunningMode.IMAGE,
        num_faces=2,
    )
    return vision.FaceLandmarker.create_from_options(options)


def _landmarker():
    try:
        return manager.load(MODEL_NAME, _create_landmarker)
    except KeyError:
        raise AtelierError(
            FailureState.MODEL_MISSING,
            "The face model is not registered. Run the model manager.",
        )
    except RegistryEntryError as exc:
        raise AtelierError(FailureState.MODEL_MISSING, str(exc))
    except Exception as exc:
        raise AtelierError(FailureState.MODEL_FAILED, f"Face model could not be loaded: {exc}")


def _sample(img: np.ndarray, lm, radius: int = 5) -> np.ndarray | None:
    h, w = img.shape[:2]
    x, y = int(lm.x * w), int(lm.y * h)
    if not (radius <= x < w - radius and radius <= y < h - radius):
        return None
    patch = img[y - radius:y + radius, x - radius:x + radius]
    return patch.reshape(-1, 3).mean(axis=0)  # mean BGR


def analyze_appearance(image_bytes: bytes) -> dict:
    img = imaging.decode(image_bytes)
    sharp, luma = imaging.quality_gate(img)

    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = _landmarker().detect(mp_image)

    if not result.face_landmarks:
        raise AtelierError(
            FailureState.NO_PERSON,
            "No face detected. Face the camera directly in even light.",
        )
    if len(result.face_landmarks) > 1:
        raise AtelierError(
            FailureState.MULTIPLE_PEOPLE,
            "More than one face detected. Please scan alone.",
        )

    face = result.face_landmarks[0]

    skin_samples = []
    for idx in (LEFT_CHEEK, RIGHT_CHEEK, FOREHEAD):
        s = _sample(img, face[idx])
        bgr_luma = 0.114 * s[0] + 0.587 * s[1] + 0.299 * s[2] if s is not None else None
        if s is not None and SKIN_LUMA_FLOOR <= bgr_luma <= SKIN_LUMA_CEIL:
            skin_samples.append(s)
    if len(skin_samples) < 2:
        raise AtelierError(
            FailureState.INSUFFICIENT_DATA,
            "Not enough usable skin samples — harsh light or shadows. Retake in even light.",
        )

    skin = np.mean(skin_samples, axis=0)  # mean BGR
    b, g, r = float(skin[0]), float(skin[1]), float(skin[2])
    skin_luma = 0.114 * b + 0.587 * g + 0.299 * r

    # Depth ---------------------------------------------------------------
    if skin_luma >= 170.0:
        skin_depth = "light"
    elif skin_luma >= 110.0:
        skin_depth = "medium"
    else:
        skin_depth = "deep"

    # Undertone -----------------------------------------------------------
    rg_spread = r - g
    gb_spread = g - b
    if rg_spread > gb_spread * 1.15:
        skin_undertone = "warm"
    elif rg_spread < gb_spread * 0.85:
        skin_undertone = "cool"
    else:
        skin_undertone = "neutral"

    # Contrast: skin vs the hair/brow band above the forehead --------------
    face_height = face[CHIN].y - face[FOREHEAD].y
    hair_point = type("P", (), {
        "x": face[FOREHEAD].x,
        "y": max(0.0, face[FOREHEAD].y - 0.35 * face_height),
    })()
    brow = _sample(img, face[LEFT_BROW], radius=4)
    hair = _sample(img, hair_point, radius=7)
    dark_refs = [s for s in (brow, hair) if s is not None]
    if dark_refs:
        dark_luma = max(
            0.114 * s[0] + 0.587 * s[1] + 0.299 * s[2] for s in dark_refs
        )
        contrast_gap = skin_luma - dark_luma
    else:
        contrast_gap = 0.0

    if contrast_gap >= 70.0:
        overall_contrast = "high"
    elif contrast_gap >= 35.0:
        overall_contrast = "medium"
    else:
        overall_contrast = "low"

    # Season table ----------------------------------------------------------
    if skin_undertone == "cool":
        if overall_contrast == "high":
            season = "winter"
        elif overall_contrast == "low":
            season = "summer"
        else:
            season = "summer" if skin_depth == "light" else "winter"
    elif skin_undertone == "warm":
        season = "spring" if (skin_depth == "light" and overall_contrast != "low") else "autumn"
    else:
        # Neutral undertone splits on contrast, mirroring the cool/warm rules.
        season = "winter" if overall_contrast == "high" else "summer"

    sample_score = min(1.0, len(skin_samples) / 3.0)
    confidence = round(
        0.5 * sample_score
        + 0.3 * imaging.sharpness_score(sharp)
        + 0.2 * imaging.exposure_score(luma),
        3,
    )
    flags = [FailureState.LOW_CONFIDENCE.value] if confidence < CONFIDENCE_FLOOR else []

    return {
        "color": {
            "skin_undertone": skin_undertone,
            "skin_depth": skin_depth,
            "overall_contrast": overall_contrast,
            "season": season,
            "palette": SEASON_PALETTES[season],
        },
        "confidence": confidence,
        "flags": flags,
    }
