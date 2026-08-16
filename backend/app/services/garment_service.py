"""Garment analysis pipeline — Phase 2 (BUILD_PLAN §1, PRODUCT_SPEC §5.3).

A garment photo in → a real GarmentRepresentation out, or an exact §12
failure state.

Pipeline: decode → quality gate → garment-presence check → zero-shot
category/pattern/fit/material with Marqo-fashionCLIP (ONNX, CPU) →
deterministic dominant-color extraction confined to a MediaPipe
selfie_multiclass clothing mask (worn photos) or center-weighted sampling
(flat-lay) → 512-dim embedding for later Wardrobe/visual-search reuse.

Honesty rules: every attribute carries its own confidence threshold — below
it the attribute is reported as unknown rather than guessed. No attribute is
ever fabricated.
"""

import cv2
import mediapipe as mp
import numpy as np
import onnxruntime as ort
from mediapipe.tasks import python as mp_tasks
from mediapipe.tasks.python import vision
from tokenizers import Tokenizer

from app.errors import AtelierError, FailureState
from app.models.manager import RegistryEntryError, manager
from app.services import imaging

VISION_MODEL = "fashion_clip_vision_onnx"
TEXT_MODEL = "fashion_clip_text_onnx"
TOKENIZER_MODEL = "fashion_clip_tokenizer"
SEGMENTER_MODEL = "selfie_multiclass_256x256"

# selfie_multiclass class index for clothing.
CLOTHING_CLASS = 4
CLOTHING_SHARE_MIN = 0.01

# Zero-shot thresholds. The category taxonomy doubles as the presence check:
# below PRESENCE_MIN the photo contains no recognizable garment
# (§12 INSUFFICIENT_DATA); between PRESENCE_MIN and CATEGORY_MIN a garment is
# present but its category is reported as unknown rather than guessed.
PRESENCE_MIN = 0.35
CATEGORY_MIN = 0.5
ATTRIBUTE_MIN = 0.35
CONFIDENCE_FLOOR = 0.5

CLIP_MEAN = np.array([0.48145466, 0.4578275, 0.40821073], dtype=np.float32)
CLIP_STD = np.array([0.26862954, 0.26130258, 0.27577711], dtype=np.float32)
SEQ_LEN = 77
TEMPERATURE = 100.0

CATEGORY_PROMPTS = [
    "a photo of a dress",
    "a photo of a t-shirt",
    "a photo of a shirt",
    "a photo of a blouse",
    "a photo of a sweater",
    "a photo of a hoodie",
    "a photo of a jacket",
    "a photo of a coat",
    "a photo of jeans",
    "a photo of trousers",
    "a photo of shorts",
    "a photo of a skirt",
    "a photo of a suit",
    "a photo of shoes",
    "a photo of sneakers",
    "a photo of boots",
    "a photo of a bag",
    "a photo of a hat",
    "a photo of a scarf",
    "a photo of a belt",
]
CATEGORY_LABELS = [
    "dress", "t-shirt", "shirt", "blouse", "sweater", "hoodie", "jacket",
    "coat", "jeans", "trousers", "shorts", "skirt", "suit", "shoes",
    "sneakers", "boots", "bag", "hat", "scarf", "belt",
]

PATTERN_PROMPTS = [
    "a photo of a plain solid color garment",
    "a photo of a striped garment",
    "a photo of a polka dot garment",
    "a photo of a floral print garment",
    "a photo of a plaid checkered garment",
    "a photo of a garment with a graphic print",
    "a photo of an animal print garment",
    "a photo of a camouflage garment",
]
PATTERN_LABELS = [
    "solid", "striped", "polka dot", "floral", "plaid", "graphic",
    "animal print", "camouflage",
]

FIT_PROMPTS = [
    "a photo of a slim fit garment",
    "a photo of a regular fit garment",
    "a photo of a loose relaxed fit garment",
    "a photo of an oversized baggy garment",
]
FIT_LABELS = ["slim", "regular", "relaxed", "oversized"]

MATERIAL_PROMPTS = [
    "a photo of a cotton garment",
    "a photo of a denim garment",
    "a photo of a leather garment",
    "a photo of a wool knit garment",
    "a photo of a silk satin garment",
    "a photo of a linen garment",
    "a photo of a synthetic polyester garment",
]
MATERIAL_LABELS = [
    "cotton", "denim", "leather", "wool knit", "silk/satin", "linen",
    "synthetic",
]

# Cached text embeddings for the fixed prompt sets (process-local).
_TEXT_FEATURE_CACHE: dict[str, np.ndarray] = {}


def _load(name: str, factory, what: str):
    try:
        return manager.load(name, factory)
    except KeyError:
        raise AtelierError(
            FailureState.MODEL_MISSING, f"The {what} model is not registered."
        )
    except RegistryEntryError as exc:
        raise AtelierError(FailureState.MODEL_MISSING, str(exc))
    except Exception as exc:
        raise AtelierError(
            FailureState.MODEL_FAILED, f"The {what} model could not be loaded: {exc}"
        )


def _vision_session(path: str) -> ort.InferenceSession:
    return ort.InferenceSession(path, providers=["CPUExecutionProvider"])


def _text_session(path: str) -> ort.InferenceSession:
    return ort.InferenceSession(path, providers=["CPUExecutionProvider"])


def _tokenizer(path: str) -> Tokenizer:
    tok = Tokenizer.from_file(path)
    tok.enable_truncation(max_length=SEQ_LEN)
    tok.enable_padding(length=SEQ_LEN)
    return tok


def _segmenter(path: str) -> vision.ImageSegmenter:
    options = vision.ImageSegmenterOptions(
        base_options=mp_tasks.BaseOptions(model_asset_path=path),
        output_confidence_masks=True,
    )
    return vision.ImageSegmenter.create_from_options(options)


def _text_features(prompts: list[str], cache_key: str) -> np.ndarray:
    if cache_key in _TEXT_FEATURE_CACHE:
        return _TEXT_FEATURE_CACHE[cache_key]
    tok = _load(TOKENIZER_MODEL, _tokenizer, "tokenizer")
    session = _load(TEXT_MODEL, _text_session, "fashion text encoder")
    enc = tok.encode_batch(prompts)
    input_ids = np.array([e.ids for e in enc], dtype=np.int64)
    out = session.run(None, {"input_ids": input_ids})[0].astype(np.float32)
    feats = out / np.linalg.norm(out, axis=1, keepdims=True)
    _TEXT_FEATURE_CACHE[cache_key] = feats
    return feats


def _vision_features(img_bgr: np.ndarray) -> np.ndarray:
    session = _load(VISION_MODEL, _vision_session, "fashion vision encoder")
    rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    h, w = rgb.shape[:2]
    scale = 224.0 / min(h, w)
    # round + 224 floor: float truncation could leave a side at 223 and the
    # center-crop at 1px, which the ONNX graph rejects.
    rgb = cv2.resize(
        rgb, (max(224, int(round(w * scale))), max(224, int(round(h * scale))))
    )
    y0, x0 = (rgb.shape[0] - 224) // 2, (rgb.shape[1] - 224) // 2
    crop = rgb[y0 : y0 + 224, x0 : x0 + 224].astype(np.float32) / 255.0
    pixel_values = ((crop - CLIP_MEAN) / CLIP_STD).transpose(2, 0, 1)[None]
    out = session.run(None, {"pixel_values": pixel_values})[0].astype(np.float32)
    return out / np.linalg.norm(out, axis=1, keepdims=True)


def image_embedding(img_bgr) -> np.ndarray:
    """Unit 512-d fashionCLIP vision vector for one frame.

    Phase 4 reuses it to compute try-on confidence as the real cosine
    similarity between the source garment and the provider's render.
    """
    return _vision_features(img_bgr)[0]


def _zero_shot(img_feats: np.ndarray, prompts: list[str], cache_key: str) -> np.ndarray:
    text_feats = _text_features(prompts, cache_key)
    logits = TEMPERATURE * (img_feats @ text_feats.T)[0]
    logits = logits - logits.max()
    probs = np.exp(logits)
    return probs / probs.sum()


def _garment_mask(rgb: np.ndarray) -> tuple[np.ndarray | None, float]:
    """Clothing pixel mask when someone wears the garment, else (None, 0)."""
    try:
        segmenter = _load(SEGMENTER_MODEL, _segmenter, "garment segmenter")
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = segmenter.segment(mp_image)
    except AtelierError:
        raise
    except Exception:
        # The mask only refines color sampling; a failed segmenter must not
        # sink an otherwise valid analysis.
        return None, 0.0
    stack = np.concatenate(
        [m.numpy_view() for m in result.confidence_masks], axis=2
    )
    classes = stack.argmax(axis=2)
    clothing = classes == CLOTHING_CLASS
    share = float(clothing.mean())
    if share < CLOTHING_SHARE_MIN:
        return None, share
    return clothing, share


def _name_color(bgr: np.ndarray) -> str:
    """Deterministic RGB → color name rules (documented in API.md)."""
    r, g, b = (int(c) for c in bgr[::-1])
    h, s, v = cv2.cvtColor(
        np.uint8([[[b, g, r]]]), cv2.COLOR_BGR2HSV
    )[0, 0].astype(float)
    h = h * 2.0  # openCV hue is 0–180; normalize to 0–360 degrees
    s /= 255.0
    v /= 255.0
    if v < 0.12:
        return "black"
    if v > 0.88 and s < 0.12:
        return "white"
    if s < 0.15:
        if v < 0.35:
            return "charcoal"
        if v > 0.65:
            return "light gray"
        return "gray"
    if 15 <= h < 50 and v < 0.55:
        return "brown"
    if 20 <= h < 50 and s < 0.4 and v > 0.6:
        return "beige"
    if h < 15 or h >= 345:
        return "burgundy" if v < 0.5 else "red"
    if h < 40:
        return "orange"
    if h < 70:
        return "olive" if v < 0.5 else "yellow"
    if h < 165:
        return "olive green" if (h < 90 and v < 0.45) else "green"
    if h < 200:
        return "teal"
    if h < 250:
        if v < 0.35:
            return "navy"
        if v > 0.7 and s < 0.5:
            return "light blue"
        return "blue"
    if h < 290:
        return "lavender" if v > 0.7 else "purple"
    return "pink" if v > 0.6 else "magenta"


def _dominant_colors(img_bgr: np.ndarray, mask: np.ndarray | None) -> tuple[list[dict], str]:
    if mask is not None:
        pixels = img_bgr[mask].astype(np.float32)
        source = "segmentation"
    else:
        h, w = img_bgr.shape[:2]
        crop = img_bgr[int(h * 0.2) : int(h * 0.8), int(w * 0.2) : int(w * 0.8)]
        pixels = crop.reshape(-1, 3).astype(np.float32)
        source = "center_weighted"
    if len(pixels) < 50:
        return [], source
    k = 3
    _, labels, centers = cv2.kmeans(
        pixels, k, None,
        (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 10, 1.0),
        3, cv2.KMEANS_PP_CENTERS,
    )
    counts = np.bincount(labels.flatten(), minlength=k)
    total = counts.sum()
    colors = []
    for center, count in sorted(zip(centers, counts), key=lambda c: -c[1]):
        share = count / total
        if share < 0.08:
            continue
        b, g, r = (int(round(c)) for c in center)
        colors.append({
            "name": _name_color(center),
            "hex": f"#{r:02x}{g:02x}{b:02x}",
            "share": round(float(share), 3),
        })
    return colors, source


def analyze_garment(image_bytes: bytes) -> dict:
    img = imaging.decode(image_bytes)
    sharp, luma = imaging.quality_gate(img)

    img_feats = _vision_features(img)

    category_probs = _zero_shot(img_feats, CATEGORY_PROMPTS, "category")
    category_idx = int(category_probs.argmax())
    category_conf = float(category_probs[category_idx])
    if category_conf < PRESENCE_MIN:
        raise AtelierError(
            FailureState.INSUFFICIENT_DATA,
            "No garment detected. Photograph one clothing item, close and centered.",
        )
    category = {
        "value": CATEGORY_LABELS[category_idx] if category_conf >= CATEGORY_MIN else None,
        "confidence": round(category_conf, 3),
    }

    def attribute(prompts: list[str], labels: list[str], key: str) -> dict:
        probs = _zero_shot(img_feats, prompts, key)
        idx = int(probs.argmax())
        conf = float(probs[idx])
        return {
            "value": labels[idx] if conf >= ATTRIBUTE_MIN else None,
            "confidence": round(conf, 3),
        }

    pattern = attribute(PATTERN_PROMPTS, PATTERN_LABELS, "pattern")
    fit = attribute(FIT_PROMPTS, FIT_LABELS, "fit")
    material = attribute(MATERIAL_PROMPTS, MATERIAL_LABELS, "material")

    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    mask, clothing_share = _garment_mask(rgb)
    colors, colors_source = _dominant_colors(img, mask)

    embedding = [round(float(x), 6) for x in img_feats[0]]

    flags: list[str] = []
    confidence = round(
        0.6 * category_conf
        + 0.2 * imaging.sharpness_score(sharp)
        + 0.2 * imaging.exposure_score(luma),
        3,
    )
    if confidence < CONFIDENCE_FLOOR:
        flags.append(FailureState.LOW_CONFIDENCE.value)

    return {
        "garment": {
            "category": category,
            "colors": colors,
            "colors_source": colors_source,
            "clothing_mask_share": round(clothing_share, 4),
            "pattern": pattern,
            "fit": fit,
            "material": material,
            "embedding": embedding,
        },
        "confidence": confidence,
        "flags": flags,
    }
