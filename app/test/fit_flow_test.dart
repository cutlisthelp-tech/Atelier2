/// FIT FLOW — guided fit check wired to the real Phase 5 size engine.
///
/// The screen must never carry sample content: it renders a real SizeCheck
/// result from POST /size/recommend, or the honest §12 states —
/// INSUFFICIENT_DATA (no body scan), NO_SIZE_CHART, and NETWORK_ERROR when
/// no backend is configured. A skipped region stays "not measurable",
/// never a guess.
library;

import 'dart:convert';

import 'package:atelier/services/backend_client.dart';
import 'package:atelier/services/local_store.dart';
import 'package:atelier/ui/screens/fit_flow_screen.dart';
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

Map<String, dynamic> _okEnvelope() => {
      'recommended': {'label': 'M', 'score': 1.0},
      'confidence': 0.9,
      'flags': <String>[],
      'fit_type': 'regular',
      'brand': '',
      'regions': [
        {'region': 'chest', 'measured_cm': null, 'chart_cm': 92.0, 'status': 'not_measurable', 'note': 'not measurable from one photo'},
        {'region': 'shoulder', 'measured_cm': 44.0, 'chart_cm': 46.0, 'delta_cm': 0.0, 'status': 'matched'},
      ],
      'sizes': [
        {'label': 'S', 'score': 0.5},
        {'label': 'M', 'score': 1.0},
      ],
      'note': 'Scored without chest.',
    };

Widget _app(Widget child) => MaterialApp(home: child);

BackendClient _client(MockClient mock) =>
    BackendClient(baseUrl: 'http://backend.test', httpClient: mock);

Future<void> _pumpWithBody(
  WidgetTester tester,
  BackendClient client, {
  bool saveBody = true,
}) async {
  final store = InMemoryKeyValueStore();
  if (saveBody) {
    await ScanRecordStore.body(store).save(_bodyPayload);
  }
  await tester.pumpWidget(_app(FitFlowScreen(
    backendClient: client,
    bodyStore: ScanRecordStore.body(store),
  )));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('without a body scan the honest prerequisite is shown',
      (tester) async {
    await _pumpWithBody(
      tester,
      _client(MockClient((_) async => http.Response('{}', 503))),
      saveBody: false,
    );

    expect(find.textContaining('Atelier hasn\u2019t measured you yet'),
        findsOneWidget);
    // No form, no sample content — a real screen never fakes a result.
    expect(find.text('Continue'), findsNothing);
    expect(find.textContaining('SAMPLE DATA'), findsNothing);
  });

  testWidgets('a real stored scan produces a real size result',
      (tester) async {
    var calls = 0;
    final client = _client(MockClient((request) async {
      calls++;
      expect(request.url.toString(), 'http://backend.test/size/recommend');
      return http.Response(
        json.encode(_okEnvelope()),
        200,
        headers: {'content-type': 'application/json'},
      );
    }));
    await _pumpWithBody(tester, client);

    // Step 1 — the garment: real scan context + taxonomy, then continue.
    expect(find.textContaining('Your body scan'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Step 2 — the chart: fill shoulder for the two existing sizes S and M.
    // Row field order: label, chest, waist, hip, shoulder, sleeve, length.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(4), '44'); // S shoulder
    await tester.enterText(fields.at(11), '46'); // M shoulder
    await tester.pump();

    // The CTA is persistent; the result it produces renders in the list.
    await tester.tap(find.text('Check my fit'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(find.textContaining('CONFIDENCE 90%'), findsOneWidget);
    expect(find.textContaining('not measurable from one photo'), findsWidgets);
  });

  testWidgets('NO_SIZE_CHART from the engine is stated plainly',
      (tester) async {
    final client = _client(MockClient((_) async => http.Response(
          json.encode({
            'error': {
              'code': 'NO_SIZE_CHART',
              'message': 'A size chart needs at least two sizes.',
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        )));
    await _pumpWithBody(tester, client);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check my fit'));
    await tester.pumpAndSettle();
    // The honest failure renders in the list below the chart rows.
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('NO_SIZE_CHART'), findsOneWidget);
    expect(
      find.textContaining('A size chart needs at least two sizes.'),
      findsOneWidget,
    );
  });

  testWidgets('fewer than two rows are caught before any network call',
      (tester) async {
    var calls = 0;
    final client = _client(MockClient((_) async {
      calls++;
      return http.Response('{}', 500);
    }));
    await _pumpWithBody(tester, client);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Remove two of the three default rows, leaving one.
    await tester.tap(find.byTooltip('Remove this size').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove this size').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check my fit'));
    await tester.pumpAndSettle();

    expect(calls, 0);
    // The validation note sits in the persistent footer — always visible.
    expect(
      find.textContaining('Enter at least two sizes'),
      findsOneWidget,
    );
  });

  testWidgets('an unconfigured backend is an honest NETWORK_ERROR',
      (tester) async {
    final store = InMemoryKeyValueStore();
    await ScanRecordStore.body(store).save(_bodyPayload);
    await tester.pumpWidget(_app(FitFlowScreen(
      backendClient: BackendClient(baseUrl: ''),
      bodyStore: ScanRecordStore.body(store),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check my fit'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('NETWORK_ERROR'), findsOneWidget);
    expect(find.textContaining('No backend is configured'), findsOneWidget);
  });
}
