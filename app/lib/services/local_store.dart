/// Local persistence: biometric consent and the Style Profile.
///
/// Storage is injectable so tests can run without path_provider; production
/// uses JSON files in the app documents directory. Phase 9 migrates this to
/// remote sync (recorded in docs/ARCHITECTURE.md) — until then everything
/// stays on this device.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class FileKeyValueStore implements KeyValueStore {
  FileKeyValueStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _file(String key) async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$key.json');
  }

  @override
  Future<String?> read(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String value) async {
    final file = await _file(key);
    await file.writeAsString(value);
  }
}

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

/// Explicit biometric opt-in (BUILD_PLAN §5). Scanning is blocked until
/// granted; the grant timestamp is stored locally.
class ConsentStore {
  ConsentStore(this._store);

  static const _key = 'biometric_consent_v1';
  final KeyValueStore _store;

  Future<DateTime?> grantedAt() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<bool> get isGranted async => (await grantedAt()) != null;

  Future<void> grant() => _store.write(_key, DateTime.now().toUtc().toIso8601String());
}

class StyleProfile {
  const StyleProfile({
    this.heightCm,
    this.fitPreference = 'regular',
    this.aesthetics = const [],
    this.bannedColors = const [],
    this.bannedBrands = const [],
    this.budgetCeiling,
  });

  final double? heightCm;
  final String fitPreference;
  final List<String> aesthetics;
  final List<String> bannedColors;
  final List<String> bannedBrands;
  final double? budgetCeiling;

  Map<String, dynamic> toJson() => {
        'height_cm': heightCm,
        'fit_preference': fitPreference,
        'aesthetics': aesthetics,
        'banned_colors': bannedColors,
        'banned_brands': bannedBrands,
        'budget_ceiling': budgetCeiling,
      };

  factory StyleProfile.fromJson(Map<String, dynamic> json) => StyleProfile(
        heightCm: (json['height_cm'] as num?)?.toDouble(),
        fitPreference: json['fit_preference'] as String? ?? 'regular',
        aesthetics: (json['aesthetics'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        bannedColors: (json['banned_colors'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        bannedBrands: (json['banned_brands'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        budgetCeiling: (json['budget_ceiling'] as num?)?.toDouble(),
      );
}

class StyleProfileStore {
  StyleProfileStore(this._store);

  static const _key = 'style_profile_v1';
  final KeyValueStore _store;

  Future<StyleProfile?> load() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    return StyleProfile.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<void> save(StyleProfile profile) =>
      _store.write(_key, json.encode(profile.toJson()));
}

/// A raw analysis payload plus its capture time, stored losslessly so what
/// the app sends back for scoring is byte-for-byte what the backend produced.
class ScanRecord {
  const ScanRecord({required this.payload, required this.capturedAt});

  final Map<String, dynamic> payload;
  final DateTime capturedAt;

  Map<String, dynamic> toJson() => {
        'payload': payload,
        'captured_at': capturedAt.toUtc().toIso8601String(),
      };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
        payload: json['payload'] as Map<String, dynamic>,
        capturedAt: DateTime.parse(json['captured_at'] as String),
      );
}

class ScanRecordStore {
  ScanRecordStore(this._store, this._key);

  static ScanRecordStore body(KeyValueStore store) =>
      ScanRecordStore(store, 'body_scan_v1');
  static ScanRecordStore appearance(KeyValueStore store) =>
      ScanRecordStore(store, 'appearance_scan_v1');

  final KeyValueStore _store;
  final String _key;

  Future<ScanRecord?> load() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    return ScanRecord.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<void> save(Map<String, dynamic> payload) => _store.write(
      _key,
      json.encode(ScanRecord(
        payload: payload,
        capturedAt: DateTime.now().toUtc(),
      ).toJson()));
}

/// Phase 3 borrows minimal wardrobe persistence (analysis JSON only — user
/// captures are never written to disk, BUILD_PLAN §5). Phase 7 owns the
/// full Wardrobe module.
class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.addedAt,
    required this.payload,
  });

  final String id;
  final DateTime addedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
        'id': id,
        'added_at': addedAt.toUtc().toIso8601String(),
        'payload': payload,
      };

  factory WardrobeItem.fromJson(Map<String, dynamic> json) => WardrobeItem(
        id: json['id'] as String,
        addedAt: DateTime.parse(json['added_at'] as String),
        payload: json['payload'] as Map<String, dynamic>,
      );
}

class WardrobeStore {
  WardrobeStore(this._store);

  static const _key = 'wardrobe_v1';
  final KeyValueStore _store;
  int _counter = 0;

  Future<List<WardrobeItem>> loadAll() async {
    final raw = await _store.read(_key);
    if (raw == null) return [];
    return (json.decode(raw) as List<dynamic>)
        .map((e) => WardrobeItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WardrobeItem> add(Map<String, dynamic> payload) async {
    final items = await loadAll();
    final item = WardrobeItem(
      id: '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_counter++}',
      addedAt: DateTime.now().toUtc(),
      payload: payload,
    );
    await _store.write(_key, json.encode([...items, item].map((e) => e.toJson()).toList()));
    return item;
  }

  Future<void> remove(String id) async {
    final items = await loadAll();
    await _store.write(
        _key,
        json.encode(
            items.where((e) => e.id != id).map((e) => e.toJson()).toList()));
  }
}

class HomePlace {
  const HomePlace({required this.label, required this.latitude, required this.longitude});

  final String label;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() =>
      {'label': label, 'latitude': latitude, 'longitude': longitude};

  factory HomePlace.fromJson(Map<String, dynamic> json) => HomePlace(
        label: json['label'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

class HomePlaceStore {
  HomePlaceStore(this._store);

  static const _key = 'home_place_v1';
  final KeyValueStore _store;

  Future<HomePlace?> load() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    return HomePlace.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<void> save(HomePlace place) => _store.write(_key, json.encode(place.toJson()));
}
