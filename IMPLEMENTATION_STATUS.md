# Implementation Status

Source of truth for what is *verified working*, per `docs/BUILD_PLAN.md §1`
— a phase is done only when its Definition of Done is demonstrated, not when
it compiles.

## Repository migration — 2026-08-16

The project migrated from `khalilblm2-droid/Atelier` to
`cutlisthelp-tech/Atelier2` (this repository), the canonical, official home
of Atelier. The old repository is **deprecated and frozen** at its
2026-08-16 state — do not pull further work from it. All phase evidence
recorded here was re-verified in this repository on the migration date (see
the 2026-08-16 entries below).

## Phase 0 — Infrastructure, feature flags, Model Manager skeleton, Diagnostics

**Status: VERIFIED — 2026-08-14**

Definition of Done: *app boots, every screen shows an honest empty state, zero
mock data anywhere.* (See commit history for the Phase 0 evidence record.)

## Phase 1 — Body + Appearance + Style Profile

**Status: VERIFIED — 2026-08-14**

Definition of Done: *a real photo produces a real BodyProfile + ColorProfile
with confidence, or an honest failure state.*

Evidence:

- `pytest` — 14/14 passed on **real CC0/CC-BY fixture photos** (provenance in
  `backend/tests/fixtures/`): person photo → real BodyProfile (shoulder/hip/
  torso/leg/arm measurements calibrated to entered height, real proportions,
  33-point skeleton, confidence 0.757, chest/waist honestly `null`); portrait
  → real ColorProfile (undertone/depth/contrast → season + palette,
  confidence 0.984); landscape → `NO_PERSON`; darkened photo → `POOR_IMAGE`;
  garbage bytes → `POOR_IMAGE`; height out of range → plain 422.
- Live `uvicorn` smoke — `GET /health`, `GET /models`, `POST /analysis/body`
  (real BodyProfile), `POST /analysis/appearance` on a landscape (honest
  `NO_PERSON`) all returned exactly those payloads.
- `flutter analyze` — no issues. `flutter test` — 9/9 passed: consent gate
  blocks scanning until granted, result screen renders real numbers and the
  honest `null`s, failure screen shows the §12 code, Style Profile
  round-trips through local JSON, diagnostics reports both registered models.
- `flutter build apk --debug` — `app-debug.apk` produced. On-device camera
  capture happens on the maintainer's Android/Termux flow; not claimed here.
- Mock-data audit — zero hardcoded scores/measurements in code paths; every
  number shown comes from a real model run or the user's own input.

Honest limits of this verification:

- Inference runs on **backend CPU** (recorded decision + on-device upgrade
  path in `ARCHITECTURE.md`), not on the phone.
- Camera capture itself is not exercised in Codespace; the pipeline is
  verified end-to-end from real photos through the same endpoints the app
  calls.
- Chest/waist measurements remain `null` by design — not inferable from a
  single 2D capture.

## Known deferrals (recorded, not silent)

On-device inference migration; full streaming Constellation Scan animation;
chest/waist depth measurements; Style Profile remote sync (Phase 9);
salient-object segmentation for busy flat-lay backgrounds (Phase 7/8);
garment embedding storage + pgvector indexing (Phase 8); full Wardrobe
module — Phase 3 persists analysis JSON only (Phase 7 owns the module);
Marqo-fashionSigLIP upgrade (Phase 8).

## Phase 2 — Garment Analysis

**Status: VERIFIED — 2026-08-15**

Definition of Done: *a garment photo returns real category/color/attributes,
or "Unknown".*

Evidence:

- Models re-verified per AGENTS.md rule 3 before integration:
  Marqo-fashionCLIP (Apache-2.0, active repo, public ONNX int8 weights,
  CPU-fast) selected; FASHN Human Parser rejected (NVIDIA SegFormer license);
  FashionSigLIP recorded as upgrade. Four new registry entries with real
  SHA-256 checksums; backend Model Manager lifecycle unchanged.
- `pytest` — 20/20 passed on **real fixture photos** (provenance in
  `backend/tests/fixtures/`): worn checkered sweater → real category
  `sweater` 0.818, real colors from the selfie_multiclass clothing mask
  (charcoal/white/gray), fit `oversized` (matches the photo's own Commons
  description), 512-dim embedding, confidence 0.846; dresses-on-hangers →
  garment present but category honestly `null` (0.445) with real colors;
  landscape → `INSUFFICIENT_DATA`; darkened photo → `POOR_IMAGE`; garbage
  bytes → `POOR_IMAGE`.
- Live `uvicorn` smoke — `POST /analysis/garment` on both fixtures and the
  landscape returned exactly the test payloads; `GET /models` reports all six
  models installed.
- `flutter analyze` — no issues. `flutter test` — 13/13 passed: garment
  result screen renders real attributes, `UNKNOWN` plus the why for
  unconfident attributes, §12 failure codes; WARDROBE tab opens the garment
  scan; missing camera reported honestly.
- `flutter build apk --debug` — `app-debug.apk` produced.
- Mock-data audit — zero fabricated values; prompt sets and color-name rules
  are documented configuration, every displayed number comes from a real
  model run.

Honest limits of this verification:

- Camera capture happens on the maintainer's Android/Termux flow; the
  pipeline is verified end-to-end from real photos through the same endpoint
  the app calls.
- Pattern/material/fit are honest zero-shot reads with per-attribute
  thresholds — expect `Unknown` often on flat-lays. That is the DoD working.

## Phase 3 — Personal Outfit Recommendation

**Status: VERIFIED — 2026-08-15**

Definition of Done — BUILD_PLAN §2 *One Test*: real photo → real analysis →
real occasion + place → real weather → real available garments → candidate
outfits → scored for THIS person → Best Outfit → explanation tied to real
score components. §3 *Personalization Test*: the same wardrobe/occasion/place
must not score identically for 3 distinct real profiles, for different
reasons.

Evidence:

- `pytest` — 29/29 passed. Nine new Phase 3 tests call the **real**
  `/analysis/*` endpoints on **real fixture photos** (two new CC BY-SA
  fixtures — jeans, sneakers — with provenance in
  `backend/tests/fixtures/`) to build the wardrobe, then call
  `/recommend/outfit`: live Open-Meteo weather (`state == "ok"`, structural
  asserts only — real weather moves), best_match outfit assembled from the
  photographed sweater + jeans + sneakers, `why` bullets bound to real score
  components, active effective weights sum to 100, `score == Σ contribution`,
  `shopping.state == CATALOG_NOT_CONNECTED`, the unidentifiable hanger photo
  reported as `unplaceable` (never guessed into a slot).
- §3 personalization verified: three real profiles (body photo A, body photo
  B, and A without appearance + a different style profile) produce three
  distinct scores, and the *reasons* differ — A vs B on the body-driven
  proportion factor, A vs C on appearance activity and fit preference.
- Honesty under failure: `WEATHER_BASE_URL` pointed at a genuinely
  unreachable address → `WEATHER_UNAVAILABLE`, weather factor inactive,
  recommendation still returned; `banned_colors` emptying the pool → 422
  `INSUFFICIENT_DATA`; trend/budget/user_preference reported inactive with
  real reasons and their weights redistributed.
- Live `uvicorn` smoke — real analyses on fixtures → real
  `POST /recommend/outfit` → 200 with live Casablanca weather (22.3 °C,
  partly cloudy) and a 71.1 best_match outfit; a second server with an
  unreachable weather URL returned the honest `WEATHER_UNAVAILABLE` path.
- `flutter analyze` — no issues. `flutter test` — 20/20 passed: store
  round-trips, HOME prerequisite states computed from real stored data,
  result rendering from contract-shaped payloads, envelope parsing into
  typed success/failure. `flutter build apk --debug` — `app-debug.apk`
  produced.
- Deterministic ranking: pure scoring functions, double-call identical
  output; explanations are templates bound to real contributions, not an LLM.

Honest limits of this verification:

- Weather in tests is **live** Open-Meteo — success-path asserts are
  structural because real weather changes.
- Trend, Budget and User Preference factors are inactive by design (no trend
  feed, no prices on photographed garments, no feedback log yet).
- **Ranked alternatives #2–#4 (Safer / Trend / Bold)**: the full selection
  mechanism is implemented and tested (strategy labels, determinism,
  no-padding rule), but the fixture wardrobe assembles exactly ONE outfit,
  so end-to-end tests demonstrate #1 only — outfits are never padded to
  four (locked honesty decision). A real multi-outfit demonstration needs a
  larger wardrobe: it lands with the Phase 7 Wardrobe module (richer item
  set + fixtures), not as a Phase 3 retrofit.
- Outfits are assembled from the user's photographed wardrobe only — no
  merchant catalog is connected (rule 4); `SHOP THIS LOOK` renders
  `CATALOG_NOT_CONNECTED`.
- Camera capture remains the maintainer's Android/Termux flow; the pipeline
  is verified end-to-end from real photos through the same endpoints the app
  calls.

## Environment rebuild re-verification — 2026-08-16

The codespace was rebuilt and the toolchain lost; Phases 0–3 were
re-verified from scratch on the fresh environment: backend `pytest` 29/29
on real fixture photos with live Open-Meteo weather, `flutter analyze`
clean, `flutter test` 21/21, and the web preview re-inspected in a browser.

Maintenance fixes landed with this pass (no phase scope changed):

- Style Profile now offers all four fit values, in sync with the backend
  `FIT_SCALE` (`oversized` was missing from the app).
- 44pt minimum tap target enforced on chips and the fit segmented control
  (DESIGN_SYSTEM §2).
- Honest storage-unavailable states on Style Profile and the body-scan
  entry, matching the existing HOME/WARDROBE pattern (previously an
  unhandled `MissingPluginException` and an infinite "Loading…" on web).
- Ranking engine looks up factor reports by name instead of positional
  indices.
- Environment fixes documented: opencv-headless shadowed by mediapipe's
  transitive GUI build, and mediapipe's native `libEGL` requirement
  (TROUBLESHOOTING.md).

## Phase 4 — Virtual Try-On

**Status: VERIFIED — 2026-08-16**

Definition of Done: *Try-on renders with method + confidence shown, or an
explicit failure state.*

Evidence:

- FASHN `tryon-max` contract verified per AGENTS.md rule 3 (docs.fashn.ai,
  2026-08-16): `/v1/run` + `/v1/status/{id}` polling, Bearer auth, error
  codes, paid-credits terms. The hosted path is the §7-sanctioned MVP choice
  on CPU-only infrastructure; the adapter sits behind a swappable provider
  boundary.
- `pytest` — 40/40 passed. Eleven new Phase 4 tests on **real fixture
  photos**: landscape person → `NO_PERSON`, garbage → `POOR_IMAGE`, hanger
  garment → `INSUFFICIENT_DATA`, accessories → `VTON_UNSUPPORTED_GARMENT`,
  no key → `MODEL_MISSING`. Against a local protocol stub of the FASHN API:
  a render returns `method: image_based_vton` + provider with a **computed**
  fashionCLIP confidence (>0.9 when the stub returns the source garment;
  flagged `LOW_CONFIDENCE` when it returns an unrelated image), identical
  across repeated calls; 429 → `RATE_LIMITED`, 401 → `MODEL_MISSING`.
- Live `uvicorn` + web-preview E2E in a browser: real person + real garment
  photos through `POST /tryon/render` → honest `MODEL_MISSING` stated
  plainly (no key configured). Nothing rendered, nothing substituted.
- `flutter analyze` — no issues. `flutter test` — 26/26 passed: the TRY ON
  tab is a real flow (choose photo + choose garment; render disabled until
  both exist), the result view shows method + confidence permanently and
  flags LOW_CONFIDENCE plainly, the client parses labeled envelopes and §12
  codes, and HOME's `TRY ON` now opens the TRY ON tab.

Honest limits of this verification:

- **No provider key exists**, so a real hosted render was not produced in
  this environment. The DoD is met on its explicit-failure branch; the
  render+confidence branch is verified against a protocol stub with real
  images. The first real render happens when `FASHN_API_KEY` is provisioned
  (paid credits) — the adapter is contract-verified and ready.
- Confidence is garment-fidelity similarity (fashionCLIP cosine between the
  source garment and the render), always shown next to the method string
  (DESIGN_SYSTEM §5). It is never a claim of precise physical simulation
  (PRODUCT_SPEC §7).

## Phase 5 — Size Engine

**Status: VERIFIED — 2026-08-16**

Definition of Done: *a real product with a real size chart returns a real
size + confidence.*

Evidence:

- Chart source is the user's own real data: centimetre values copied from a
  real product page (rule 4 — no catalog scraping, no demo products). Brand
  Size Normalization (§8) is satisfied by matching purely in cm space with
  opaque brand labels.
- `pytest` — 49/49 passed. Nine new Phase 5 tests: real `/analysis/body`
  runs on fixture photos feed the engine; a chart built at the real
  measurements + documented ease returns the expected size with score 1.0
  and confidence 0.9 (coverage 2/3 — chest in the chart but honestly
  `not_measurable`); double-call identical; two real bodies score the same
  chart differently (§3 personalization); fit type moves the match;
  chest/waist-only chart → `INSUFFICIENT_DATA`; one-row/empty chart →
  `NO_SIZE_CHART`; footwear → `INSUFFICIENT_DATA` (no foot measurement
  exists); unknown category → plain 422.
- `flutter analyze` — no issues. `flutter test` — 32/32 passed: envelope
  parsing, `NO_SIZE_CHART` surfacing, result view shows the recommended
  size + confidence + the honest chest note + LOW CONFIDENCE flag, the
  screen states the honest "not measured yet" prerequisite without a stored
  scan, and renders the chart form with one.
- Web preview: PROFILE → Size check shows the honest prerequisite on
  platforms without a stored scan; with a backend and a real scan the form
  submits to `POST /size/recommend`.

Honest limits of this verification:

- Only shoulder, hip and arm-as-sleeve score; chest/waist remain `null` by
  design and are listed, never guessed. `length` is displayed but never
  scored (no honest body counterpart).
- Outfit Detail's `[Check Sizes]` button wires to this engine when that
  screen lands; today the flow lives under PROFILE → Size check.

## Phase 6 — Weather + Occasion depth

**Status: VERIFIED — 2026-08-16**

Definition of Done: *ranking measurably shifts when occasion/weather inputs
change (§3 test, applied to context).*

Evidence:

- Two new real CC fixtures (provenance recorded): `garment_tshirt.jpg`
  (File:T-shirt mockup.jpg, CC BY-SA 4.0) and `garment_shorts.jpg`
  (File:Men's Shorts - Old Bull Lee - Orange.jpg, CC BY-SA 3.0), classified
  by the real Phase 2 pipeline as `t-shirt` 0.949 and `shorts` 0.999 — the
  wardrobe now assembles four real outfits, so context can decide.
- `pytest` — 55/55 passed. Six new Phase 6 tests against a local Open-Meteo
  contract stub: HOT (35°C) ranks the summer pair first, COLD (5°C) the warm
  pair first — a measurable weather-driven flip with the Weather factor as
  the visible driver; severity (cold/rainy) raises the Weather effective
  weight above mild while base stays 6.0 and active weights still sum to
  100; dinner vs gym reorders the same wardrobe via the occasion table;
  every why-line traces a factor that cleared the 4.0 contribution
  threshold; double-call identical.
- Depth mechanics are documented deterministic configuration: occasion
  score = 0.7·category suitability + 0.3·formality fit (per-occasion
  formality × pattern/fit penalties); weather base weight ×(1 + severity).
- Maintenance fix landed with this pass: the fashionCLIP preprocessor could
  truncate a resized side to 223px and feed a 1px crop to ONNX (crash on
  square-ish large photos); now rounded with a 224 floor.
- `flutter analyze` — no issues; `flutter test` — 32/32 (app renders the
  richer factor report generically; no UI change needed).

Honest limits of this verification:

- Weather in the flip tests is a local stub of the Open-Meteo contract; the
  live-weather success path remains covered by Phase 3 tests.
- Formality/severity values are documented styling conventions, not learned
  — same status as the occasion tables (PRODUCT_SPEC §6 tunable baseline).

## Phase 7 — Wardrobe module

**Status: VERIFIED — 2026-08-16**

Definition of Done: *"Best Outfit From My Closet" returns a real ranked
outfit from photographed items only.*

Evidence:

- The WARDROBE tab is now the full module (PRODUCT_SPEC §10): rich honest
  item cards (category or "Unidentified", confidence, fit/pattern/material
  with Unknown left Unknown, real color swatches, LOW CONFIDENCE flags),
  slot filter chips, add via camera **or** file, remove, and a "Best outfit
  from my closet" panel (occasion + real place → same ranking brain as
  HOME) rendering the shared ResultCard with real alternatives.
- `pytest` — 60/60 passed. Five new Phase 7 tests: the five-fixture real
  wardrobe yields exactly four distinct outfits with the full strategy set
  `[best_match, safer, trend_forward, bold]`, #1 the top score; a
  three-piece wardrobe yields one outfit (never padded); two real bodies
  score the same closet differently (§3); the unplaceable hanger item is
  reported, never guessed; double-call identical.
- `flutter analyze` — no issues; `flutter test` — 35/35: rich cards read
  real attributes, filters scope the list, closet scoring renders the
  backend's alternatives, session-only storage is labeled honestly.
- Web preview gained a **session-only in-memory store** (labeled in the UI:
  "nothing is saved after this tab closes") so the wardrobe flow is
  demonstrable end-to-end there: real fixture uploads → real analyses →
  real closet recommendation with live weather.

Honest limits of this verification:

- Salient-object segmentation for cluttered flat-lay backgrounds remains
  deferred to Phase 8 (recorded decision).
- Wardrobe photos themselves are still never stored (BUILD_PLAN §5); only
  analysis JSON persists, session-only on web.

## Phases 8–10

Not started. No feature flags are enabled.
