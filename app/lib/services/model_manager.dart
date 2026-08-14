import 'package:flutter/services.dart' show rootBundle;

import '../models/model_registry.dart';

/// Lifecycle states per docs/BUILD_PLAN.md §4:
/// Discover → Download → Verify → Install → Load → Cache → Unload → Report.
enum ModelLifecycle { discovered, downloading, verifying, installing, loaded, cached, unloaded, failed }

class ModelStatus {
  const ModelStatus(this.entry, this.state, [this.detail]);

  final ModelEntry entry;
  final ModelLifecycle state;
  final String? detail;
}

/// Owns every model the app uses. Phase 0 is the skeleton: it discovers the
/// registry and reports honest status. Download/verify/install/load arrive
/// with Phase 1, when the first real model (pose landmarks) is integrated.
class ModelManager {
  static const registryAssetPath = 'assets/models/registry.yaml';

  ModelRegistry _registry = const ModelRegistry([]);

  ModelRegistry get registry => _registry;
  bool get hasModels => !_registry.isEmpty;

  Future<void> discover() async {
    final text = await rootBundle.loadString(registryAssetPath);
    _registry = ModelRegistry.parse(text);
  }

  /// Report — the only fully implemented stage in Phase 0.
  List<ModelStatus> report() => [
        for (final entry in _registry.models)
          ModelStatus(
            entry,
            entry.installed ? ModelLifecycle.loaded : ModelLifecycle.discovered,
            entry.installed ? null : 'Registered, not installed.',
          ),
      ];
}
