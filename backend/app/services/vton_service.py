"""Virtual Try-On — Phase 4 (PRODUCT_SPEC §7, DESIGN_SYSTEM §5).

Person photo + garment photo → hosted render via the FASHN tryon-max API
(contract verified 2026-08-16 against docs.fashn.ai). The result is always
labeled with its method (image_based_vton, §7 honesty doctrine) and a
confidence that is real, never fabricated: the fashionCLIP cosine similarity
between the source garment photo and the provider's render.

Without a provider key the honest state is MODEL_MISSING — no render, no
substitute. Provider failures map onto the §12 taxonomy (RATE_LIMITED,
MODEL_FAILED, POOR_IMAGE).
"""

import asyncio
import base64
import os

import cv2
import httpx
import numpy as np

from app.errors import AtelierError, FailureState
from app.services import body_service, garment_service, imaging

PROVIDER_NAME = "fashn"
METHOD = "image_based_vton"
DEFAULT_BASE_URL = "https://api.fashn.ai"
POLL_INTERVAL_S = 1.0
POLL_ATTEMPTS = 60
MAX_IMAGE_BYTES = 15 * 1024 * 1024

# Below this garment↔render similarity the render is shown but flagged.
CONFIDENCE_FLOOR = 0.25

# Accessories cannot be worn onto a body by the current try-on path.
UNSUPPORTED_CATEGORIES = frozenset({"bag", "hat", "scarf", "belt"})


def configured() -> bool:
    return bool(os.environ.get("FASHN_API_KEY", "").strip())


def assert_supported_category(category: str | None) -> None:
    if category is None:
        raise AtelierError(
            FailureState.INSUFFICIENT_DATA,
            "The garment could not be identified from this photo. Retake it "
            "close and centered.",
        )
    if category in UNSUPPORTED_CATEGORIES:
        raise AtelierError(
            FailureState.VTON_UNSUPPORTED_GARMENT,
            f"A {category} can't be tried on yet — supported pieces are "
            "clothing and shoes.",
        )


def render_confidence(garment_img, render_bytes: bytes) -> float:
    """Real cosine similarity between source garment and render (0..1)."""
    render_img = imaging.decode(render_bytes)
    a = garment_service.image_embedding(garment_img)
    b = garment_service.image_embedding(render_img)
    cos = float(np.dot(a, b))
    return round(max(0.0, min(1.0, cos)), 3)


async def render_tryon(person_bytes: bytes, garment_bytes: bytes) -> dict:
    for data in (person_bytes, garment_bytes):
        if len(data) > MAX_IMAGE_BYTES:
            raise AtelierError(FailureState.POOR_IMAGE, "Image exceeds 15 MB.")

    person_img = imaging.decode(person_bytes)
    imaging.quality_gate(person_img)
    garment_img = imaging.decode(garment_bytes)
    imaging.quality_gate(garment_img)

    people = body_service.count_people(person_img)
    if people == 0:
        raise AtelierError(
            FailureState.NO_PERSON,
            "No person detected. Use a photo with one full body in frame.",
        )
    if people > 1:
        raise AtelierError(
            FailureState.MULTIPLE_PEOPLE,
            "More than one person detected. Use a photo of yourself alone.",
        )

    analysis = garment_service.analyze_garment(garment_bytes)
    category = analysis["garment"]["category"]["value"]
    assert_supported_category(category)

    if not configured():
        raise AtelierError(
            FailureState.MODEL_MISSING,
            "Try-on isn't connected yet. The hosted renderer needs a provider "
            "key (FASHN_API_KEY) — nothing is rendered without one.",
        )

    render_bytes = await _fashn_render(person_img, garment_img)
    confidence = render_confidence(garment_img, render_bytes)
    flags = []
    if confidence < CONFIDENCE_FLOOR:
        flags.append(FailureState.LOW_CONFIDENCE.value)

    return {
        "render": {
            "image": base64.b64encode(render_bytes).decode("ascii"),
            "mime": "image/jpeg",
            "method": METHOD,
            "provider": PROVIDER_NAME,
        },
        "confidence": confidence,
        "flags": flags,
        "garment": {
            "category": category,
            "category_confidence": analysis["garment"]["category"]["confidence"],
        },
    }


def _data_uri_jpeg(img) -> str:
    ok, buf = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 90])
    if not ok:
        raise AtelierError(FailureState.POOR_IMAGE, "The photo could not be re-encoded.")
    return "data:image/jpeg;base64," + base64.b64encode(buf.tobytes()).decode("ascii")


def _from_data_uri(uri: str) -> bytes:
    if "," in uri:
        uri = uri.split(",", 1)[1]
    return base64.b64decode(uri)


def _raise_for_api(resp: httpx.Response) -> None:
    if resp.status_code == 401:
        raise AtelierError(
            FailureState.MODEL_MISSING, "The try-on provider rejected the key."
        )
    if resp.status_code == 429:
        raise AtelierError(
            FailureState.RATE_LIMITED,
            "The try-on provider is throttling requests. Try again shortly.",
        )
    if resp.status_code == 400:
        raise AtelierError(
            FailureState.POOR_IMAGE, "The provider rejected the input photos."
        )
    if resp.status_code >= 500:
        raise AtelierError(
            FailureState.MODEL_FAILED,
            f"The try-on provider errored (HTTP {resp.status_code}).",
        )


async def _fashn_render(person_img, garment_img) -> bytes:
    key = os.environ["FASHN_API_KEY"].strip()
    base = os.environ.get("FASHN_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    headers = {"Authorization": f"Bearer {key}"}
    body = {
        "model_name": "tryon-max",
        "inputs": {
            "model_image": _data_uri_jpeg(person_img),
            "product_image": _data_uri_jpeg(garment_img),
            "return_base64": True,
            "output_format": "jpeg",
            "num_images": 1,
        },
    }
    timeout = httpx.Timeout(connect=5.0, read=30.0, write=30.0, pool=5.0)
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            resp = await client.post(f"{base}/v1/run", headers=headers, json=body)
            _raise_for_api(resp)
            run_id = (resp.json() or {}).get("id")
            if not run_id:
                raise AtelierError(
                    FailureState.MODEL_FAILED, "The provider returned no job id."
                )
            for _ in range(POLL_ATTEMPTS):
                await asyncio.sleep(POLL_INTERVAL_S)
                status = await client.get(
                    f"{base}/v1/status/{run_id}", headers=headers
                )
                _raise_for_api(status)
                doc = status.json() or {}
                state = doc.get("status")
                if state == "completed":
                    output = doc.get("output") or []
                    if not output:
                        raise AtelierError(
                            FailureState.MODEL_FAILED,
                            "The provider completed without an image.",
                        )
                    return _from_data_uri(output[0])
                if state == "failed":
                    name = (doc.get("error") or {}).get("name", "PipelineError")
                    if name == "ImageLoadError":
                        raise AtelierError(
                            FailureState.POOR_IMAGE,
                            "The provider could not read one of the photos. "
                            "Retake and try again.",
                        )
                    raise AtelierError(
                        FailureState.MODEL_FAILED,
                        f"The provider's render failed ({name}).",
                    )
    except AtelierError:
        raise
    except httpx.HTTPError as exc:
        raise AtelierError(
            FailureState.NETWORK_ERROR,
            f"The try-on provider could not be reached ({type(exc).__name__}).",
        )
    raise AtelierError(
        FailureState.MODEL_FAILED, "The provider did not finish in time."
    )
