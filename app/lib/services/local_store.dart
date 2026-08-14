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
