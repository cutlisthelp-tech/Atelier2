# Data Sources

**Catalog / weather / merchant data: none connected yet.**

Atelier's catalog, weather, and other external data must come from official
APIs, affiliate feeds, or licensed merchant data only (AGENTS.md rule 4).
Until a source is genuinely connected, the app returns the honest failure
states from `docs/PRODUCT_SPEC.md §12` (`CATALOG_NOT_CONNECTED`,
`WEATHER_UNAVAILABLE`, …) instead of any substitute.

When a source is connected, record it here: provider, API/feed, license or
agreement terms, freshness guarantees, and which feature consumes it.

## Test fixtures (Phase 1 + 2) — real photos, real provenance

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

These are **fixtures**, committed under the `.gitignore` exception for
`backend/tests/fixtures/`. AGENTS.md rule 7's ban on committing raw user
images is unaffected: user captures exist only in request memory and are
never written to disk (BUILD_PLAN §5).
