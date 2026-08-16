import 'dart:convert';

import 'package:atelier/services/backend_client.dart';
import 'package:atelier/services/local_store.dart';
import 'package:atelier/theme/tokens.dart';
import 'package:atelier/ui/screens/wardrobe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _garmentPayload({
  required String? category,
  String fit = 'regular',
  String pattern = 'solid',
  String material = 'cotton',
  List<String> flags = const [],
}) =>
    {
      'garment': {
        'category': {'value': category, 'confidence': 0.9},
        'colors': [
          {'name': 'charcoal', 'hex': '#2f3234', 'share': 0.6},
        ],
        'colors_source': 'center_weighted',
        'pattern': {'value': pattern, 'confidence': 0.5},
        'fit': {'value': fit, 'confidence': 0.5},
        'material': {'value': material, 'confidence': 0.5},
      },
      'confidence': 0.85,
      'flags': flags,
    };

const _bodyPayload = {
  'body': {
    'measurements_cm': {
      'height_input': 178.0, 'shoulder': 44.0, 'hip': 30.0,
      'torso': 55.0, 'leg': 96.0, 'arm': 60.0, 'chest': null, 'waist': null,
    },
    'proportions': {'torso_to_leg_ratio': 0.57, 'shoulder_to_hip_ratio': 1.47, 'vertical_balance': 0.36},
    'body_shape': 'inverted_triangle',
    'skeleton': <dynamic>[],
    'visible_landmarks': 27,
  },
  'confidence': 0.75,
  'flags': <dynamic>[],
};

Map<String, dynamic> _recommendJson() => {
      'context': {
        'occasion': 'casual lunch',
        'place_label': 'Casablanca',
        'weather': {
          'state': 'ok',
          'temperature_c': 22.0,
          'precipitation_mm': 0.0,
          'weather_code': 2,
          'weather_label': 'partly cloudy',
          'wind_kmh': 5.0,
          'observed_at': '2026-08-16T12:00',
        },
      },
      'factors': [
        {
          'name': 'body_fit', 'base_weight': 18.0, 'effective_weight': 20.0,
          'active': true, 'inactive_reason': null, 'score': 0.8, 'contribution': 16.0,
        },
      ],
      'outfits': [
        {
          'strategy': 'best_match',
          'score': 71.1,
          'garments': [
            {
              'id': 'g-sweater', 'category': 'sweater',
              'colors': [
                {'name': 'charcoal', 'hex': '#2f3234', 'share': 0.6},
              ],
              'fit': 'oversized', 'material': 'cotton', 'pattern': 'plaid',
            },
          ],
          'why': ['Fit tracks your preference.'],
        },
        {
          'strategy': 'safer',
          'score': 64.3,
          'garments': [
            {
              'id': 'g-tshirt', 'category': 't-shirt',
              'colors': [
                {'name': 'black', 'hex': '#101010', 'share': 0.8},
              ],
              'fit': 'regular', 'material': 'cotton', 'pattern': 'graphic',
            },
          ],
          'why': ['Right for casual lunch.'],
        },
      ],
      'excluded': {
        'hard_filters': <Map<String, dynamic>>[],
        'unplaceable': <Map<String, dynamic>>[],
        'filters_note': '',
      },
      'shopping': {
        'state': 'CATALOG_NOT_CONNECTED',
        'message': 'No merchant catalog is connected yet.',
      },
    };

Widget _wrap(Widget child) =>
    MaterialApp(theme: buildAtelierTheme(), home: Scaffold(body: child));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BackendClient mockClient() => BackendClient(
        baseUrl: 'http://backend.test',
        httpClient: MockClient((_) async => http.Response(
              json.encode(_recommendJson()),
              200,
              headers: {'content-type': 'application/json'},
            )),
      );

  testWidgets('rich cards read real attributes, Unknown stays Unknown',
      (tester) async {
    final store = InMemoryKeyValueStore();
    final wardrobe = WardrobeStore(store);
    await wardrobe.add(_garmentPayload(
      category: 'sweater', fit: 'oversized', pattern: 'plaid',
    ));
    await wardrobe.add(_garmentPayload(category: null));

    await tester.pumpWidget(_wrap(WardrobeScreen(
      backendClient: mockClient(),
      wardrobeStore: wardrobe,
    )));
    await tester.pumpAndSettle();

    expect(find.text('sweater'), findsOneWidget);
    expect(find.text('fit oversized · pattern plaid · material cotton'),
        findsOneWidget);
    expect(find.text('Unidentified'), findsOneWidget);
    expect(find.text('85%'), findsNWidgets(2));

    // The filter chips scope the list.
    await tester.tap(find.text('shoes'));
    await tester.pumpAndSettle();
    expect(find.text('sweater'), findsNothing);
  });

  testWidgets('session-only storage is labeled honestly', (tester) async {
    final store = InMemoryKeyValueStore();
    await tester.pumpWidget(_wrap(WardrobeScreen(
      backendClient: mockClient(),
      wardrobeStore: WardrobeStore(store),
      sessionStorage: true,
    )));
    await tester.pumpAndSettle();
    expect(
      find.text(
          'Session preview storage — nothing is saved after this tab closes.'),
      findsOneWidget,
    );
  });

  testWidgets('closet scoring renders real alternatives from the backend',
      (tester) async {
    final store = InMemoryKeyValueStore();
    final wardrobe = WardrobeStore(store);
    await wardrobe.add(_garmentPayload(category: 'sweater'));
    await wardrobe.add(_garmentPayload(category: 'jeans'));
    await wardrobe.add(_garmentPayload(category: 'sneakers'));
    await ScanRecordStore.body(store).save(_bodyPayload);
    await HomePlaceStore(store).save(
      const HomePlace(latitude: 33.5731, longitude: -7.5898, label: 'Casablanca'),
    );

    await tester.pumpWidget(_wrap(WardrobeScreen(
      backendClient: mockClient(),
      wardrobeStore: wardrobe,
      bodyStore: ScanRecordStore.body(store),
      homePlaceStore: HomePlaceStore(store),
    )));
    await tester.pumpAndSettle();

    // The closet panel sits below the fold in the lazy ListView.
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Best outfit from my closet'), findsOneWidget);
    await tester.tap(find.text('Score my closet'));
    await tester.pumpAndSettle();

    expect(find.text('Personal Match'), findsOneWidget);
    expect(find.text('safer'), findsOneWidget);
    expect(find.text('64.3'), findsOneWidget);
  });
}
