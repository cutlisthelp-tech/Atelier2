import 'dart:convert';
import 'dart:typed_data';

import 'package:atelier/models/search.dart';
import 'package:atelier/services/backend_client.dart';
import 'package:atelier/services/local_store.dart';
import 'package:atelier/theme/tokens.dart';
import 'package:atelier/ui/screens/wardrobe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _searchJson({bool empty = false}) => {
      'state': empty ? 'NO_MATCH_FOUND' : 'ok',
      'matches': empty
          ? <Map<String, dynamic>>[]
          : [
              {'id': 'g-sweater', 'similarity': 1.0, 'tier': 'exact_match'},
              {'id': 'g-tshirt', 'similarity': 0.74, 'tier': 'inspired'},
            ],
      'index': 'stateless',
      'method': 'fashionclip_cosine',
      'tiers': {'exact_match': 0.92, 'close_match': 0.80, 'inspired': 0.68},
      'catalog': {
        'same_product_other_merchant': 'CATALOG_NOT_CONNECTED',
        'budget_alternative': 'CATALOG_NOT_CONNECTED',
        'note': 'No merchant catalog is connected — merchant tiers stay unavailable.',
      },
      'message': empty ? 'No match found — nothing in the index clears the similarity floor.' : '',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BackendClient clientReturning(Map<String, dynamic> body, [int status = 200]) =>
      BackendClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'http://backend.test/search/similar');
          return http.Response(json.encode(body), status,
              headers: {'content-type': 'application/json'});
        }),
      );

  final candidates = [
    {'id': 'g-sweater', 'embedding': List.filled(512, 0.1)},
  ];

  test('client parses the tiered search envelope', () async {
    final outcome = await clientReturning(_searchJson())
        .searchSimilar(Uint8List(8), candidates);
    expect(outcome, isA<SearchOk>());
    final result = (outcome as SearchOk).result;
    expect(result.state, 'ok');
    expect(result.matches, hasLength(2));
    expect(result.matches[0].tier, 'exact_match');
    expect(result.matches[0].similarity, 1.0);
    expect(result.index, 'stateless');
    expect(result.catalogNote, contains('No merchant catalog'));
  });

  test('no-match stays a real result, never a fabricated guess', () async {
    final outcome = await clientReturning(_searchJson(empty: true))
        .searchSimilar(Uint8List(8), candidates);
    final result = (outcome as SearchOk).result;
    expect(result.state, 'NO_MATCH_FOUND');
    expect(result.matches, isEmpty);
    expect(result.message, contains('No match found'));
  });

  test('client surfaces §12 codes from the search envelope', () async {
    final outcome = await clientReturning({
      'error': {'code': 'POOR_IMAGE', 'message': 'Blurry or dark.'},
    }, 422).searchSimilar(Uint8List(8), candidates);
    expect(outcome, isA<SearchFailure>());
    expect((outcome as SearchFailure).code, 'POOR_IMAGE');
  });

  testWidgets('wardrobe shows the Find-this-look panel', (tester) async {
    final store = InMemoryKeyValueStore();
    await WardrobeStore(store).add({
      'garment': {
        'category': {'value': 'sweater', 'confidence': 0.9},
        'embedding': List.filled(512, 0.1),
      },
      'confidence': 0.9,
      'flags': <String>[],
    });

    await tester.pumpWidget(MaterialApp(
      theme: buildAtelierTheme(),
      home: Scaffold(
        body: WardrobeScreen(
          backendClient: clientReturning(_searchJson()),
          wardrobeStore: WardrobeStore(store),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Find this look'), findsOneWidget);
    expect(
      find.textContaining('your real wardrobe index'),
      findsOneWidget,
    );
  });
}
