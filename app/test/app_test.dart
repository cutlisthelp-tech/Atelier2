import 'dart:io';

import 'package:atelier/app.dart';
import 'package:atelier/models/model_registry.dart';
import 'package:atelier/services/model_manager.dart';
import 'package:flutter/material.dart' show Size;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots with five tabs, each showing an honest empty state',
      (tester) async {
    await tester.pumpWidget(const AtelierApp());
    await tester.pumpAndSettle();

    for (final label in ['HOME', 'DISCOVER', 'TRY ON', 'WARDROBE', 'PROFILE']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Your best look appears here.'), findsOneWidget);

    await tester.tap(find.text('DISCOVER'));
    await tester.pumpAndSettle();
    expect(find.text('No catalog connected.'), findsOneWidget);

    await tester.tap(find.text('TRY ON'));
    await tester.pumpAndSettle();
    expect(find.text('Try On isn\'t connected yet.'), findsOneWidget);

    await tester.tap(find.text('WARDROBE'));
    await tester.pumpAndSettle();
    expect(find.text('Your wardrobe is empty.'), findsOneWidget);

    await tester.tap(find.text('PROFILE'));
    await tester.pumpAndSettle();
    expect(find.text('Diagnostics'), findsOneWidget);
  });

  testWidgets('diagnostics reports registry state honestly', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Seed the manager from the canonical registry file so this test is
    // deterministic regardless of asset-bundle timing in the fake-async zone.
    final registry = ModelRegistry.parse(
      File('../models/registry.yaml').readAsStringSync(),
    );

    await tester.pumpWidget(AtelierApp(modelManager: ModelManager(seed: registry)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('PROFILE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Diagnostics'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('pose_landmarker_full'), findsOneWidget);
    expect(find.text('face_landmarker'), findsOneWidget);
    // Stated twice, honestly: the health probe and the backend-models probe.
    expect(find.text('Backend URL not configured.'), findsNWidgets(2));
    expect(find.text('FEATURE_AUTH'), findsOneWidget);
    expect(find.text('false'), findsNWidgets(4));
  });
}
