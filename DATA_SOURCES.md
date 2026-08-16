# Data Sources

**Catalog / merchant data: none connected yet. Weather: Open-Meteo (Phase 3).**

Atelier's catalog, weather, and other external data must come from official
APIs, affiliate feeds, or licensed merchant data only (AGENTS.md rule 4).
Until a source is genuinely connected, the app returns the honest failure
states from `docs/PRODUCT_SPEC.md §12` (`CATALOG_NOT_CONNECTED`,
`WEATHER_UNAVAILABLE`, …) instead of any substitute.

When a source is connected, record it here: provider, API/feed, license or
agreement terms, freshness guarantees, and which feature consumes it.

## Open-Meteo — live weather (Phase 3)

| | |
|---|---|
| Provider | Open-Meteo (open-meteo.com) |
| Endpoint | `GET https://api.open-meteo.com/v1/forecast` with `current=temperature_2m,precipitation,weather_code,wind_speed_10m` |
| Auth | Keyless, free for non-commercial use (Open-Meteo terms; commercial use requires attribution/licensing — revisit before monetization) |
| Freshness | Current-conditions forecast; `observed_at` is echoed from the response, never invented |
| Consumer | `POST /recommend/outfit` — the Weather factor (6 base weight) |
| Failure mode | Unreachable/non-200 after 3 attempts → `weather.state = "WEATHER_UNAVAILABLE"`, Weather factor inactive, recommendation still returned. Never a canned temperature. |
| Test override | `WEATHER_BASE_URL` env var points the service at any base URL (the failure test uses a genuinely unreachable address — nothing is stubbed) |

The app's place picker ships a small bundled list of reference city
coordinates (Casablanca, Rabat, Paris, London, New York, Dubai) plus manual
lat/lon entry — an explicit user choice, not geocoding.

## FASHN — hosted virtual try-on (Phase 4)

| | |
|---|---|
| Provider | FASHN (fashn.ai), hosted `tryon-max` model |
| Endpoint | `POST https://api.fashn.ai/v1/run` then poll `GET /v1/status/{id}` (contract verified 2026-08-16 against docs.fashn.ai) |
| Auth | `Authorization: Bearer` key from `FASHN_API_KEY`; paid credits, no free tier |
| License/terms | Proprietary hosted API — the integration path sanctioned by `docs/PRODUCT_SPEC.md` §7 for MVP (no self-hosted GPU diffusion on CPU-only infrastructure) |
| Consumer | `POST /tryon/render` — renders the person photo wearing the garment photo |
| Honesty | Result is always labeled `method: image_based_vton` + provider; confidence is **computed**, not claimed: fashionCLIP cosine similarity between the source garment photo and the render (below 0.25 the render is shown but flagged `LOW_CONFIDENCE`) |
| Failure mode | No key → `MODEL_MISSING` (nothing rendered, no substitute). 401 → `MODEL_MISSING`, 429 → `RATE_LIMITED`, 400/`ImageLoadError` → `POOR_IMAGE`, 5xx/`failed` → `MODEL_FAILED`, unreachable → `NETWORK_ERROR` |
| Test override | `FASHN_BASE_URL` env var points the adapter at any base URL (tests run a local protocol stub; every number in the response is still computed from real fixture images) |

## Test fixtures (Phase 1 + 2 + 3) — real photos, real provenance

The backend test suite (`backend/tests/fixtures/`) runs on real, openly
licensed photographs — never user data, never synthetic stand-ins presented
as results. Machine-readable provenance: `provenance.json` in the same
directory.

| Fixture | Source | License | Credit |
|---|---|---|---|
| body_person.jpg | [Jumping surfer (Unsplash)](https://commons.wikimedia.org/wiki/File%3AJumping_surfer_%28Unsplash%29.jpg) | CC0 | Julie Macey (jules144) |
| body_yoga.jpg | [Chakrasana wheel pose yoga](https://commons.wikimedia.org/wiki/File%3AChakrasana_wheel_pose_yoga.jpg) | CC BY 2.0 | Perzonseo Webbyra |
| face_portrait.jpg | [Boy Face from Venezuela](https://commons.wikimedia.org/wiki/File%3ABoy_Face_from_Venezuela.jpg) | CC0 | Wilfredor |
| landscape.jpg | [An Alpine Landscape NZ](https://commons.wikimedia.org/wiki/File%3AAn_Alpine_Landscape_NZ.jpg) | CC0 | Bernard Spragg, NZ |
| garment_hanger.jpg | [White dressers on hangers (Unsplash)](https://commons.wikimedia.org/wiki/File%3AWhite_dressers_on_hangers_%28Unsplash%29.jpg) | CC0 | Celia Michon (celiamichon) |
| garment_checkered.jpg | [Checkered Sweater H&M](https://commons.wikimedia.org/wiki/File%3ACheckered_Sweater_H%26M.jpg) | CC BY-SA 4.0 | Kauey |
| garment_jeans.jpg | [Women's Levi's jeans inside out](https://commons.wikimedia.org/wiki/File%3AWomen%27s_Levi%27s_jeans_inside_out.jpg) | CC BY-SA 4.0 | 1Veertje |
| garment_sneakers.jpg | [2023 Adidas Yeezy 350 V2 EF2905 (1)](https://commons.wikimedia.org/wiki/File%3A2023_Adidas_Yeezy_350_V2_EF2905_(1).jpg) | CC BY-SA 4.0 | Jacek Halicki |

These are **fixtures**, committed under the `.gitignore` exception for
`backend/tests/fixtures/`. AGENTS.md rule 7's ban on committing raw user
images is unaffected: user captures exist only in request memory and are
never written to disk (BUILD_PLAN §5).
