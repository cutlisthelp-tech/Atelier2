import 'package:atelier/models/analysis.dart';
import 'package:atelier/services/backend_client.dart';
import 'package:atelier/services/local_store.dart';
import 'package:atelier/services/model_manager.dart';
import 'package:atelier/ui/screens/profile_screen.dart';
import 'package:atelier/ui/screens/scan_result_screen.dart';
import 'package:atelier/ui/screens/style_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('consent gate', () {
    testWidgets('blocks the scan entry until biometric consent is granted',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = InMemoryKeyValueStore();
      final consent = ConsentStore(store);
      final style = StyleProfileStore(store);
      await style.save(const StyleProfile(heightCm: 178));

      await tester.pumpWidget(harness(ProfileScreen(
        modelManager: ModelManager(),
        consentStore: consent,
        styleStore: style,
        backendClient: BackendClient(),
      )));
      await tester.pump();

      await tester.tap(find.text('Body scan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Consent screen is up; the camera screen is not.
      expect(find.text('Before your first scan'), findsOneWidget);
      expect(find.text('Capture'), findsNothing);
      expect(await consent.isGranted, isFalse);

      await tester.tap(find.text('I understand — enable scanning'));
      await tester.pump();
      // Let the consent route close (exit animation) and the scan route open.
      await tester.pump(const Duration(milliseconds: 600));

      expect(await consent.isGranted, isTrue);
      expect(find.text('Before your first scan'), findsNothing);
    });
  });

  group('scan result rendering', () {
    // Payload shape mirrors the backend contract exactly; values exercise the
    // renderer, they are never presented to users from this code path.
    final bodyJson = {
      'body': {
        'measurements_cm': {
          'height_input': 178.0,
          'shoulder': 34.3,
          'hip': 23.3,
          'torso': 56.5,
          'leg': 96.6,
          'arm': 47.0,
          'chest': null,
          'waist': null,
        },
        'proportions': {
          'torso_to_leg_ratio': 0.584,
          'shoulder_to_hip_ratio': 1.472,
          'vertical_balance': 0.369,
        },
        'body_shape': 'inverted_triangle',
        'skeleton': [
          for (var i = 0; i < 33; i++)
            {'x': 0.5, 'y': i / 33.0, 'visibility': i < 27 ? 0.9 : 0.1},
        ],
        'visible_landmarks': 27,
      },
      'confidence': 0.757,
      'flags': <String>[],
    };

    testWidgets('renders real measurements, honest nulls and confidence',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final outcome = BodyScanSuccess(
        body: BodyProfile.fromJson(bodyJson['body'] as Map<String, dynamic>),
        confidence: (bodyJson['confidence'] as num).toDouble(),
        flags: const [],
      );
      await tester.pumpWidget(harness(ScanResultScreen(outcome: outcome)));
      await tester.pump();

      expect(find.text('Body profile'), findsOneWidget);
      expect(find.text('34.3 cm'), findsOneWidget);
      expect(find.text('CONFIDENCE 76%'), findsOneWidget);
      // chest/waist stay honest: dash, with the why spelled out.
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('not measurable from one photo'), findsNWidgets(2));
    });

    testWidgets('renders a failure state with its §12 code', (tester) async {
      await tester.pumpWidget(harness(const ScanResultScreen(
        outcome: ScanFailure(
          code: 'NO_PERSON',
          message: 'No person detected. Step back so your full body is in the frame.',
        ),
      )));
      await tester.pump();

      expect(find.text('This one didn’t work'), findsOneWidget);
      expect(find.text('NO_PERSON'), findsOneWidget);
    });
  });

  group('style profile persistence', () {
    testWidgets('round-trips through local JSON storage', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = StyleProfileStore(InMemoryKeyValueStore());

      await tester.pumpWidget(harness(StyleProfileScreen(store: store)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField).first, '181');
      await tester.tap(find.text('Relaxed'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(1), 'neon green');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Saved — on this device only.'), findsOneWidget);

      final saved = await store.load();
      expect(saved, isNotNull);
      expect(saved!.heightCm, 181.0);
      expect(saved.fitPreference, 'relaxed');
      expect(saved.bannedColors, ['neon green']);

      // A fresh screen reads the same values back. The key forces a new
      // State so the load path really runs.
      await tester.pumpWidget(harness(StyleProfileScreen(
        key: const ValueKey('fresh'),
        store: store,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('181.0'), findsOneWidget);
      expect(find.text('neon green'), findsOneWidget);
    });
  });
}
