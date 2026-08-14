# Model Setup

No models are installed yet. `models/registry.yaml` is intentionally empty in
Phase 0, and the app's Diagnostics screen reports "No models registered."

## How a model enters the project (docs/BUILD_PLAN.md §4)

1. **Search open-source first.** Check repository activity, license, weights
   availability, inference instructions, hardware requirements. Names in
   `docs/PRODUCT_SPEC.md` are starting points, not permanent choices.
2. **Register it** in `models/registry.yaml` with every field real:
   `name, github, revision, license, weights, checksum, runtime, task,
   hardware, installed, tested, notes`. No placeholder values — the app
   rejects incomplete entries.
3. **Model Manager lifecycle:** Discover → Download → Verify (checksum) →
   Install → Load → Cache → Unload → Report status on the Diagnostics screen.
4. **Test on real input** before marking `tested: true`.

## Planned by phase

- Phase 1: pose landmarks (MediaPipe-class, on-device, CPU) + face landmarks.
- Phase 2: fashion-tuned embedding model (FashionCLIP/FashionSigLIP-class).
- Phase 4: virtual try-on — hosted API, not a local model.
