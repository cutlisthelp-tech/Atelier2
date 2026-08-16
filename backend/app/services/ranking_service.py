"""Phase 3 deterministic ranking engine (PRODUCT_SPEC §6).

Stage-1 flat weighted sum. Every subscore is computed from real inputs only
(real garment analyses, real profiles, real weather); factors without a data
source are INACTIVE and their weight is redistributed deterministically —
never fabricated. Explanations are templates bound to real score components.
"""

from . import occasion_service as occ

BASE_WEIGHTS: dict[str, float] = {
    "body_fit": 18.0,
    "proportion": 14.0,
    "style": 14.0,
    "color_harmony": 12.0,
    "occasion": 10.0,
    "user_preference": 8.0,
    "appearance": 8.0,
    "weather": 6.0,
    "trend": 6.0,
    "budget": 4.0,
}

INACTIVE_REASONS = {
    "user_preference": "no feedback has been recorded yet",
    "trend": "no trend feed is connected",
    "budget": "photographed garments carry no prices",
}


def _cat(entry: dict) -> str | None:
    return entry["garment"]["category"]["value"]


def _fit(entry: dict) -> str | None:
    return entry["garment"]["fit"]["value"]


def _material(entry: dict) -> str | None:
    return entry["garment"]["material"]["value"]


def _pattern(entry: dict) -> str | None:
    return entry["garment"]["pattern"]["value"]


def _colors(entry: dict) -> list[dict]:
    return entry["garment"]["colors"]


def _hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
    h = hex_str.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def _rgb_distance(a: str, b: str) -> float:
    ra, ga, ba = _hex_to_rgb(a)
    rb, gb, bb = _hex_to_rgb(b)
    return ((ra - rb) ** 2 + (ga - gb) ** 2 + (ba - bb) ** 2) ** 0.5


def hard_filter(
    wardrobe: list[dict], style_profile: dict
) -> tuple[list[dict], list[dict], str]:
    """Apply §6 hard filters before ranking. Returns (kept, excluded, note)."""
    banned_colors = {c.strip().lower() for c in style_profile.get("banned_colors", []) if c.strip()}
    banned_brands = [b.strip().lower() for b in style_profile.get("banned_brands", []) if b.strip()]
    kept, excluded = [], []
    for entry in wardrobe:
        names = {c["name"].lower() for c in _colors(entry)}
        hit = banned_colors & names
        if hit:
            excluded.append(
                {"id": entry["id"], "reason": f"contains banned color(s): {', '.join(sorted(hit))}"}
            )
        else:
            kept.append(entry)
    if banned_brands:
        note = (
            "banned_brands recorded but not applied: photographed garments "
            "carry no brand attribute yet"
        )
    else:
        note = "no banned brands recorded"
    if style_profile.get("budget_ceiling") is not None:
        note += "; budget_ceiling not applied: photographed garments carry no prices"
    return kept, excluded, note


def active_factors(color_profile: dict | None, weather: dict) -> dict[str, tuple[bool, str | None]]:
    factors: dict[str, tuple[bool, str | None]] = {}
    for name in BASE_WEIGHTS:
        if name in INACTIVE_REASONS:
            factors[name] = (False, INACTIVE_REASONS[name])
        elif name == "appearance":
            if color_profile is None:
                factors[name] = (False, "no appearance profile was provided")
            else:
                factors[name] = (True, None)
        elif name == "weather":
            if weather.get("state") != "ok":
                factors[name] = (False, "WEATHER_UNAVAILABLE")
            else:
                factors[name] = (True, None)
        else:
            factors[name] = (True, None)
    return factors


def context_weights(weather: dict) -> dict[str, float]:
    """Phase 6 depth: harsh conditions push the Weather factor harder —
    base weight scales by (1 + severity), documented in API.md. Base weights
    in the report stay the §6 table; effective weights carry the scaling."""
    weights = dict(BASE_WEIGHTS)
    weights["weather"] = BASE_WEIGHTS["weather"] * (1.0 + occ.weather_severity(weather))
    return weights


def effective_weights(
    factors: dict[str, tuple[bool, str | None]],
    weights: dict[str, float] | None = None,
) -> dict[str, float]:
    weights = weights if weights is not None else BASE_WEIGHTS
    active_sum = sum(w for name, w in weights.items() if factors[name][0])
    out = {}
    for name, w in weights.items():
        if factors[name][0]:
            out[name] = w * 100.0 / active_sum
        else:
            out[name] = 0.0
    return out


def _score_body_fit(outfit: list[dict], style_profile: dict) -> float:
    pref = style_profile.get("fit_preference") or "regular"
    pref_idx = occ.FIT_SCALE.index(pref) if pref in occ.FIT_SCALE else 1
    values = []
    for entry in outfit:
        fit = _fit(entry)
        if fit is None or fit not in occ.FIT_SCALE:
            values.append(0.5)
        else:
            values.append(1.0 - abs(occ.FIT_SCALE.index(fit) - pref_idx) / 3.0)
    return sum(values) / len(values)


def _balance_term(body_profile: dict) -> float:
    proportions = (body_profile or {}).get("body", {}).get("proportions", {}) or {}
    torso_leg = proportions.get("torso_to_leg_ratio")
    shoulder_hip = proportions.get("shoulder_to_hip_ratio")
    term = 0.6
    if torso_leg is not None:
        # Documented ideal: legs slightly longer than the torso.
        term = 1.0 - min(abs(torso_leg - 0.6) / 0.4, 1.0) * 0.3
    if shoulder_hip is not None:
        # Documented ideal: shoulders and hips in balance.
        term -= min(abs(shoulder_hip - 1.0) / 0.6, 1.0) * 0.3
    return max(0.0, min(1.0, term))


def _score_proportion(outfit: list[dict], body_profile: dict) -> float:
    tops = [e for e in outfit if _cat(e) in ("t-shirt", "shirt", "blouse", "sweater", "hoodie")]
    bottoms = [e for e in outfit if _cat(e) in ("jeans", "trousers", "shorts", "skirt")]
    one_pieces = [e for e in outfit if _cat(e) in ("dress", "suit")]
    if one_pieces:
        pair = occ.ONE_PIECE_PROPORTION
    elif tops and bottoms:
        tf, bf = _fit(tops[0]), _fit(bottoms[0])
        if tf in occ.FIT_SCALE and bf in occ.FIT_SCALE:
            pair = occ.PROPORTION_PAIR_SCORES[(tf, bf)]
        else:
            pair = occ.PROPORTION_UNKNOWN
    else:
        pair = occ.PROPORTION_UNKNOWN
    base = 0.6 * pair + 0.4 * _balance_term(body_profile)
    shape = (body_profile or {}).get("body", {}).get("body_shape")
    deltas = occ.BODY_SHAPE_CATEGORY_MODIFIERS.get(shape or "", {})
    if deltas:
        base += sum(deltas.get(_cat(e) or "", 0.0) for e in outfit) / len(outfit)
    return max(0.0, min(1.0, base))


def _score_style(outfit: list[dict], style_profile: dict) -> float:
    aesthetics = style_profile.get("aesthetics") or []
    if not aesthetics:
        return 0.5
    values = []
    for entry in outfit:
        cat = _cat(entry) or ""
        hit = any(cat in occ.AESTHETIC_CATEGORY_AFFINITY.get(a, frozenset()) for a in aesthetics)
        values.append(1.0 if hit else 0.5)
    return sum(values) / len(values)


def _distinct_non_neutral(outfit: list[dict]) -> set[str]:
    names = set()
    for entry in outfit:
        for c in _colors(entry):
            if c["name"].lower() not in occ.NEUTRAL_COLOR_NAMES:
                names.add(c["name"].lower())
    return names


def _score_color_harmony(outfit: list[dict]) -> float:
    distinct = _distinct_non_neutral(outfit)
    n = len(distinct)
    if n == 0:
        return 0.9
    if n == 1:
        return 0.85
    if n == 2:
        return 1.0
    if n == 3:
        return 0.8
    return 0.5


def _score_occasion(outfit: list[dict], occasion: str) -> float:
    """Phase 6 depth: category suitability (70%) plus how comfortably each
    piece's pattern/fit sit within the occasion's formality (30%)."""
    values = []
    for entry in outfit:
        base = occ.occasion_suitability(occasion, _cat(entry) or "")
        form = occ.formality_piece(occasion, _pattern(entry), _fit(entry))
        values.append(0.7 * base + 0.3 * form)
    return sum(values) / len(values)


def _score_appearance(outfit: list[dict], color_profile: dict | None) -> float:
    palette = [s["hex"] for s in color_profile["color"]["palette"]]
    values = []
    for entry in outfit:
        piece = 0.0
        for c in _colors(entry):
            dist = min(_rgb_distance(c["hex"], p) for p in palette)
            piece += c["share"] * (1.0 - min(dist, 300.0) / 300.0)
        values.append(piece)
    return sum(values) / len(values)


def _score_weather(outfit: list[dict], weather: dict) -> float:
    temp = weather.get("temperature_c")
    precip = weather.get("precipitation_mm")
    values = []
    for entry in outfit:
        mat = occ.material_temp_score(_material(entry), temp) if temp is not None else 0.6
        cat = occ.category_temp_score(_cat(entry) or "", temp, precip)
        values.append((mat + cat) / 2.0)
    return sum(values) / len(values)


def score_outfit(
    outfit: list[dict],
    *,
    occasion: str,
    body_profile: dict,
    color_profile: dict | None,
    style_profile: dict,
    weather: dict,
) -> dict:
    """Score one candidate outfit; returns the full factor report + total."""
    factors = active_factors(color_profile, weather)
    weights = effective_weights(factors, context_weights(weather))
    subscores = {
        "body_fit": _score_body_fit(outfit, style_profile),
        "proportion": _score_proportion(outfit, body_profile),
        "style": _score_style(outfit, style_profile),
        "color_harmony": _score_color_harmony(outfit),
        "occasion": _score_occasion(outfit, occasion),
        "user_preference": 0.0,
        "appearance": _score_appearance(outfit, color_profile) if color_profile else 0.0,
        "weather": _score_weather(outfit, weather) if weather.get("state") == "ok" else 0.0,
        "trend": 0.0,
        "budget": 0.0,
    }
    report = []
    total = 0.0
    for name in BASE_WEIGHTS:
        active, reason = factors[name]
        contribution = weights[name] * subscores[name] if active else 0.0
        total += contribution
        report.append(
            {
                "name": name,
                "base_weight": BASE_WEIGHTS[name],
                "effective_weight": round(weights[name], 1),
                "active": active,
                "inactive_reason": reason,
                "score": round(subscores[name], 3),
                "contribution": round(contribution, 1),
            }
        )
    return {
        "score": round(total, 1),
        "factors": report,
        "why": explain(outfit, report, occasion, color_profile, weather),
    }


def explain(
    outfit: list[dict],
    report: list[dict],
    occasion: str,
    color_profile: dict | None,
    weather: dict,
) -> list[str]:
    cats = [_cat(e) or "piece" for e in outfit]
    templates = {
        "occasion": lambda f: (
            f"Right for {occasion}: {', '.join(cats)} rate "
            f"{f['score']:.0%} on the occasion table."
        ),
        "body_fit": lambda f: (
            f"Fit tracks your preference ({f['score']:.0%} across the pieces)."
        ),
        "proportion": lambda f: f"Silhouette balance scores {f['score']:.0%}.",
        "style": lambda f: f"Matches your stated aesthetics ({f['score']:.0%}).",
        "color_harmony": lambda f: (
            f"Colors hold together: {len(_distinct_non_neutral(outfit))} distinct "
            f"hue(s) plus neutrals ({f['score']:.0%})."
        ),
        "appearance": lambda f: (
            f"Sits close to your {color_profile['color']['season']} palette "
            f"({f['score']:.0%} color closeness)."
        ),
        "weather": lambda f: (
            f"Suited to {weather['temperature_c']}°C, {weather['weather_label']} "
            f"({f['score']:.0%})."
        ),
    }
    active = [f for f in report if f["active"] and f["contribution"] >= 4.0]
    active.sort(key=lambda f: (-f["contribution"], f["name"]))
    lines = [templates[f["name"]](f) for f in active[:3] if f["name"] in templates]
    inactive = [f["name"] for f in report if not f["active"]]
    if inactive:
        lines.append(
            "Scored without: "
            + ", ".join(f"{n} ({next(r['inactive_reason'] for r in report if r['name'] == n)})" for n in inactive)
            + "; weights redistributed over the active factors."
        )
    return lines


def _factor_score(result: dict, name: str) -> float:
    return next(f for f in result["factors"] if f["name"] == name)["score"]


def _distinctiveness(entry: dict) -> float:
    pattern = _pattern(entry)
    distinct = 0.0
    if pattern is not None and pattern != "solid":
        distinct += 0.5
    distinct += 0.5 * min(len(_distinct_non_neutral([entry])), 2) / 2.0
    return distinct


def _boldness(entry: dict) -> float:
    return float(len(_distinct_non_neutral([entry])))


def select_alternatives(
    candidates: list[dict], scored: dict[str, dict]
) -> list[dict]:
    """§6 alternatives #1-#4. Never pads: returns only distinct outfits that exist."""
    by_score = sorted(
        candidates,
        key=lambda c: (
            -scored[c["key"]]["score"],
            -_factor_score(scored[c["key"]], "occasion"),
            c["key"],
        ),
    )
    picked: list[dict] = []
    if not by_score:
        return picked
    picked.append({**by_score[0], "strategy": "best_match"})

    remaining = [c for c in by_score if c["key"] != picked[0]["key"]]
    if remaining:
        safer = max(
            remaining,
            key=lambda c: (
                (
                    _factor_score(scored[c["key"]], "occasion")
                    + _factor_score(scored[c["key"]], "body_fit")
                )
                / 2,
                scored[c["key"]]["score"],
            ),
        )
        picked.append({**safer, "strategy": "safer"})

    remaining = [c for c in remaining if c["key"] not in {p["key"] for p in picked}]
    if remaining:
        patterned = [
            c for c in remaining if any(_pattern(e) not in (None, "solid") for e in c["entries"])
        ]
        if patterned:
            trend = max(
                patterned,
                key=lambda c: (sum(_distinctiveness(e) for e in c["entries"]), scored[c["key"]]["score"]),
            )
        else:
            trend = remaining[0]
        picked.append({**trend, "strategy": "trend_forward"})

    remaining = [c for c in remaining if c["key"] not in {p["key"] for p in picked}]
    if remaining:
        bold = max(
            remaining,
            key=lambda c: (sum(_boldness(e) for e in c["entries"]), scored[c["key"]]["score"]),
        )
        picked.append({**bold, "strategy": "bold"})
    return picked
