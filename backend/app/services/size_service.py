"""Size & Fit Engine — Phase 5 (PRODUCT_SPEC §8, BUILD_PLAN §1).

Measurements + garment size chart + fit type → recommended size + confidence
+ per-region breakdown. Deterministic and honest:

- The only body inputs are the real Phase 1 measurements (shoulder, hip,
  arm-as-sleeve). Chest and waist are null by design — a single 2D capture
  cannot support them — so they are excluded from scoring and listed in the
  breakdown as "not measurable from one photo".
- Brand Size Normalization (§8): charts are consumed purely as centimetres;
  brand labels are opaque. Cross-brand comparison therefore happens in cm
  space, and the response echoes the chart cm per region.
- Garment ease per fit type is documented configuration (below), never
  inferred. A region with no measurable body counterpart (length) is shown
  but never scored.
"""

from app.errors import AtelierError, FailureState
from app.services import occasion_service as occ

# §8 per-region breakdown order.
REGION_ORDER = ("chest", "shoulder", "sleeve", "length", "waist", "hip")

TOPS = frozenset({"t-shirt", "shirt", "blouse", "sweater", "hoodie", "jacket", "coat"})
BOTTOMS = frozenset({"jeans", "trousers", "shorts", "skirt"})
ONE_PIECES = frozenset({"dress", "suit"})
SHOES = frozenset({"shoes", "sneakers", "boots"})

RELEVANT_REGIONS = {
    "top": ("chest", "shoulder", "sleeve"),
    "bottom": ("waist", "hip"),
    "one_piece": ("chest", "waist", "hip"),
}

# Body measurement that genuinely supports each region (None = not measurable).
BODY_SOURCE = {
    "chest": None,
    "waist": None,
    "length": None,
    "shoulder": "shoulder",
    "hip": "hip",
    "sleeve": "arm",
}

# Documented garment ease (cm over body) per fit type. Configuration, in the
# same status as the occasion tables — summarized in API.md.
EASE_CM = {
    "chest": {"slim": 6.0, "regular": 8.0, "relaxed": 10.0, "oversized": 14.0},
    "waist": {"slim": 4.0, "regular": 6.0, "relaxed": 8.0, "oversized": 12.0},
    "hip": {"slim": 4.0, "regular": 6.0, "relaxed": 8.0, "oversized": 10.0},
    "shoulder": {"slim": 1.0, "regular": 2.0, "relaxed": 3.0, "oversized": 4.0},
    "sleeve": {"slim": 1.0, "regular": 2.0, "relaxed": 3.0, "oversized": 3.0},
}
TOLERANCE_CM = 4.0
CONFIDENCE_FLOOR = 0.5

NOT_MEASURABLE_NOTE = "not measurable from one photo"
NO_COUNTERPART_NOTE = "no honest body counterpart — shown, never scored"


def _slot(category: str) -> str | None:
    if category in TOPS:
        return "top"
    if category in BOTTOMS:
        return "bottom"
    if category in ONE_PIECES:
        return "one_piece"
    return None


def _measurements(body_profile: dict) -> dict[str, float | None]:
    body = body_profile.get("body") or {}
    raw = body.get("measurements_cm") or {}
    return {
        "shoulder": raw.get("shoulder"),
        "hip": raw.get("hip"),
        "arm": raw.get("arm"),
    }


def recommend_size(
    *,
    category: str,
    fit_type: str,
    body_profile: dict,
    rows: list[dict],
    brand: str = "",
) -> dict:
    if category in SHOES:
        raise AtelierError(
            FailureState.INSUFFICIENT_DATA,
            "Footwear needs a foot length, which the body scan does not "
            "measure. Size shoes against a real foot measurement.",
        )
    slot = _slot(category)
    if slot is None:
        raise AtelierError(
            FailureState.NO_SIZE_CHART,
            f"No size model exists for '{category}' — the engine sizes "
            "tops, bottoms and one-pieces.",
        )

    sized = [r for r in rows if any(r.get(region) is not None for region in REGION_ORDER)]
    if len(sized) < 2:
        raise AtelierError(
            FailureState.NO_SIZE_CHART,
            "A size chart needs at least two sizes with centimetre values.",
        )

    relevant = RELEVANT_REGIONS[slot]
    body = _measurements(body_profile)

    def measured(region: str) -> float | None:
        source = BODY_SOURCE[region]
        return body.get(source) if source else None

    scored = []
    for row in sized:
        provided = [r for r in relevant if row.get(r) is not None]
        usable = [r for r in provided if measured(r) is not None]
        if not usable:
            scored.append((row["label"], 0.0, provided, usable))
            continue
        total = 0.0
        for region in usable:
            target = measured(region) + EASE_CM[region][fit_type]
            delta = abs(row[region] - target)
            total += max(0.0, 1.0 - delta / TOLERANCE_CM)
        scored.append((row["label"], total / len(usable), provided, usable))

    # Deterministic tie-break: first row in chart order wins.
    best_label, best_score, provided_best, best_usable = max(
        scored, key=lambda s: (s[1], -scored.index(s))
    )
    coverage = len(best_usable) / len(provided_best) if provided_best else 0.0
    if not best_usable:
        raise AtelierError(
            FailureState.INSUFFICIENT_DATA,
            "The chart's regions ("
            + ", ".join(provided_best)
            + ") have no measurable body input — the scan reads shoulder, "
              "hip and arm only.",
        )

    confidence = round(0.7 * best_score + 0.3 * coverage, 3)
    flags = []
    if confidence < CONFIDENCE_FLOOR:
        flags.append(FailureState.LOW_CONFIDENCE.value)

    best_row = next(r for r in sized if r["label"] == best_label)
    regions = []
    for region in relevant + (("length",) if best_row.get("length") is not None else ()):
        m = measured(region)
        c = best_row.get(region)
        entry = {"region": region, "measured_cm": m, "chart_cm": c}
        if m is None and c is not None:
            entry["status"] = "not_measurable"
            entry["note"] = (
                NO_COUNTERPART_NOTE if region == "length" else NOT_MEASURABLE_NOTE
            )
        elif c is None:
            entry["status"] = "not_provided"
        else:
            delta = round(c - (m + EASE_CM[region][fit_type]), 1)
            entry["delta_cm"] = delta
            entry["status"] = "matched" if abs(delta) <= TOLERANCE_CM else "off"
        regions.append(entry)

    unmeasured = [r for r in relevant if measured(r) is None and any(
        row.get(r) is not None for row in sized)]
    note = ""
    if unmeasured:
        note = (
            "Scored without " + ", ".join(unmeasured) + " ("
            + NOT_MEASURABLE_NOTE + "); those regions are listed, not guessed."
        )

    return {
        "recommended": {"label": best_label, "score": round(best_score, 3)},
        "confidence": confidence,
        "flags": flags,
        "fit_type": fit_type,
        "brand": brand,
        "regions": regions,
        "sizes": [
            {"label": label, "score": round(score, 3)} for label, score, _, _ in scored
        ],
        "note": note,
    }
