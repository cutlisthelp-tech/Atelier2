import 'package:yaml/yaml.dart';

/// One model entry in models/registry.yaml — schema per docs/BUILD_PLAN.md §4.
/// Every field is required; no placeholder values are allowed.
class ModelEntry {
  const ModelEntry({
    required this.name,
    required this.github,
    required this.revision,
    required this.license,
    required this.weights,
    required this.checksum,
    required this.runtime,
    required this.task,
    required this.hardware,
    required this.installed,
    required this.tested,
    required this.notes,
  });

  final String name;
  final String github;
  final String revision;
  final String license;
  final String weights;
  final String checksum;
  final String runtime;
  final String task;
  final String hardware;
  final bool installed;
  final bool tested;
  final String notes;

  static const requiredFields = [
    'name', 'github', 'revision', 'license', 'weights', 'checksum',
    'runtime', 'task', 'hardware', 'installed', 'tested', 'notes',
  ];

  factory ModelEntry.fromYaml(YamlMap map) {
    final missing = requiredFields.where((f) => !map.containsKey(f)).toList();
    if (missing.isNotEmpty) {
      throw FormatException(
        'Registry entry "${map['name'] ?? '<unnamed>'}" is missing required '
        'fields: ${missing.join(', ')}. No placeholder values — see docs/BUILD_PLAN.md §4.',
      );
    }
    return ModelEntry(
      name: map['name'] as String,
      github: map['github'] as String,
      revision: map['revision'] as String,
      license: map['license'] as String,
      weights: map['weights'] as String,
      checksum: map['checksum'] as String,
      runtime: map['runtime'] as String,
      task: map['task'] as String,
      hardware: map['hardware'] as String,
      installed: map['installed'] as bool,
      tested: map['tested'] as bool,
      notes: map['notes'] as String,
    );
  }
}

class ModelRegistry {
  const ModelRegistry(this.models);

  final List<ModelEntry> models;

  bool get isEmpty => models.isEmpty;

  static ModelRegistry parse(String yamlText) {
    final doc = loadYaml(yamlText);
    if (doc is! YamlMap || !doc.containsKey('models')) {
      throw const FormatException('registry.yaml must have a top-level "models" list.');
    }
    final raw = doc['models'];
    if (raw == null) return const ModelRegistry([]);
    if (raw is! YamlList) {
      throw const FormatException('"models" must be a list.');
    }
    return ModelRegistry(
      raw.map((e) => ModelEntry.fromYaml(e as YamlMap)).toList(),
    );
  }
}
