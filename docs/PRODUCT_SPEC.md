# Atelier — Product Specification

*Linked from `AGENTS.md`. This is where the "what" and "why" live — mission, architecture, pipelines, ranking, and the honesty rules that hold the product together.*

---

## §1. Mission & Ranking Priority

There is a difference between "this is a popular outfit" and "this is the best possible outfit for this person, specifically." Build the second one.

Do not build a generic recommendation engine that shows the same outfits to every user. Build a system that constructs a **Personal Fashion Intelligence Profile** per user, and for every candidate outfit answers: *"How will this look on this person?"* — never *"Is this outfit nice in general?"*

**Default ranking priority** (weights in §6 are tunable; this ordering is the product's spine and is not):

| Priority | Factor |
|---|---|
| 1 | Person (real body + real appearance) |
| 2 | Fit |
| 3 | Proportion |
| 4 | Color |
| 5 | Style match |
| 6 | Occasion |
| 7 | Weather |
| 8 | Trend |
| 9 | Price |

A trend-heavy item at 98 trend / 62 personal suitability is never #1. An item at 88 trend / 96 personal suitability is a top candidate. Trend never outranks person.

---

## §2. Competitive Landscape (verified mid-2026)

| Precedent | What it does | Take | Avoid |
|---|---|---|---|
| **Google "Try It On"** (formerly the standalone Doppl app, shut down Apr 30 2026 and folded into Search) | Full-body render from a selfie via Gemini 2.5 Flash Image ("Nano Banana"), anchored to the real catalog photo to preserve fabric/print fidelity | Anchor generation to the real product image to protect garment fidelity. Try-on wins embedded at the point of discovery, not as a standalone destination | Don't assume a standalone "Try-On app" is a durable category — even Google didn't keep it standalone |
| **FASHN.ai** | Proprietary hosted VTON API, ~18M try-on pairs trained, 5–8s median latency on the standard endpoint | Pragmatic hosted path to an MVP with no GPU infrastructure | Be as explicit about latency/quality tradeoffs on a cost tier as the vendor itself is |
| **IDM-VTON / StableVITON / OOTDiffusion** (open research lineage) | StableVITON freezes Stable Diffusion, trains a lightweight adapter conditioned on garment image + mask + DensePose | Credible self-hosted path once GPU budget exists | Mostly research/non-commercial licenses — verify before commercial use |
| **Marqo-FashionCLIP / FashionSigLIP** | Apache-2.0 fashion-tuned embedding models, outperform generic CLIP on retrieval | Correctly-licensed default for visual search (§9) | Don't default to generic CLIP for fashion — domain-tuned models win by a wide margin |
| **MediaPipe Pose Landmarker** (Google) | Apache-2.0, 33 3D landmarks with world coordinates, runs on-device on phones | This is the Phase 1 body pipeline — free, well-licensed, no GPU server | Don't reach for heavier SMPL-X research models for MVP — restrictive licenses, real compute |
| **Stitch Fix** | Hybrid human-stylist + algorithmic ranking in production for over a decade | Explain the *why*; treat a score as an auditable signal, not a black box | No styling team to out-hire — out-personalize with real body geometry instead |
| **Walmart / Zeekit** | AR fitting room, acquired 2021; shipped a lower-cost "Choose My Model" avatar-matching tier before full generative try-on | A cheaper "closest matching avatar" tier is legitimate to ship before full generative try-on | Big acquisitions don't guarantee tech survives as a standalone brand — keep the VTON backend swappable |

---

## §3. System Architecture & Orchestration

```
Mobile App (Flutter)
   ↓
Application Layer
   ↓
API Gateway (FastAPI)
   ↓
Domain Services  (Body · Appearance · Color · Garment · Ranking · Size · VTON · Weather · Wardrobe)
   ↓
Repositories
   ↓
ML Providers / External Providers
```

The UI never talks to a model directly. Every screen calls a domain service; the service picks the provider (on-device, self-hosted, hosted API) and returns a typed result that always includes a confidence value, or one of the failure states in §12.

### Who handles what — the orchestration map

| Capability | Handled by | Nature |
|---|---|---|
| Conversational context-gathering, turning real score deltas into "why this works" | Orchestrator LLM (tool-calling — Gemini, Claude, or GPT-class; swappable) | LLM — narrates only, never computes a number |
| Body landmarks, proportions, measurements | MediaPipe Pose Landmarker (or equivalent) | Deterministic CV |
| Face/appearance & color extraction | Face landmark model + documented color-theory rules | Deterministic CV + rules |
| Garment detection, attributes, embeddings | Fashion-tuned CLIP/SigLIP model | Deterministic CV / embeddings |
| Outfit ranking | Weighted scoring service, later a learned re-ranker | Deterministic, then ML — not the LLM |
| Virtual try-on rendering | Dedicated VTON model or hosted API | Generative image model |
| Weather | Real weather API | External provider |
| Size/fit math | Deterministic size-chart matching | Deterministic |

**The rule that protects everything else:** the orchestrator LLM is the mouth, not the brain of the numbers. It calls tools, converses, and phrases explanations from real tool outputs. It never invents a percentage, a measurement, a garment attribute, or a price. If a tool call fails or returns low confidence, it relays that honestly.

---

## §4. Personal Fashion Intelligence Profile

```yaml
PersonalFashionProfile:
  user_id: string
  body_profile:
    height_cm: float | null
    measurements: { shoulder_cm, chest_cm, waist_cm, hip_cm, inseam_cm, arm_length_cm }
    proportions: { torso_to_leg_ratio, shoulder_to_hip_ratio, vertical_balance }
    body_shape: enum | "insufficient_data"
    confidence: float          # always present
    source_image_refs: [image_id]   # never logged in plaintext — see BUILD_PLAN §5
  appearance_profile:
    face_shape: enum | null
    skin_undertone: enum(cool|warm|neutral)
    skin_depth: enum(light|medium|deep)
    hair_color: string
    eye_color: string
    overall_contrast: enum(low|medium|high)
    confidence: float
  color_profile:
    excellent: [hex]
    good: [hex]
    neutral: [hex]
    avoid: [hex]
    confidence: float
  style_profile:
    fit_preference: enum(slim|regular|relaxed|oversized)
    aesthetic_tags: [string]
    liked_outfits: [outfit_id]
    disliked_outfits: [outfit_id]
    learned_weight_deltas: {factor: float}
  constraints:                 # HARD FILTERS — see §6
    budget_ceiling: {min, max, currency}
    banned_colors: [hex]
    banned_brands: [string]
  wardrobe: [garment_id]
  feedback_log: [{outfit_id, reaction, notes, timestamp}]
```

Never infer or store race or ethnicity. Only optical undertone/depth/contrast — that's what actually drives color harmony.

---

## §5. Core Intelligence Pipelines

**5.1 Body Analysis**
```
Images (front/side/back, quality-validated)
 → Person detection (reject zero or multiple people)
 → Pose landmarks — MediaPipe Pose Landmarker (Apache-2.0, on-device capable)
 → Segmentation mask
 → Proportion/measurement estimation, calibrated against user-entered height
 → Confidence score → BodyProfile
```
Heavier SMPL-X-based mesh-recovery models are a post-MVP upgrade — mostly research-only licenses, need real GPU. Verify current terms before adopting.

**5.2 Appearance & Color** — face landmarks → skin/hair/eye sampling → undertone/depth/contrast → mapped against a documented seasonal color-analysis model → `ColorProfile` with confidence.

**5.3 Garment Analysis** — detect + segment → category → color/pattern → fashion-domain embedding (Marqo-FashionCLIP/FashionSigLIP) → fit-type → material cue (label "Unknown" if not reliably inferable) → `GarmentRepresentation`, embedding reused in §6 and §9.

**5.4 Context** — Weather from a real API (Open-Meteo / OpenWeatherMap-class); `WEATHER_UNAVAILABLE` on failure, never fabricated. Occasion: fixed taxonomy (casual lunch, university, office, interview, wedding, date, dinner, party, travel, beach, gym, shopping, formal) feeding §6's weights.

---

## §6. Ranking & Explainability Engine

**Hard filters vs. soft scoring — don't blur these.** `budget_ceiling`, `banned_colors`, `banned_brands` are gates applied *before* ranking — an over-budget item is excluded outright, not merely down-weighted.

**Default weights (MVP baseline, sum to 100, tunable via `learned_weight_deltas`):**

| Factor | Weight |
|---|---|
| Body / Fit Compatibility | 18 |
| Proportion Balance | 14 |
| Style Compatibility | 14 |
| Color Harmony | 12 |
| Occasion Compatibility | 10 |
| User Preference (learned) | 8 |
| Appearance Harmony | 8 |
| Weather Compatibility | 6 |
| Trend Relevance | 6 |
| Budget Efficiency | 4 |

**Stage 1 → Stage 2.** A flat weighted sum is an acceptable MVP baseline — interpretable, fast to ship. From day one, log every recommendation with its real feedback (❤️/👍/😐/👎, purchase, return). Once there's enough data, train a learning-to-rank re-ranker (LightGBM/LambdaMART-class, or a small neural re-ranker). Keep the Stage 1 baseline alive as the interpretable source for explanations, even after Stage 2 ships.

**"Why this outfit?"** is written by the orchestrator LLM, but every sentence must trace to a real score component that cleared a threshold. If proportion didn't move, don't mention proportion.

**Present alternatives, not one outfit:** #1 Best Match, #2 Safer Choice, #3 Trend Choice, #4 Bold Choice — all four scored for *this* person; "bold" never means generic.

---

## §7. Virtual Try-On Engine

**Honesty doctrine:** if the model is generative, never claim precise physical simulation. Internally: `method: image_based_vton`, `confidence: <float>`, always. Keep the architecture open to a future 3D-mesh + cloth-simulation upgrade.

| Path | Fit for this project |
|---|---|
| **Hosted API** (FASHN.ai-class, or Gemini 2.5 Flash Image) | **Recommended for MVP** — no GPU to manage, usage-based cost, matches a mobile-only workflow with no local GPU |
| **Self-hosted open-source** (IDM-VTON/StableVITON-class) | Upgrade path once usage data justifies a GPU box — re-verify current SOTA and licenses then |
| **General multimodal image model** | Viable alternative; garment fidelity depends on anchoring the prompt tightly to the real product image |

---

## §8. Size & Fit Engine

```
Measurements + Garment size chart + Fit type
 → Recommended Size + Confidence
 → Per-region breakdown: Chest / Shoulder / Sleeve / Length / Waist
```
**Brand Size Normalization Layer:** "M" at one merchant isn't "M" at another — map every brand's chart into canonical cm ranges before trusting a cross-brand suggestion.

---

## §9. Find-This-Look Visual Search

```
Screenshot → Garment decomposition (reuse §5.3) → per-item embedding
 → nearest-neighbor search against a real indexed catalog (pgvector or Qdrant)
 → tiers: Exact Match → Same Product, Different Merchant → Closest Match → Budget Alternative
```
Nothing clears the similarity threshold → "No match found," never a fabricated closest guess presented as real.

---

## §10. Wardrobe Module

Users photograph what they own → real `GarmentRepresentation` objects (§5.3). "Best Outfit From My Closet" runs the same §6 ranking engine, constrained to `wardrobe` items, combined with real weather/occasion. A filtered view of the same brain, not a separate one.

---

## §11. Feedback & Continuous Learning

```
Recommendation → Feedback (❤️ 👍 😐 👎 + tags: too loose / wrong color / loved the shoes...)
 → feedback_log + learned_weight_deltas → Stage 2 retraining (§6) → next recommendation reflects it
```

---

## §12. The No-Fake-Data Doctrine & Failure States

Absolutely prohibited: fake users, products, prices, weather, analysis, scores, measurements, recommendations, or any hardcoded percentage.

| State | Meaning |
|---|---|
| `NO_PERSON` / `MULTIPLE_PEOPLE` | Detection couldn't isolate one person |
| `POOR_IMAGE` | Quality too low to analyze reliably |
| `INSUFFICIENT_DATA` | Not enough signal for a confident profile |
| `LOW_CONFIDENCE` | Result exists but below trust threshold — show it, flag it, don't hide it |
| `MODEL_MISSING` / `MODEL_FAILED` | A required model isn't installed or errored |
| `GPU_MEMORY_ERROR` | Self-hosted inference ran out of resources |
| `RATE_LIMITED` | Hosted API path throttled |
| `NO_SIZE_CHART` | Can't size this product with confidence |
| `VTON_UNSUPPORTED_GARMENT` | Garment type unsupported by the current try-on path |
| `PRODUCT_UNAVAILABLE` / `CATALOG_NOT_CONNECTED` / `STALE_CATALOG_DATA` | Product can't be sourced or verified fresh |
| `WEATHER_UNAVAILABLE` / `NETWORK_ERROR` | External dependency down |

State it plainly, in the interface's real voice — see `docs/DESIGN_SYSTEM.md §6` for how that voice actually sounds.
