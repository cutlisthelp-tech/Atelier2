import 'dart:convert';

import 'package:atelier/models/size.dart';
import 'package:atelier/services/backend_client.dart';
import 'package:atelier/services/local_store.dart';
import 'package:atelier/theme/tokens.dart';
import 'package:atelier/ui/screens/size_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _bodyPayload = {
  'body': {
    'measurements_cm': {
      'height_input': 175.0,
      'shoulder': 44.0,
      'hip': 30.0,
      'torso': 55.0,
      'leg': 95.0,
      'arm': 60.0,
      'chest': null,
      'waist': null,
    },
    'proportions': {'torso_to_leg_ratio': 0.58, 'shoulder_to_hip_ratio': 1.47, 'vertical_balance': 0.37},
    'body_shape': 'inverted_triangle',
    'skeleton': <dynamic>[],
    'visible_landmarks': 27,
  },
  'confidence': 0.75,
  'flags': <dynamic>[],
};

SizeRecommendation _rec({List<String> flags = const []}) => SizeRecommendation(
      label: 'M',
      score: 1.0,
      confidence: 0.9,
      flags: flags,
      fitType: 'regular',
      brand: 'test-brand',
      regions: const [
        SizeRegion(region: 'chest', chartCm: 92, status: 'not_measurable', note: 'not measurable from one photo'),
        SizeRegion(region: 'shoulder', measuredCm: 44, chartCm: 46, deltaCm: 0, status: 'matched'),
        SizeRegion(region: 'sleeve', measuredCm: 60, chartCm: 62, deltaCm: 0, status: 'matched'),
      ],
      sizes: const [
        SizeScore(label: 'S', score: 0.5),
        SizeScore(label: 'M', score: 1.0),
        SizeScore(label: 'L', score: 0.25),
      ],
      note: 'Scored without chest (not measurable from one photo).',
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: buildAtelierTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

// SizeCheckScreen owns a Scaffold; pump it directly, never inside a scroll view.
Widget _app(Widget child) => MaterialApp(theme: buildAtelierTheme(), home: child);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('client parses the size envelope', () async {
    final client = BackendClient(
      baseUrl: 'http://backend.test',
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'http://backend.test/size/recommend');
        return http.Response(
          json.encode({
            'recommended': {'label': 'M', 'score': 1.0},
            'confidence': 0.9,
            'flags': <String>[],
            'fit_type': 'regular',
            'brand': 'test-brand',
            'regions': [
              {'region': 'chest', 'measured_cm': null, 'chart_cm': 92.0, 'status': 'not_measurable', 'note': 'not measurable from one photo'},
              {'region': 'shoulder', 'measured_cm': 44.0, 'chart_cm': 46.0, 'delta_cm': 0.0, 'status': 'matched'},
            ],
            'sizes': [
              {'label': 'S', 'score': 0.5},
              {'label': 'M', 'score': 1.0},
            ],
            'note': 'Scored without chest.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final outcome = await client.recommendSize(
      category: 'shirt',
      fitType: 'regular',
      bodyProfile: _bodyPayload,
      rows: [
        {'label': 'S', 'shoulder_cm': 44},
        {'label': 'M', 'shoulder_cm': 46},
      ],
    );
    expect(outcome, isA<SizeOk>());
    final rec = (outcome as SizeOk).recommendation;
    expect(rec.label, 'M');
    expect(rec.confidence, 0.9);
    expect(rec.regions.first.status, 'not_measurable');
  });

  test('client surfaces NO_SIZE_CHART from the envelope', () async {
    final client = BackendClient(
      baseUrl: 'http://backend.test',
      httpClient: MockClient((_) async => http.Response(
            json.encode({
              'error': {
                'code': 'NO_SIZE_CHART',
                'message': 'A size chart needs at least two sizes.',
              },
            }),
            422,
            headers: {'content-type': 'application/json'},
          )),
    );
    final outcome = await client.recommendSize(
      category: 'shirt',
      fitType: 'regular',
      bodyProfile: _bodyPayload,
      rows: [
        {'label': 'M', 'shoulder_cm': 46},
      ],
    );
    expect(outcome, isA<SizeFailure>());
    expect((outcome as SizeFailure).code, 'NO_SIZE_CHART');
  });

  testWidgets('result view shows size, confidence and the honest chest note',
      (tester) async {
    await tester.pumpWidget(_wrap(SizeResultView(recommendation: _rec())));
    await tester.pumpAndSettle();

    // The big recommended label and the ALL SIZES row both read "M".
    expect(find.text('M'), findsNWidgets(2));
    expect(find.textContaining('CONFIDENCE 90%'), findsOneWidget);
    expect(find.textContaining('not measurable from one photo'), findsWidgets);
    expect(find.textContaining('Scored without chest'), findsOneWidget);
  });

  testWidgets('low confidence is flagged plainly', (tester) async {
    await tester.pumpWidget(
        _wrap(SizeResultView(recommendation: _rec(flags: const ['LOW_CONFIDENCE']))));
    await tester.pumpAndSettle();
    expect(find.textContaining('LOW CONFIDENCE'), findsOneWidget);
  });

  testWidgets('without a body scan the screen states the honest prerequisite',
      (tester) async {
    await tester.pumpWidget(_app(SizeCheckScreen(
      backendClient: BackendClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient((_) async => http.Response('{}', 503)),
      ),
      bodyStore: ScanRecordStore.body(InMemoryKeyValueStore()),
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('Atelier hasn\u2019t measured you yet'),
        findsOneWidget);
    expect(find.text('Find my size'), findsNothing);
  });

  testWidgets('with a real stored scan the chart form appears',
      (tester) async {
    final store = InMemoryKeyValueStore();
    await ScanRecordStore.body(store).save(_bodyPayload);
    await tester.pumpWidget(_app(SizeCheckScreen(
      backendClient: BackendClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient((_) async => http.Response('{}', 503)),
      ),
      bodyStore: ScanRecordStore.body(store),
    )));
    await tester.pumpAndSettle();

    expect(find.text('SIZE CHART (CM)'), findsOneWidget);
    // The submit button sits below the fold in the lazy ListView.
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Find my size'), findsOneWidget);
    expect(find.text('Add a size'), findsOneWidget);
  });
}
