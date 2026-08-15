/// Phase 3 app tests — local persistence round trips, HOME prerequisite
/// states, and honest rendering/parsing of the /recommend/outfit contract.
///
/// Contract-shaped payloads here exercise the renderer only; they are never
/// presented to users from this code path. Real user data comes only from
/// real backend responses.
library;

import 'dart:convert';

import 'package:atelier/models/recommendation.dart';
import 'package:atelier/services/backend_client.dart';
import 'package:atelier/services/local_store.dart';
import 'package:atelier/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(Widget child) => MaterialApp(home: Scaffold(body: child));

  final bodyPayload = {
    'body': {
      'measurements_cm': {
        'height_input': 178.0,
        'shoulder': 46.2,
        'hip': 40.1,
        'torso': 62.0,
        'leg': 96.0,
        'arm': 60.0,
        'chest': null,
        'waist': null,
      },
      'proportions': {
        'torso_to_leg_ratio': 0.65,
        'shoulder_to_hip_ratio': 1.15,
        'vertical_balance': 0.52,
      },
      'body_shape': 'inverted_triangle',
      'skeleton': <dynamic>[],
      'visible_landmarks': 27,
    },
    'confidence': 0.86,
    'flags': <String>[],
  };

  Map<String, dynamic> wardrobePayload(String category) => {
        'garment': {
          'category': {'value': category, 'confidence': 0.9},
          'colors': [
            {'name': 'charcoal', 'hex': '#2f3234', 'share': 0.6},
          ],
          'colors_source': 'segmentation',
          'pattern': {'value': null, 'confidence': 0.3},
          'fit': {'value': 'regular', 'confidence': 0.5},
          'material': {'value': 'cotton', 'confidence': 0.5},
        },
        'confidence': 0.8,
        'flags': <String>[],
      };

  final recommendationJson = {
    'context': {
      'occasion': 'dinner',
      'place_label': 'Casablanca',
      'weather': {
        'state': 'ok',
        'temperature_c': 22.3,
        'precipitation_mm': 0.0,
        'weather_code': 2,
        'weather_label': 'partly cloudy',
        'wind_kmh': 5.0,
        'observed_at': '2026-08-14T18:00',
      },
    },
    'factors': [
      {
        'name': 'body_fit',
        'base_weight': 18.0,
        'effective_weight': 20.0,
        'active': true,
        'inactive_reason': null,
        'score': 0.8,
        'contribution': 16.0,
      },
      {
        'name': 'trend',
        'base_weight': 6.0,
        'effective_weight': 0.0,
        'active': false,
        'inactive_reason': 'no trend feed is connected',
        'score': 0.0,
        'contribution': 0.0,
      },
    ],
    'outfits': [
      {
        'strategy': 'best_match',
        'score': 71.1,
        'garments': [
          {
            'id': 'g-sweater',
            'category': 'sweater',
            'colors': [
              {'name': 'charcoal', 'hex': '#2f3234', 'share': 0.6},
            ],
            'fit': 'regular',
            'material': null,
            'pattern': null,
          },
          {
            'id': 'g-jeans',
            'category': 'jeans',
            'colors': [
              {'name': 'blue', 'hex': '#3a5a8c', 'share': 0.7},
            ],
            'fit': 'slim',
            'material': 'denim',
            'pattern': null,
          },
        ],
        'why': ['Fit tracks your preference (67% across the pieces).'],
      },
    ],
    'excluded': {
      'hard_filters': <dynamic>[],
      'unplaceable': <dynamic>[],
      'filters_note': 'No hard filters applied.',
    },
    'shopping': {
      'state': 'CATALOG_NOT_CONNECTED',
      'message': 'No merchant catalog is connected.',
    },
  };

  group('local persistence round trips', () {
    test('scan records, wardrobe and home place survive save/load', () async {
      final kv = InMemoryKeyValueStore();
      final bodyStore = ScanRecordStore.body(kv);
      final appearanceStore = ScanRecordStore.appearance(kv);
      final wardrobeStore = WardrobeStore(kv);
      final placeStore = HomePlaceStore(kv);

      expect(await bodyStore.load(), isNull);
      await bodyStore.save(bodyPayload);
      await appearanceStore.save({'color': {}, 'confidence': 0.8, 'flags': []});
      final loadedBody = await bodyStore.load();
      expect(loadedBody, isNotNull);
      expect(loadedBody!.payload['confidence'], 0.86);
      expect(await appearanceStore.load(), isNotNull);

      final added = await wardrobeStore.add(wardrobePayload('sweater'));
      await wardrobeStore.add(wardrobePayload('jeans'));
      var items = await wardrobeStore.loadAll();
      expect(items.length, 2);
      expect(items.first.id, added.id);
      await wardrobeStore.remove(added.id);
      items = await wardrobeStore.loadAll();
      expect(items.length, 1);
      expect(
        (items.first.payload['garment'] as Map<String, dynamic>)['category'],
        {'value': 'jeans', 'confidence': 0.9},
      );

      expect(await placeStore.load(), isNull);
      await placeStore.save(const HomePlace(
          label: 'Casablanca', latitude: 33.5731, longitude: -7.5898));
      final place = await placeStore.load();
      expect(place!.label, 'Casablanca');
      expect(place.latitude, 33.5731);
    });
  });

  group('HOME prerequisite states', () {
    HomeScreen screen(KeyValueStore kv, BackendClient client, {Key? key}) =>
        HomeScreen(
          key: key,
          backendClient: client,
          bodyStore: ScanRecordStore.body(kv),
          appearanceStore: ScanRecordStore.appearance(kv),
          styleStore: StyleProfileStore(kv),
          wardrobeStore: WardrobeStore(kv),
          homePlaceStore: HomePlaceStore(kv),
        );

    testWidgets('no body scan points to Profile', (tester) async {
      await tester.pumpWidget(harness(screen(
          InMemoryKeyValueStore(), BackendClient(baseUrl: ''))));
      await tester.pump();
      expect(find.text('Atelier hasn\u2019t met you yet.'), findsOneWidget);
      expect(find.text('Open Profile'), findsOneWidget);
    });

    testWidgets('assemblable wardrobe is computed from real categories',
        (tester) async {
      final kv = InMemoryKeyValueStore();
      await ScanRecordStore.body(kv).save(bodyPayload);
      final wardrobe = WardrobeStore(kv);
      await wardrobe.add(wardrobePayload('sweater'));
      await tester.pumpWidget(harness(screen(
          kv, BackendClient(baseUrl: ''), key: const ValueKey('small'))));
      await tester.pump();
      expect(find.textContaining('can\u2019t form an outfit yet'),
          findsOneWidget);

      await wardrobe.add(wardrobePayload('jeans'));
      await wardrobe.add(wardrobePayload('sneakers'));
      await tester.pumpWidget(harness(screen(
          kv, BackendClient(baseUrl: ''), key: const ValueKey('full'))));
      await tester.pump();
      expect(find.text('Where should the outfit work?'), findsOneWidget);
    });
  });

  group('recommendation parsing', () {
    final validRequest = {
      'occasion': 'dinner',
      'location': {'latitude': 33.5731, 'longitude': -7.5898, 'label': 'Casablanca'},
      'body_profile': bodyPayload,
      'color_profile': null,
      'style_profile': {'fit_preference': 'regular'},
      'wardrobe': <dynamic>[],
    };

    test('200 envelope parses into a typed recommendation', () async {
      final client = BackendClient(
        baseUrl: 'http://atelier.test',
        httpClient: MockClient((req) async {
          expect(req.url.path, '/recommend/outfit');
          final sent = json.decode(req.body) as Map<String, dynamic>;
          expect(sent.keys, containsAll(validRequest.keys));
          return http.Response(json.encode(recommendationJson), 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final outcome = await client.recommendOutfit(
        occasion: 'dinner',
        latitude: 33.5731,
        longitude: -7.5898,
        placeLabel: 'Casablanca',
        bodyProfile: bodyPayload,
        styleProfile: const {'fit_preference': 'regular'},
        wardrobe: const [],
      );
      final success = outcome as RecommendSuccess;
      final rec = success.recommendation;
      expect(rec.occasion, 'dinner');
      expect(rec.weather.state, 'ok');
      expect(rec.weather.temperatureC, 22.3);
      expect(rec.outfits.single.strategy, 'best_match');
      expect(rec.outfits.single.score, 71.1);
      expect(rec.outfits.single.garments.first.category, 'sweater');
      expect(rec.factors[1].active, isFalse);
      expect(rec.factors[1].inactiveReason, 'no trend feed is connected');
      expect(rec.shoppingState, 'CATALOG_NOT_CONNECTED');
    });

    test('error envelope parses into a typed failure with its code',
        () async {
      final client = BackendClient(
        baseUrl: 'http://atelier.test',
        httpClient: MockClient((req) async => http.Response(
            json.encode({
              'error': {
                'code': 'INSUFFICIENT_DATA',
                'message': 'No shoes in the wardrobe.',
              }
            }),
            422,
            headers: {'content-type': 'application/json'})),
      );
      final outcome = await client.recommendOutfit(
        occasion: 'dinner',
        latitude: 33.5731,
        longitude: -7.5898,
        placeLabel: 'Casablanca',
        bodyProfile: bodyPayload,
        styleProfile: const {'fit_preference': 'regular'},
        wardrobe: const [],
      );
      final failure = outcome as RecommendFailure;
      expect(failure.code, 'INSUFFICIENT_DATA');
      expect(failure.message, 'No shoes in the wardrobe.');
    });

    test('unconfigured client fails honestly with NETWORK_ERROR', () async {
      final outcome = await BackendClient(baseUrl: '').recommendOutfit(
        occasion: 'dinner',
        latitude: 0,
        longitude: 0,
        placeLabel: '',
        bodyProfile: bodyPayload,
        styleProfile: const {},
        wardrobe: const [],
      );
      expect((outcome as RecommendFailure).code, 'NETWORK_ERROR');
    });
  });

  group('HOME result rendering', () {
    testWidgets('renders only what the response contains', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final kv = InMemoryKeyValueStore();
      await ScanRecordStore.body(kv).save(bodyPayload);
      final wardrobe = WardrobeStore(kv);
      await wardrobe.add(wardrobePayload('sweater'));
      await wardrobe.add(wardrobePayload('jeans'));
      await wardrobe.add(wardrobePayload('sneakers'));
      await HomePlaceStore(kv).save(const HomePlace(
          label: 'Casablanca', latitude: 33.5731, longitude: -7.5898));

      final client = BackendClient(
        baseUrl: 'http://atelier.test',
        httpClient: MockClient((req) async {
          final sent = json.decode(req.body) as Map<String, dynamic>;
          // The stored payloads round-trip verbatim; embeddings are stripped
          // in transit, never the analysis itself.
          expect(sent['body_profile'], bodyPayload);
          final entries = sent['wardrobe'] as List<dynamic>;
          expect(entries.length, 3);
          expect(
            (entries.first as Map<String, dynamic>)['garment'],
            isNot(contains('embedding')),
          );
          return http.Response(json.encode(recommendationJson), 200,
              headers: {'content-type': 'application/json'});
        }),
      );

      await tester.pumpWidget(harness(HomeScreen(
        backendClient: client,
        bodyStore: ScanRecordStore.body(kv),
        appearanceStore: ScanRecordStore.appearance(kv),
        styleStore: StyleProfileStore(kv),
        wardrobeStore: wardrobe,
        homePlaceStore: HomePlaceStore(kv),
      )));
      await tester.pump();

      expect(find.text('Casablanca'), findsOneWidget);
      expect(find.text('Score my best outfit'), findsOneWidget);
      await tester.tap(find.text('Score my best outfit'));
      await tester.pump();

      expect(find.text('Personal Match'), findsOneWidget);
      expect(find.text('71'), findsOneWidget); // score ring, rounded
      expect(find.textContaining('dinner \u00B7 Casablanca \u00B7 22.3\u00B0C'),
          findsOneWidget);
      expect(find.text('sweater'), findsOneWidget);
      expect(find.text('jeans'), findsOneWidget);
      expect(find.text('Why it works'), findsOneWidget);
      expect(find.text('How the score is built'), findsOneWidget);

      await tester.tap(find.text('SHOP THIS LOOK'));
      await tester.pump();
      expect(
        find.textContaining('CATALOG_NOT_CONNECTED'),
        findsOneWidget,
      );
    });
  });
}
