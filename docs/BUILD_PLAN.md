# Atelier — Build Plan

*Linked from `AGENTS.md`. This is where the "how we get there, one verified phase at a time" lives.*

---

## §1. Phased Roadmap & Definition of Done

| Phase | Scope | Definition of Done |
|---|---|---|
| 0 | Infrastructure, feature flags, Model Manager skeleton, Diagnostics screen | App boots, every screen shows an honest empty state, zero mock data anywhere |
| 1 | Body + Appearance + Style Profile | A real photo produces a real BodyProfile + ColorProfile with confidence, or an honest failure state |
| 2 | Garment Analysis | A garment photo returns real category/color/attributes, or "Unknown" |
| 3 | Personal Outfit Recommendation | The test in §2 below passes end-to-end |
| 4 | Virtual Try-On | Try-on renders with method + confidence shown, or an explicit failure state |
| 5 | Size Engine | A real product with a real size chart returns a real size + confidence |
| 6 | Weather + Occasion depth | Ranking measurably shifts when occasion/weather inputs change (§3 test, applied to context) |
| 7 | Wardrobe | "Best Outfit From My Closet" returns a real ranked outfit from photographed items only |
| 8 | Product Search / Find This Look | A screenshot returns real tiered matches, or "no match found" |
| 9 | Accounts & Cloud Sync | `LocalUser` → `RemoteUserRepository` migration, zero data loss |
| 10 | Subscriptions & Monetization | Real payment integration — no paywall appears before this phase |

Feature flags start at:
```
FEATURE_AUTH=false
FEATURE_SUBSCRIPTIONS=false
FEATURE_CLOUD_SYNC=false
FEATURE_SHOPPING=false
```
Flip on only after Phases 0–8 are proven.

Do not jump to Phase 9 or 10 to make the project look more finished. An app that nails Phases 0–3 and is honest about the rest beats one that fakes its way to Phase 10.

---

## §2. The One Test That Matters

```
Upload a real photo → real analysis with confidence → enter a real occasion and place
 → app reads real weather → searches real available products → builds several real candidate outfits
 → scores them for THIS person → returns the Best Outfit → explains why, tied to real score components
```
If any step is faked, stubbed, or hardcoded, the project has not succeeded — no matter how polished the screen looks.

---

## §3. Testing Doctrine

**Personalization Test** — the same outfit, shown to Person A and Person B, must not score the same for the same reasons. Run against at least three distinct real profiles (A/B/C). Suspiciously similar results across people means the engine isn't personalized — it's a generic recommender in a personalization costume.

**A/B Evaluation** — Generic recommendation vs. Personal recommendation, compared on body fit, color preference, style preference, occasion fit, and real user feedback.

**Fairness / inclusive validation** — run every CV pipeline (body, appearance, color) against a deliberately diverse validation set: a range of skin tones across the Fitzpatrick scale, body sizes and shapes, ages, and genders. Track confidence/accuracy *per group*, not only in aggregate — pose and segmentation models trained on narrow datasets are a well-documented failure mode.

Never declare a phase complete based only on compilation or mocked tests — run the real test above.

---

## §4. Engineering Standards

**Model Manager** owns: Discover → Download → Verify → Install → Load → Cache → Unload → Report status, per model, surfaced on the Diagnostics screen.

**Open-source-first, every time a model is needed.** Search for a real implementation before writing anything from scratch. Check: repository activity, license, model weights availability, inference instructions, hardware requirements. Don't lock in a name from `PRODUCT_SPEC.md` if something better exists at build time.

`OPEN_SOURCE_COMPONENTS.md` and `models/registry.yaml` track every model: `name, github, revision, license, weights, checksum, runtime, task, hardware, installed, tested, notes` — no placeholder values.

---

## §5. Privacy, Consent & Regional Compliance

- Minimize image uploads to cloud; prefer on-device processing where the model supports it (MediaPipe does).
- Never write raw images into logs.
- Delete on request, and say so plainly in the UI, not buried in settings.
- Explicit consent screen before the first body scan — biometric-adjacent data deserves its own opt-in, not a bundled ToS checkbox.
- If the product expands beyond Morocco: Saudi Arabia's PDPL and EU-style GDPR both treat body-measurement and facial data as sensitive categories with extra handling requirements. Not legal advice — flag for a real compliance review before launch in those markets.

---

## §6. Infrastructure Notes

- **Backend:** FastAPI.
- **Mobile:** Flutter.
- **Heavy inference** (VTON, Stage-2 re-ranker training): don't self-host GPU diffusion models on a free-tier CPU VM. Use the hosted-API path (`PRODUCT_SPEC.md §7`) for MVP; revisit self-hosting once there's budget and a real GPU box.
- **Light inference** (pose, face landmarks, embeddings): cheap enough for modest CPU infrastructure, or on-device — this is why they're the MVP default in `PRODUCT_SPEC.md §5`.
- **Vector search:** pgvector on the existing Postgres instance is simpler to operate than a dedicated vector database until scale says otherwise.

---

## §7. Documentation Deliverables

`README.md` · `DEVELOPMENT.md` · `ARCHITECTURE.md` · `OPEN_SOURCE_COMPONENTS.md` · `DATA_SOURCES.md` · `MODEL_SETUP.md` · `TROUBLESHOOTING.md` · `API.md` · `IMPLEMENTATION_STATUS.md`

---

## §8. Operating Directives

1. Build → Run → Test → Verify → Document, every phase, no exceptions.
2. If a technique doesn't work, say so and show the real error — don't quietly swap in a fake result to keep a demo looking good.
3. Re-read `PRODUCT_SPEC.md §12` before touching any screen that displays a number, a score, or a product.
4. The success condition for v1 is not a beautiful screen. It's: the app understands a real person and hands them a real outfit that's genuinely right for *them*.
