import 'dart:io';

import 'package:atelier/models/model_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonical registry parses with the two Phase 1 models', () {
    final text = File('../models/registry.yaml').readAsStringSync();
    final registry = ModelRegistry.parse(text);
    final byName = {for (final m in registry.models) m.name: m};
    expect(byName.keys, containsAll(['pose_landmarker_full', 'face_landmarker']));
    // Real checksums computed from the actual downloads (2026-08-14).
    expect(
      byName['pose_landmarker_full']!.checksum,
      '4eaa5eb7a98365221087693fcc286334cf0858e2eb6e15b506aa4a7ecdcec4ad',
    );
    expect(
      byName['face_landmarker']!.checksum,
      '64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff',
    );
    expect(byName['pose_landmarker_full']!.installed, isTrue);
    expect(byName['face_landmarker']!.installed, isTrue);
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
