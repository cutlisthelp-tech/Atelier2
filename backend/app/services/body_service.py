"""Body analysis pipeline — Phase 1 (BUILD_PLAN §1).

Real photo in → real BodyProfile out, or an exact §12 failure state.

Pipeline: decode → quality gate → MediaPipe pose (IMAGE mode, num_poses=2)
→ proportions from 3D world landmarks → measurements calibrated against the
user-entered height → deterministic confidence.

Honesty guard: only measurements the landmarks genuinely support are
computed — shoulder and hip widths from 3D world coordinates, limb lengths
from joint chains. Chest/waist depth is not inferable from a single 2D
capture, so those fields are returned as null. Never estimated.
"""

import math

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_tasks
from mediapipe.tasks.python import vision

from app.errors import AtelierError, FailureState
from app.models.manager import RegistryEntryError, manager
from app.services import imaging

MODEL_NAME = "pose_landmarker_full"

VISIBILITY_THRESHOLD = 0.5
MIN_VISIBLE_LANDMARKS = 20
CONFIDENCE_FLOOR = 0.5

# MediaPipe pose landmark indices.
NOSE = 0
LEFT_SHOULDER, RIGHT_SHOULDER = 11, 12
LEFT_ELBOW, RIGHT_ELBOW = 13, 14
LEFT_WRIST, RIGHT_WRIST = 15, 16
LEFT_HIP, RIGHT_HIP = 23, 24
LEFT_ANKLE, RIGHT_ANKLE = 27, 28
LEFT_HEEL, RIGHT_HEEL = 29, 30
LANDMARK_COUNT = 33

# 3D joint chains that produce defensible measurements.
MEASURED_CHAINS = {
    "arm_left": (LEFT_SHOULDER, LEFT_ELBOW, LEFT_WRIST),
    "arm_right": (RIGHT_SHOULDER, RIGHT_ELBOW, RIGHT_WRIST),
    "leg_left": (LEFT_HIP, 25, LEFT_ANKLE),
    "leg_right": (RIGHT_HIP, 26, RIGHT_ANKLE),
}


def _create_landmarker(model_path: str):
    options = vision.PoseLandmarkerOptions(
        base_options=mp_tasks.BaseOptions(model_asset_path=model_path),
        running_mode=vision.RunningMode.IMAGE,
        num_poses=2,
    )
    return vision.PoseLandmarker.create_from_options(options)


def _landmarker():
    try:
        return manager.load(MODEL_NAME, _create_landmarker)
    except KeyError:
        raise AtelierError(
            FailureState.MODEL_MISSING,
            "The pose model is not registered. Run the model manager.",
        )
    except RegistryEntryError as exc:
        raise AtelierError(FailureState.MODEL_MISSING, str(exc))
    except Exception as exc:  # load or download failure is a model failure
        raise AtelierError(FailureState.MODEL_FAILED, f"Pose model could not be loaded: {exc}")


def count_people(img) -> int:
    """Detected people in a decoded, quality-gated frame (Phase 4 try-on)."""
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = _landmarker().detect(mp_image)
    return 0 if not result.pose_landmarks else len(result.pose_landmarks)


def _dist(a, b) -> float:
    return math.sqrt((a.x - b.x) ** 2 + (a.y - b.y) ** 2 + (a.z - b.z) ** 2)


def _mid(a, b):
    class _P:
        x = (a.x + b.x) / 2.0
        y = (a.y + b.y) / 2.0
        z = (a.z + b.z) / 2.0

    return _P()


def _chain_length(world, chain) -> float:
    total = 0.0
    for i in range(len(chain) - 1):
        total += _dist(world[chain[i]], world[chain[i + 1]])
    return total


def analyze_body(image_bytes: bytes, height_cm: float) -> dict:
    img = imaging.decode(image_bytes)
    sharp, luma = imaging.quality_gate(img)

    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
    result = _landmarker().detect(mp_image)

    if not result.pose_landmarks:
        raise AtelierError(
            FailureState.NO_PERSON,
            "No person detected. Step back so your full body is in the frame.",
        )
    if len(result.pose_landmarks) > 1:
        raise AtelierError(
            FailureState.MULTIPLE_PEOPLE,
            "More than one person detected. Please scan alone.",
        )

    pose = result.pose_landmarks[0]
    world = result.pose_world_landmarks[0]

    visible = [p for p in pose if p.visibility > VISIBILITY_THRESHOLD]
    visibility_score = len(visible) / LANDMARK_COUNT

    # Calibration: pose world landmarks are in metres. The vertical y-span is
    # pose-dependent (a jump or crouch compresses it), so calibrate against
    # the pose-invariant head→ankle chain length instead, anchored to the
    # user-entered height. Measurements stay honest for bent limbs too.
    mid_shoulder = _mid(world[LEFT_SHOULDER], world[RIGHT_SHOULDER])
    mid_hip = _mid(world[LEFT_HIP], world[RIGHT_HIP])
    neck_m = _dist(world[NOSE], mid_shoulder)
    torso_m = _dist(mid_shoulder, mid_hip)
    leg_m = (
        _chain_length(world, MEASURED_CHAINS["leg_left"])
        + _chain_length(world, MEASURED_CHAINS["leg_right"])
    ) / 2.0
    chain_m = neck_m + torso_m + leg_m
    if chain_m <= 0:
        raise AtelierError(
            FailureState.INSUFFICIENT_DATA,
            "Not enough of the body is visible to measure. Stand fully in frame.",
        )
    scale = (height_cm / 100.0) / chain_m  # dimensionless correction factor
    if not (0.5 <= scale <= 2.0):
        # The visible body wildly disagrees with the entered height — the
        # photo or the input cannot support measurement.
        raise AtelierError(
            FailureState.INSUFFICIENT_DATA,
            "The visible body does not match the entered height. Check both and retake.",
        )

    to_cm = scale * 100.0  # world metres → calibrated centimetres
    shoulder_cm = _dist(world[LEFT_SHOULDER], world[RIGHT_SHOULDER]) * to_cm
    hip_cm = _dist(world[LEFT_HIP], world[RIGHT_HIP]) * to_cm
    torso_cm = torso_m * to_cm
    leg_cm = leg_m * to_cm
    arm_cm = (
        (_chain_length(world, MEASURED_CHAINS["arm_left"])
         + _chain_length(world, MEASURED_CHAINS["arm_right"])) / 2.0
    ) * to_cm

    flags: list[str] = []
    if len(visible) < MIN_VISIBLE_LANDMARKS:
        flags.append(FailureState.LOW_CONFIDENCE.value)

    def ratio(a: float, b: float):
        return round(a / b, 3) if b > 0 else None

    shoulder_to_hip = ratio(shoulder_cm, hip_cm)
    torso_to_leg = ratio(torso_cm, leg_cm)
    vertical_balance = ratio(torso_cm, torso_cm + leg_cm)

    if shoulder_to_hip is None:
        body_shape = "insufficient_data"
    elif shoulder_to_hip >= 1.08:
        body_shape = "inverted_triangle"
    elif shoulder_to_hip <= 0.92:
        body_shape = "triangle"
    else:
        body_shape = "rectangle"

    confidence = round(
        0.5 * visibility_score
        + 0.3 * imaging.sharpness_score(sharp)
        + 0.2 * imaging.exposure_score(luma),
        3,
    )
    if confidence < CONFIDENCE_FLOOR and FailureState.LOW_CONFIDENCE.value not in flags:
        flags.append(FailureState.LOW_CONFIDENCE.value)

    return {
        "body": {
            "measurements_cm": {
                "height_input": height_cm,
                "shoulder": round(shoulder_cm, 1),
                "hip": round(hip_cm, 1),
                "torso": round(torso_cm, 1),
                "leg": round(leg_cm, 1),
                "arm": round(arm_cm, 1),
                # Honesty guard: not inferable from a single 2D capture.
                "chest": None,
                "waist": None,
            },
            "proportions": {
                "torso_to_leg_ratio": torso_to_leg,
                "shoulder_to_hip_ratio": shoulder_to_hip,
                "vertical_balance": vertical_balance,
            },
            "body_shape": body_shape,
            "skeleton": [
                {"x": round(p.x, 4), "y": round(p.y, 4), "visibility": round(p.visibility, 3)}
                for p in pose
            ],
            "visible_landmarks": len(visible),
        },
        "confidence": confidence,
        "flags": flags,
    }
