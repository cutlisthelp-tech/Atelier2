/// Typed Phase 4 try-on results.
///
/// A render always carries its method and a real confidence (PRODUCT_SPEC
/// §7) — the UI shows both permanently, never in a submenu.
library;

import 'dart:typed_data';

class TryOnRender {
  const TryOnRender({
    required this.imageBytes,
    required this.method,
    required this.provider,
  });

  final Uint8List imageBytes;

  /// Always "image_based_vton" on the MVP path (§7 honesty doctrine).
  final String method;
  final String provider;
}

class TryOnSuccess {
  const TryOnSuccess({
    required this.render,
    required this.confidence,
    required this.flags,
    required this.category,
  });

  final TryOnRender render;
  final double confidence;
  final List<String> flags;
  final String category;
}

sealed class TryOnOutcome {
  const TryOnOutcome();
}

class TryOnOk extends TryOnOutcome {
  const TryOnOk(this.result);
  final TryOnSuccess result;
}

class TryOnFailure extends TryOnOutcome {
  const TryOnFailure({required this.code, required this.message});

  /// A §12 failure-state code, e.g. MODEL_MISSING, VTON_UNSUPPORTED_GARMENT.
  final String code;
  final String message;
}
