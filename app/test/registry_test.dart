import 'dart:io';

import 'package:atelier/models/model_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical registry parses and is intentionally empty in Phase 0', () {
    final text = File('../models/registry.yaml').readAsStringSync();
    final registry = ModelRegistry.parse(text);
    expect(registry.isEmpty, isTrue);
  });

  test('a complete entry parses', () {
    const yaml = '''
models:
  - name: pose_landmarker
    github: https://github.com/google-ai-edge/mediapipe
    revision: v0.10.14
    license: Apache-2.0
    weights: https://example.test/weights.task
    checksum: test-value-not-a-real-checksum
    runtime: mediapipe
    task: pose_landmarks
    hardware: cpu
    installed: false
    tested: false
    notes: schema test entry
''';
    final registry = ModelRegistry.parse(yaml);
    expect(registry.models, hasLength(1));
    expect(registry.models.single.task, 'pose_landmarks');
    expect(registry.models.single.installed, isFalse);
  });

  test('an entry missing required fields is rejected by name', () {
    const yaml = '''
models:
  - name: half_specified
    github: https://example.test/repo
''';
    expect(
      () => ModelRegistry.parse(yaml),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('half_specified'), contains('checksum')),
        ),
      ),
    );
  });
}
