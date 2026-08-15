import 'package:atelier/models/analysis.dart';
import 'package:atelier/services/backend_client.dart';
import 'package:atelier/ui/screens/garment_scan_screen.dart';
import 'package:atelier/ui/screens/scan_result_screen.dart';
import 'package:atelier/ui/screens/wardrobe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  // Payload shape mirrors the backend contract exactly; values exercise the
  // renderer, they are never presented to users from this code path.
  final garmentJson = {
    'garment': {
      'category': {'value': 'sweater', 'confidence': 0.818},
      'colors': [
        {'name': 'charcoal', 'hex': '#2f3234', 'share': 0.436},
        {'name': 'white', 'hex': '#edefee', 'share': 0.388},
      ],
      'colors_source': 'segmentation',
      'clothing_mask_share': 0.3989,
      'pattern': {'value': null, 'confidence': 0.31},
      'fit': {'value': 'oversized', 'confidence': 0.503},
      'material': {'value': null, 'confidence': 0.29},
      'embedding': List<dynamic>.filled(512, 0.01),
    },
    'confidence': 0.846,
    'flags': <String>[],
  };

  group('garment result rendering', () {
    testWidgets('renders real attributes, honest unknowns and confidence',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final body = garmentJson;
      final outcome = GarmentScanSuccess(
        garment:
            GarmentProfile.fromJson(body['garment'] as Map<String, dynamic>),
        confidence: (body['confidence'] as num).toDouble(),
        flags: const [],
      );
      await tester.pumpWidget(harness(ScanResultScreen(outcome: outcome)));
      await tester.pump();

      expect(find.text('Garment read'), findsOneWidget);
      expect(find.text('CONFIDENCE 85%'), findsOneWidget);
      expect(find.text('SWEATER'), findsOneWidget);
      expect(find.text('OVERSIZED'), findsOneWidget);
      // Pattern and material are honestly unknown: UNKNOWN plus the why.
      expect(find.text('UNKNOWN'), findsNWidgets(2));
      expect(
          find.text('not reliably visible in this photo'), findsNWidgets(2));
      expect(find.text('#2f3234 · 44%'), findsOneWidget);
    });

    testWidgets('renders a garment failure state with its §12 code',
        (tester) async {
      await tester.pumpWidget(harness(const ScanResultScreen(
        outcome: ScanFailure(
          code: 'INSUFFICIENT_DATA',
          message:
              'No garment detected. Photograph one clothing item, close and centered.',
        ),
      )));
      await tester.pump();

      expect(find.text('This one didn’t work'), findsOneWidget);
      expect(find.text('INSUFFICIENT_DATA'), findsOneWidget);
    });
  });

  group('wardrobe garment entry', () {
    testWidgets('opens the garment scan from the wardrobe tab',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness(WardrobeScreen(
        backendClient: BackendClient(),
      )));
      await tester.pump();

      expect(find.text('Your wardrobe is empty.'), findsOneWidget);
      await tester.tap(find.text('Photograph a garment'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(GarmentScanScreen), findsOneWidget);
    });

    testWidgets('reports a missing camera honestly', (tester) async {
      await tester.pumpWidget(harness(GarmentScanScreen(
        client: BackendClient(),
        camerasFinder: () async => const [],
      )));
      await tester.pump();

      expect(
          find.text('No camera was found on this device.'), findsOneWidget);
      expect(find.text('Capture'), findsNothing);
    });
  });
}
