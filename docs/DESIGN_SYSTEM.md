# Atelier — Design System: "Atelier Glass"

*Linked from `AGENTS.md`. This is where the "how it looks and feels" lives.*

Inspired by Apple's Human Interface Guidelines and the Liquid Glass material language (iOS 26) — **not a reuse of them.** Liquid Glass is a proprietary, SwiftUI-native rendering system; this app ships on Flutter/Android. Borrow the *principles*, rebuild the *material* honestly with `BackdropFilter`/shaders that behave well on mid-range Android hardware, not just a flagship.

---

## §1. Design Principles

Apple's HIG rests on three pillars: **Clarity, Deference, Depth.** Here's what each means for Atelier specifically:

- **Clarity** — the garment and the person's real body are always the most legible thing on screen. Glass, blur, and chrome defer to them, never compete.
- **Deference** — the interface doesn't perform. It gets out of the way so the outfit and the score are what the eye lands on.
- **Depth** — hierarchy is communicated through layering and transparency, not just size or color contrast — a card that matters sits visibly *above* the ones that don't.

**Honest materiality.** Apple's own Liquid Glass documentation states that glass effects should serve a functional purpose, not exist purely for decoration. Apply that literally here: **every** translucent surface must be communicating real hierarchy or real state. This is the visual expression of the same rule that governs the data layer in `PRODUCT_SPEC.md §12` — no fake data, and no fake depth either.

**Restraint is not optional.** Apple's own design guidance warns that Liquid Glass carries real performance and accessibility costs when over-applied. Reserve glass for a small number of primary surfaces — the nav bar, the Personal Match card, modal sheets. Everything else is a flat, quiet surface. This is a performance decision as much as an aesthetic one — see §3.

---

## §2. Design Tokens

**Color** (named, not vague adjectives):

| Token | Hex | Use |
|---|---|---|
| Ink | `#16161B` | Dark canvas, primary text on light |
| Graphite | `#2A2A31` | Elevated dark surfaces / cards |
| Bone | `#F5F3EE` | Light canvas, editorial-paper feel |
| Fog | `#C7C6C9` | Borders, dividers, disabled states — low opacity only |
| **Spotlight Gold** | `#B99A5B` | Signature accent — the Personal Match ring and primary CTA *only*. Nowhere else. |
| Signal Red | `#C0453A` | Functional only — hard failure states, never decorative |

Use semantic token names in code (`surface.primary`, `accent.signature`), not raw hex references — this is what lets light/dark and accessibility modes (§6) adapt automatically, the same way Apple's system colors do.

**Typography** — three roles, deliberately different jobs:

- **Display** (headlines, the Personal Match numeral): a high-contrast editorial serif, in the spirit of Canela or GT Sectra — used large, and rarely.
- **Interface** (buttons, nav, body copy): a quiet humanist grotesk — Inter, General Sans, or Neue Montreal — that never competes with garment photography.
- **Data** (measurements, confidence scores, diagnostics): a monospaced or semi-condensed grotesk — IBM Plex Mono or similar. The moment the eye hits monospace, it reads "this is a real number," not marketing copy — a typographic enforcement of the honesty doctrine.

**Layout:** 8pt grid with 4pt subdivisions. 44×44pt minimum tap target on every interactive element (Apple's own HIG minimum — it's the right number regardless of platform).

**Material:** glass cards sit on 20–24px backdrop blur at 62–72% surface opacity over Ink or Bone, with a 1px Fog border at ~8% opacity. Stop there — pushing further is what makes glass read as templated "glassmorphism" instead of considered.

---

## §3. Performance Budget

Apple design is inseparable from Apple-grade speed. On mixed Android hardware, that has to be earned deliberately, not assumed:

- **Frame budget:** 60fps minimum on every supported device (16.6ms/frame), 120fps where the display supports it. No dropped frames during scroll or the Try-On comparison slider — these are the two places jank is most visible.
- **Cold start:** first meaningful paint under ~1.5s on a mid-tier Android device, not just a flagship. Use skeleton states, not blank screens, for anything waiting on network or inference.
- **Glass has a real cost.** Backdrop blur is expensive to render — this is exactly why §1 says to reserve it for a handful of primary surfaces. Test glass-heavy screens on real mid-range hardware, not only a dev flagship.
- **Never block the UI thread on inference.** The body/garment CV pipelines (`PRODUCT_SPEC.md §5`) run on a background isolate. The Constellation Scan animation (§4) must stay smooth at 60fps even while pose/segmentation inference is running concurrently — if it can't, that's a threading bug, not a reason to simplify the animation.
- **Reduced Transparency mode** (§6) doubles as a low-end-device performance mode: turning it on should measurably cut GPU load, not just visually flatten the UI.

---

## §4. Signature Moment — The Constellation Scan

This is the one place the interface is allowed to be genuinely alive. Everywhere else, restraint (§1). Here, presence — because this is the moment the app is quite literally seeing the person for the first time.

**Sequence, driven entirely by real pipeline events — never by a decorative timer:**

1. Camera opens on a quiet Ink canvas with plain-language guidance ("Stand here," "Move back," "Full body detected").
2. The instant MediaPipe returns a real landmark, a small Spotlight Gold point fades in at that exact screen coordinate — not all 33 at once, one by one, exactly as they're actually detected.
3. Thin glass line-segments connect landmarks into a skeleton as adjacent points complete.
4. As segmentation resolves, a soft light-sweep passes once down the body silhouette.
5. Measurements "crystallize" into place in the Data typeface (§2) as each one is actually computed — a quick focus-pull settle, not a slot-machine spin.

**The rule that makes this honest, not just pretty:** if detection stalls, the animation stalls honestly — a subtle "still analyzing" pulse, never a looping generic animation that fakes progress to mask latency. The visual excitement comes from truthfully rendering a real-time process, not from decorating a black box. This is the same principle as `PRODUCT_UNAVAILABLE` in §12 of the product spec, expressed as motion instead of text.

Avoid any framing that reads as a security scanner or surveillance device — warm, editorial, personal. This is a fitting room, not a checkpoint.

---

## §5. Information Architecture & Screens

**Navigation:** `HOME · DISCOVER · TRY ON · WARDROBE · PROFILE`

- **Home — "Your Best Look":** not a shopping feed. Large outfit visualization, Personal Match ring, one line of context ("Perfect for: Dinner · Tonight · Casablanca"), an expandable "Why it works" tied to real score components, then `[TRY ON] [SEE DETAILS] [SHOP THIS LOOK]`.
- **Outfit Detail:** match %, why-it-works list, itemized pieces with prices and a total, `[Try On] [Check Sizes] [Buy]`.
- **Body Scan:** the Constellation Scan (§4) is this screen.
- **Try On:** Choose Photo + Choose Garment → result, with Before/After, zoom, and the confidence + method label from `PRODUCT_SPEC.md §7` always visible — never hidden in a submenu.
- **Diagnostics** (developer/QA screen): GPU/VRAM/RAM/CPU, per-pipeline model status (`READY`/`MISSING`/`FAILED`), latency and error rates — all real, none illustrative.

---

## §6. Accessibility, Restraint & Voice

Borrowed faithfully from Apple's own accessibility accommodations for Liquid Glass — implement all three as real, user-toggleable states:

- **Reduced Transparency** — surfaces go frostier/more opaque, obscuring more of what's behind them. Also functions as the low-end-device performance mode (§3).
- **Increased Contrast** — elements go predominantly Ink/Bone with a visible contrasting border.
- **Reduced Motion** — the Constellation Scan and all elastic/spring effects drop to simple, immediate state changes. The scan still works, it just doesn't perform.

**Voice.** Active voice. Errors don't apologize and are never vague. An empty screen is an invitation to act, not a dead end.

| Instead of | Write |
|---|---|
| "Sorry, we couldn't process your photo." | "Photo too dark to read. Retake in better light." |
| "Outfit not available at this time." | "This piece just sold out. Here are two that fit the same way." |
| "Analysis complete" (when it silently failed) | The real state from `PRODUCT_SPEC.md §12`, stated plainly |
