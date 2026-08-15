"""Phase 3 deterministic context tables.

These tables are *configuration*, in the same status as the season palettes
and zero-shot prompt sets: they encode styling conventions the ranking engine
applies, and they never fabricate a measurement, price, or weather value.
Every value is documented here and summarized in API.md.
"""

# PRODUCT_SPEC §5.4 fixed occasion taxonomy.
OCCASIONS = (
    "casual lunch",
    "university",
    "office",
    "interview",
    "wedding",
    "date",
    "dinner",
    "party",
    "travel",
    "beach",
    "gym",
    "shopping",
    "formal",
)

# The Phase 2 category taxonomy, verbatim.
CATEGORIES = (
    "dress", "t-shirt", "shirt", "blouse", "sweater", "hoodie", "jacket",
    "coat", "jeans", "trousers", "shorts", "skirt", "suit", "shoes",
    "sneakers", "boots", "bag", "hat", "scarf", "belt",
)

# Suitability of each category for each occasion: 1.0 appropriate,
# 0.5 acceptable, 0.0 inappropriate. Every occasion lists all 20 categories.
OCCASION_CATEGORY_SUITABILITY: dict[str, dict[str, float]] = {
    "casual lunch": {
        "dress": 1.0, "t-shirt": 1.0, "shirt": 1.0, "blouse": 1.0,
        "sweater": 1.0, "hoodie": 0.5, "jacket": 1.0, "coat": 0.5,
        "jeans": 1.0, "trousers": 0.5, "shorts": 1.0, "skirt": 1.0,
        "suit": 0.0, "shoes": 1.0, "sneakers": 1.0, "boots": 0.5,
        "bag": 1.0, "hat": 0.5, "scarf": 0.5, "belt": 0.5,
    },
    "university": {
        "dress": 0.5, "t-shirt": 1.0, "shirt": 0.5, "blouse": 0.5,
        "sweater": 1.0, "hoodie": 1.0, "jacket": 1.0, "coat": 0.5,
        "jeans": 1.0, "trousers": 0.5, "shorts": 1.0, "skirt": 0.5,
        "suit": 0.0, "shoes": 0.5, "sneakers": 1.0, "boots": 0.5,
        "bag": 1.0, "hat": 0.5, "scarf": 0.5, "belt": 0.5,
    },
    "office": {
        "dress": 1.0, "t-shirt": 0.0, "shirt": 1.0, "blouse": 1.0,
        "sweater": 1.0, "hoodie": 0.0, "jacket": 1.0, "coat": 0.5,
        "jeans": 0.5, "trousers": 1.0, "shorts": 0.0, "skirt": 1.0,
        "suit": 1.0, "shoes": 1.0, "sneakers": 0.0, "boots": 0.5,
        "bag": 1.0, "hat": 0.0, "scarf": 0.5, "belt": 1.0,
    },
    "interview": {
        "dress": 0.5, "t-shirt": 0.0, "shirt": 1.0, "blouse": 1.0,
        "sweater": 0.5, "hoodie": 0.0, "jacket": 1.0, "coat": 0.5,
        "jeans": 0.0, "trousers": 1.0, "shorts": 0.0, "skirt": 1.0,
        "suit": 1.0, "shoes": 1.0, "sneakers": 0.0, "boots": 0.0,
        "bag": 1.0, "hat": 0.0, "scarf": 0.5, "belt": 1.0,
    },
    "wedding": {
        "dress": 1.0, "t-shirt": 0.0, "shirt": 1.0, "blouse": 1.0,
        "sweater": 0.0, "hoodie": 0.0, "jacket": 1.0, "coat": 0.5,
        "jeans": 0.0, "trousers": 1.0, "shorts": 0.0, "skirt": 1.0,
        "suit": 1.0, "shoes": 1.0, "sneakers": 0.0, "boots": 0.0,
        "bag": 1.0, "hat": 0.5, "scarf": 0.5, "belt": 0.5,
    },
    "date": {
        "dress": 1.0, "t-shirt": 0.5, "shirt": 1.0, "blouse": 1.0,
        "sweater": 1.0, "hoodie": 0.0, "jacket": 1.0, "coat": 0.5,
        "jeans": 1.0, "trousers": 1.0, "shorts": 0.5, "skirt": 1.0,
        "suit": 0.5, "shoes": 1.0, "sneakers": 0.5, "boots": 1.0,
        "bag": 1.0, "hat": 0.5, "scarf": 0.5, "belt": 0.5,
    },
    "dinner": {
        "dress": 1.0, "t-shirt": 0.0, "shirt": 1.0, "blouse": 1.0,
        "sweater": 1.0, "hoodie": 0.0, "jacket": 1.0, "coat": 0.5,
        "jeans": 0.5, "trousers": 1.0, "shorts": 0.0, "skirt": 1.0,
        "suit": 1.0, "shoes": 1.0, "sneakers": 0.0, "boots": 0.5,
        "bag": 1.0, "hat": 0.0, "scarf": 0.5, "belt": 0.5,
    },
    "party": {
        "dress": 1.0, "t-shirt": 0.5, "shirt": 1.0, "blouse": 1.0,
        "sweater": 0.5, "hoodie": 0.5, "jacket": 1.0, "coat": 0.5,
        "jeans": 1.0, "trousers": 0.5, "shorts": 0.5, "skirt": 1.0,
        "suit": 0.5, "shoes": 1.0, "sneakers": 1.0, "boots": 1.0,
        "bag": 1.0, "hat": 0.5, "scarf": 0.0, "belt": 0.5,
    },
    "travel": {
        "dress": 0.5, "t-shirt": 1.0, "shirt": 1.0, "blouse": 0.5,
        "sweater": 1.0, "hoodie": 1.0, "jacket": 1.0, "coat": 0.5,
        "jeans": 1.0, "trousers": 1.0, "shorts": 1.0, "skirt": 0.5,
        "suit": 0.0, "shoes": 0.5, "sneakers": 1.0, "boots": 0.5,
        "bag": 1.0, "hat": 1.0, "scarf": 0.5, "belt": 0.5,
    },
    "beach": {
        "dress": 1.0, "t-shirt": 1.0, "shirt": 0.5, "blouse": 0.5,
        "sweater": 0.0, "hoodie": 0.0, "jacket": 0.0, "coat": 0.0,
        "jeans": 0.0, "trousers": 0.0, "shorts": 1.0, "skirt": 1.0,
        "suit": 0.0, "shoes": 1.0, "sneakers": 0.0, "boots": 0.0,
        "bag": 1.0, "hat": 1.0, "scarf": 0.0, "belt": 0.0,
    },
    "gym": {
        "dress": 0.0, "t-shirt": 1.0, "shirt": 0.0, "blouse": 0.0,
        "sweater": 0.0, "hoodie": 0.5, "jacket": 0.5, "coat": 0.0,
        "jeans": 0.0, "trousers": 0.5, "shorts": 1.0, "skirt": 0.0,
        "suit": 0.0, "shoes": 0.5, "sneakers": 1.0, "boots": 0.0,
        "bag": 1.0, "hat": 0.5, "scarf": 0.0, "belt": 0.0,
    },
    "shopping": {
        "dress": 1.0, "t-shirt": 1.0, "shirt": 1.0, "blouse": 1.0,
        "sweater": 1.0, "hoodie": 1.0, "jacket": 1.0, "coat": 0.5,
        "jeans": 1.0, "trousers": 1.0, "shorts": 1.0, "skirt": 1.0,
        "suit": 0.0, "shoes": 1.0, "sneakers": 1.0, "boots": 1.0,
        "bag": 1.0, "hat": 0.5, "scarf": 0.5, "belt": 0.5,
    },
    "formal": {
        "dress": 1.0, "t-shirt": 0.0, "shirt": 1.0, "blouse": 1.0,
        "sweater": 0.0, "hoodie": 0.0, "jacket": 1.0, "coat": 0.5,
        "jeans": 0.0, "trousers": 1.0, "shorts": 0.0, "skirt": 1.0,
        "suit": 1.0, "shoes": 1.0, "sneakers": 0.0, "boots": 0.0,
        "bag": 1.0, "hat": 0.0, "scarf": 0.5, "belt": 1.0,
    },
}

# Comfort temperature bands (°C) per Phase 2 material label.
MATERIAL_TEMP_BANDS: dict[str, tuple[float, float]] = {
    "cotton": (15.0, 30.0),
    "denim": (10.0, 28.0),
    "leather": (5.0, 22.0),
    "wool knit": (0.0, 18.0),
    "silk/satin": (15.0, 30.0),
    "linen": (20.0, 40.0),
    "synthetic": (10.0, 25.0),
}

FIT_SCALE = ("slim", "regular", "relaxed", "oversized")

AESTHETIC_CATEGORY_AFFINITY: dict[str, frozenset[str]] = {
    "minimal": frozenset({"t-shirt", "shirt", "trousers", "sweater", "coat", "shoes"}),
    "classic": frozenset({"shirt", "blouse", "trousers", "skirt", "dress", "suit", "shoes", "belt"}),
    "streetwear": frozenset({"hoodie", "t-shirt", "jeans", "sneakers", "jacket", "hat"}),
    "workwear": frozenset({"jeans", "jacket", "boots", "shirt", "belt", "trousers"}),
    "avant-garde": frozenset({"coat", "dress", "boots", "jacket", "skirt"}),
    "sporty": frozenset({"t-shirt", "hoodie", "shorts", "sneakers", "jacket"}),
}

NEUTRAL_COLOR_NAMES = frozenset(
    {"black", "white", "gray", "charcoal", "light gray", "beige", "navy"}
)

# Small documented silhouette deltas per body shape (PRODUCT_SPEC §4 shapes).
BODY_SHAPE_CATEGORY_MODIFIERS: dict[str, dict[str, float]] = {
    "inverted_triangle": {"skirt": 0.1, "trousers": 0.05, "dress": 0.05},
    "triangle": {"dress": 0.1, "shirt": 0.05, "blouse": 0.05},
    "rectangle": {"dress": 0.05, "sweater": 0.05},
}

# Silhouette balance on (top fit, bottom fit) pairs.
PROPORTION_PAIR_SCORES: dict[tuple[str, str], float] = {
    ("slim", "slim"): 0.6, ("slim", "regular"): 0.8, ("slim", "relaxed"): 1.0,
    ("slim", "oversized"): 0.8, ("regular", "slim"): 0.8,
    ("regular", "regular"): 0.8, ("regular", "relaxed"): 0.9,
    ("regular", "oversized"): 0.8, ("relaxed", "slim"): 1.0,
    ("relaxed", "regular"): 0.9, ("relaxed", "relaxed"): 0.6,
    ("relaxed", "oversized"): 0.5, ("oversized", "slim"): 0.8,
    ("oversized", "regular"): 0.8, ("oversized", "relaxed"): 0.5,
    ("oversized", "oversized"): 0.4,
}
PROPORTION_UNKNOWN = 0.6
ONE_PIECE_PROPORTION = 0.8


def occasion_suitability(occasion: str, category: str) -> float:
    return OCCASION_CATEGORY_SUITABILITY[occasion].get(category, 0.5)


def material_temp_score(material: str | None, temperature_c: float) -> float:
    if material is None:
        return 0.6
    band = MATERIAL_TEMP_BANDS.get(material)
    if band is None:
        return 0.6
    lo, hi = band
    if lo <= temperature_c <= hi:
        return 1.0
    distance = lo - temperature_c if temperature_c < lo else temperature_c - hi
    return max(0.0, 1.0 - distance / 15.0)


def category_temp_score(
    category: str, temperature_c: float | None, precipitation_mm: float | None
) -> float:
    if temperature_c is None:
        return 0.6
    if category == "shorts":
        if temperature_c >= 20.0:
            return 1.0
        if temperature_c >= 15.0:
            return 0.4
        return 0.0
    if category in ("skirt", "dress"):
        return 1.0 if temperature_c >= 15.0 else 0.5
    if category == "coat":
        if temperature_c < 12.0:
            return 1.0
        return 0.6 if temperature_c < 18.0 else 0.2
    if category == "jacket":
        if temperature_c < 18.0:
            return 1.0
        return 0.6 if temperature_c < 24.0 else 0.3
    if category in ("sweater", "hoodie"):
        if temperature_c < 18.0:
            return 1.0
        return 0.5 if temperature_c < 24.0 else 0.2
    if precipitation_mm is not None and precipitation_mm > 0.0:
        if category == "boots":
            return 1.0
        if category == "shoes":
            return 0.8
        if category == "sneakers":
            return 0.6
    return 1.0
