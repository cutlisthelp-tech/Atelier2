"""Phase 3 recommendation orchestration.

Assembles candidate outfits from the user's real photographed garments,
fetches real weather, applies §6 hard filters, scores deterministically,
and reports every factor honestly. No catalog is connected, so the
shopping surface always carries CATALOG_NOT_CONNECTED.
"""

from app.errors import AtelierError, FailureState
from app.services import ranking_service, weather_service

MAX_CANDIDATES = 200
OUTERWEAR_TEMP_C = 18.0

TOPS = ("t-shirt", "shirt", "blouse", "sweater", "hoodie")
BOTTOMS = ("jeans", "trousers", "shorts", "skirt")
ONE_PIECES = ("dress", "suit")
SHOES = ("shoes", "sneakers", "boots")
OUTERWEAR = ("jacket", "coat")

CATALOG_MESSAGE = (
    "The catalog isn't connected yet — shopping links arrive when real "
    "product data does."
)


def _slot(category: str | None) -> str | None:
    if category in TOPS:
        return "top"
    if category in BOTTOMS:
        return "bottom"
    if category in ONE_PIECES:
        return "one_piece"
    if category in SHOES:
        return "shoes"
    if category in OUTERWEAR:
        return "outerwear"
    return None


def assemble_candidates(wardrobe: list[dict], weather: dict) -> tuple[list[dict], list[dict]]:
    """Returns (candidates, unplaceable). Each candidate: {key, entries, ids}."""
    slots: dict[str, list[dict]] = {"top": [], "bottom": [], "one_piece": [], "shoes": [], "outerwear": []}
    unplaceable = []
    for entry in wardrobe:
        category = entry["garment"]["category"]["value"]
        slot = _slot(category)
        if slot is None:
            unplaceable.append(
                {
                    "id": entry["id"],
                    "reason": "category could not be identified from the photo, "
                    "so it cannot be placed in an outfit",
                }
            )
        elif slot == "outerwear" and not _needs_outerwear(weather):
            continue
        else:
            slots[slot].append(entry)
    for slot in slots:
        slots[slot].sort(key=lambda e: (-e["confidence"], e["id"]))

    candidates: list[dict] = []

    def push(entries: list[dict]) -> bool:
        if len(candidates) >= MAX_CANDIDATES:
            return False
        ids = tuple(e["id"] for e in entries)
        candidates.append({"key": "+".join(ids), "ids": ids, "entries": entries})
        return True

    for shoes in slots["shoes"]:
        for one in slots["one_piece"]:
            base = [one, shoes]
            for outer in slots["outerwear"]:
                if not push(base + [outer]):
                    return candidates, unplaceable
            if not slots["outerwear"] and not push(base):
                return candidates, unplaceable
        for top in slots["top"]:
            for bottom in slots["bottom"]:
                base = [top, bottom, shoes]
                for outer in slots["outerwear"]:
                    if not push(base + [outer]):
                        return candidates, unplaceable
                if not slots["outerwear"] and not push(base):
                    return candidates, unplaceable
    return candidates, unplaceable


def _needs_outerwear(weather: dict) -> bool:
    if weather.get("state") != "ok":
        return True
    temp = weather.get("temperature_c")
    precip = weather.get("precipitation_mm") or 0.0
    return temp is None or temp < OUTERWEAR_TEMP_C or precip > 0.0


def wardrobe_gap_message(wardrobe: list[dict]) -> str:
    placeable = [e for e in wardrobe if _slot(e["garment"]["category"]["value"])]
    slots = {_slot(e["garment"]["category"]["value"]) for e in placeable}
    missing = []
    if "shoes" not in slots:
        missing.append("shoes or sneakers")
    if not ("top" in slots and "bottom" in slots) and "one_piece" not in slots:
        missing.append("a top and a bottom (or a dress)")
    return (
        "Not enough garments for an outfit yet. Photograph " + " and ".join(missing) + "."
    )


async def recommend(
    *,
    occasion: str,
    location: dict,
    body_profile: dict,
    color_profile: dict | None,
    style_profile: dict,
    wardrobe: list[dict],
) -> dict:
    weather = await weather_service.current_weather(
        location["latitude"], location["longitude"]
    )

    kept, hard_excluded, filters_note = ranking_service.hard_filter(wardrobe, style_profile)

    candidates, unplaceable = assemble_candidates(kept, weather)
    if not candidates:
        raise AtelierError(FailureState.INSUFFICIENT_DATA, wardrobe_gap_message(kept))

    scored = {
        c["key"]: ranking_service.score_outfit(
            c["entries"],
            occasion=occasion,
            body_profile=body_profile,
            color_profile=color_profile,
            style_profile=style_profile,
            weather=weather,
        )
        for c in candidates
    }

    alternatives = ranking_service.select_alternatives(candidates, scored)

    outfits = []
    for pick in alternatives:
        result = scored[pick["key"]]
        outfits.append(
            {
                "strategy": pick["strategy"],
                "score": result["score"],
                "garments": [
                    {
                        "id": e["id"],
                        "category": e["garment"]["category"]["value"],
                        "colors": e["garment"]["colors"],
                        "fit": e["garment"]["fit"]["value"],
                        "material": e["garment"]["material"]["value"],
                        "pattern": e["garment"]["pattern"]["value"],
                    }
                    for e in pick["entries"]
                ],
                "why": result["why"],
            }
        )

    return {
        "context": {
            "occasion": occasion,
            "place_label": location.get("label", ""),
            "weather": weather,
        },
        "factors": scored[alternatives[0]["key"]]["factors"],
        "outfits": outfits,
        "excluded": {
            "hard_filters": hard_excluded,
            "unplaceable": unplaceable,
            "filters_note": filters_note,
        },
        "shopping": {"state": "CATALOG_NOT_CONNECTED", "message": CATALOG_MESSAGE},
    }
