import 'dart:convert';
import 'dart:typed_data';

import 'package:atelier/models/tryon.dart';
import 'package:atelier/services/backend_client.dart';
import 'package:atelier/theme/tokens.dart';
import 'package:atelier/ui/screens/try_on_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// 1x1 transparent PNG — decodable placeholder pixels for layout only; every
// assertion is about labels and states, not about the image content.
const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

Uint8List get _bytes => base64Decode(_png);

TryOnSuccess _success({List<String> flags = const []}) => TryOnSuccess(
      render: TryOnRender(
        imageBytes: _bytes,
        method: 'image_based_vton',
        provider: 'fashn',
      ),
      confidence: 0.87,
      flags: flags,
      category: 'sweater',
    );

// The result view lives inside a ListView on the real screen; the scroll
// view mirrors that so tall content never overflows the test viewport.
Widget _wrapScroll(Widget child) => MaterialApp(
      theme: buildAtelierTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: buildAtelierTheme(),
      home: Scaffold(body: child),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('try-on screen starts with choose affordances, render disabled',
      (tester) async {
    await tester.pumpWidget(_wrap(TryOnScreen(
      backendClient: BackendClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient((_) async => http.Response('{}', 503)),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Try On'), findsOneWidget);
    expect(find.text('PHOTO OF YOU'), findsOneWidget);
    expect(find.text('GARMENT'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull,
        reason: 'render must stay disabled until both photos are chosen');
  });

  testWidgets('result view shows method and confidence permanently',
      (tester) async {
    await tester.pumpWidget(
        _wrapScroll(TryOnResultView(result: _success(), person: _bytes)));
    await tester.pumpAndSettle();

    expect(find.text('image_based_vton · fashn'), findsOneWidget);
    expect(find.text('CONFIDENCE 87%'), findsOneWidget);
    expect(find.text('BEFORE'), findsOneWidget);
    expect(find.text('AFTER'), findsOneWidget);
    expect(find.textContaining('LOW CONFIDENCE'), findsNothing);
  });

  testWidgets('low confidence is flagged plainly, never hidden',
      (tester) async {
    await tester.pumpWidget(_wrapScroll(TryOnResultView(
      result: _success(flags: const ['LOW_CONFIDENCE']),
      person: _bytes,
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('LOW CONFIDENCE'), findsOneWidget);
  });

  test('client parses the labeled try-on envelope', () async {
    final client = BackendClient(
      baseUrl: 'http://backend.test',
      httpClient: MockClient((request) async {
        expect(request.url.toString(),
            'http://backend.test/tryon/render');
        return http.Response(
          json.encode({
            'render': {
              'image': _png,
              'mime': 'image/jpeg',
              'method': 'image_based_vton',
              'provider': 'fashn',
            },
            'confidence': 0.87,
            'flags': <String>[],
            'garment': {'category': 'sweater', 'category_confidence': 0.82},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final outcome = await client.renderTryOn(_bytes, _bytes);
    expect(outcome, isA<TryOnOk>());
    final result = (outcome as TryOnOk).result;
    expect(result.render.method, 'image_based_vton');
    expect(result.render.provider, 'fashn');
    expect(result.confidence, 0.87);
    expect(result.category, 'sweater');
  });

  test('client surfaces §12 codes from the try-on envelope', () async {
    final client = BackendClient(
      baseUrl: 'http://backend.test',
      httpClient: MockClient((_) async => http.Response(
            json.encode({
              'error': {
                'code': 'MODEL_MISSING',
                'message': 'Try-on isn\u2019t connected yet.',
              },
            }),
            503,
            headers: {'content-type': 'application/json'},
          )),
    );
    final outcome = await client.renderTryOn(_bytes, _bytes);
    expect(outcome, isA<TryOnFailure>());
    expect((outcome as TryOnFailure).code, 'MODEL_MISSING');
  });
}
