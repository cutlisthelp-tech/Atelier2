# AGENTS.md — Atelier

## Project Identity — Read This First

This is a **brand-new, clean repository** for Atelier, a personal fashion intelligence app.

- Repo: `khalilblm2-droid/Atelier` — independent from any prior workspace.
- Do **not** reuse, copy, migrate, inspect-for-functionality, or inherit code, APKs, build artifacts, databases, credentials, or temp data from `Vanta_os1`, `Voyra`, or any earlier `Atelier` workspace — unless a task explicitly asks you to reference one of them.
- Start at Phase 0. This file, plus `docs/`, is the source of truth. If an instruction conflicts with the constitution, stop and resolve the conflict before writing code — don't silently reinterpret it.

## Product Identity

Atelier is **not a chatbot.** The user-facing product is a visual app: `HOME · DISCOVER · TRY ON · WARDROBE · PROFILE`.

The LLM/agent is an invisible backend orchestration layer only. **Never** build a chat screen, a ChatGPT-style interface, or let conversation become the primary UI. If a task seems to call for one, stop and check `docs/DESIGN_SYSTEM.md` instead.

## Where the Detail Lives

| Topic | File |
|---|---|
| Mission, architecture, pipelines, ranking engine, try-on, failure states | `docs/PRODUCT_SPEC.md` |
| Design principles, tokens, performance budget, screens | `docs/DESIGN_SYSTEM.md` |
| Phases, Definition of Done, testing, engineering standards | `docs/BUILD_PLAN.md` |

Read the relevant doc before starting work in that area. Don't ask the user to repeat information that's already written down here.

## Non-Negotiable Rules

1. **No fake data, ever.** No invented products, merchants, prices, URLs, weather, measurements, garment attributes, scores, or confidence values. When a real provider isn't connected, return the exact failure state defined in `docs/PRODUCT_SPEC.md §12` — never a plausible-looking substitute.
2. **Phase discipline.** One phase at a time: plan → implement → test → verify → document → commit → only then proceed. Never implement Phase 9–10 early to make the app look more finished. Never mark a phase done from compilation or mocked tests alone — use the Definition of Done in `docs/BUILD_PLAN.md §1`.
3. **Model selection is not permanently locked.** Names in the docs are starting points. Before integrating any model or library: check current GitHub activity, license, weights availability, commercial-use terms, and hardware needs — then decide.
4. **Catalog data must be real.** Official APIs, affiliate feeds, or licensed merchant data only — no unauthorized scraping, no demo products. Nothing connected yet → `PRODUCT_UNAVAILABLE` / `CATALOG_NOT_CONNECTED`.
5. **LLM boundaries.** The orchestrator LLM may interpret intent, choose tools, call services, and explain real results in plain language. It may **not** calculate measurements, invent scores, prices, weather, or product facts, override deterministic ranking, or fabricate a confidence value.
6. **Environment.** Android phone → Termux → GitHub Codespace → remote Linux. Flutter mobile client, FastAPI backend. CPU-only infrastructure for light inference; hosted API/GPU for virtual try-on. Never assume a local desktop GPU exists.
7. **Checkpointing.** One git commit per verified phase. Commit message states phase, capability, and verification status. Never commit `.env`, keys, tokens, credentials, raw user images, or build artifacts.

## Before You Build

Enter Plan / Quest mode before writing code for any new phase. Propose the plan, wait for review, then implement.
