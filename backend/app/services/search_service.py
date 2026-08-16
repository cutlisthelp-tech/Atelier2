"""Find-This-Look visual search — Phase 8 (PRODUCT_SPEC §9).

Screenshot → real fashionCLIP embedding → tiered nearest-neighbor matches
against a real indexed collection (the user's photographed wardrobe; no
merchant catalog is connected, and that is said plainly). Nothing clears
the similarity floor → NO_MATCH_FOUND, never a fabricated closest guess.
"""

from app import config
from app.errors import AtelierError, FailureState
from app.services import garment_service, imaging
from app.services.vector_index import PgVectorIndex, StatelessCosineIndex

# Documented similarity tiers (§9): below the floor there is no match at all.
EXACT_MATCH_MIN = 0.92
CLOSE_MATCH_MIN = 0.80
INSPIRED_MIN = 0.68

CATALOG_NOTE = (
    "No merchant catalog is connected — merchant tiers stay unavailable."
)


def tier_for(sim: float) -> str | None:
    if sim >= EXACT_MATCH_MIN:
        return "exact_match"
    if sim >= CLOSE_MATCH_MIN:
        return "close_match"
    if sim >= INSPIRED_MIN:
        return "inspired"
    return None


def search_similar(query_bytes: bytes, candidates: list[dict]) -> dict:
    if not candidates:
        raise AtelierError(
            FailureState.INSUFFICIENT_DATA,
            "The wardrobe index is empty — photograph pieces first.",
        )

    img = imaging.decode(query_bytes)
    imaging.quality_gate(img)
    vector = garment_service.image_embedding(img)

    url = config.database_url()
    if url:
        try:
            index = PgVectorIndex(url)
            index.seed(candidates)
        except RuntimeError as exc:
            raise AtelierError(FailureState.MODEL_FAILED, str(exc))
    else:
        index = StatelessCosineIndex(candidates)

    ranked = index.nearest(list(vector), limit=len(candidates))
    matches = []
    for item_id, sim in ranked:
        tier = tier_for(sim)
        if tier is None:
            continue
        matches.append(
            {"id": item_id, "similarity": round(max(0.0, sim), 3), "tier": tier}
        )

    return {
        "state": "ok" if matches else "NO_MATCH_FOUND",
        "matches": matches,
        "index": index.name,
        "method": "fashionclip_cosine",
        "tiers": {
            "exact_match": EXACT_MATCH_MIN,
            "close_match": CLOSE_MATCH_MIN,
            "inspired": INSPIRED_MIN,
        },
        "catalog": {
            "same_product_other_merchant": "CATALOG_NOT_CONNECTED",
            "budget_alternative": "CATALOG_NOT_CONNECTED",
            "note": CATALOG_NOTE,
        },
        "message": ""
        if matches
        else "No match found — nothing in the index clears the similarity floor.",
    }
