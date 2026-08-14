/// Feature flags — docs/BUILD_PLAN.md §1.
/// All four default false and flip on only after Phases 0–8 are proven.
/// Override at build time: --dart-define=FEATURE_AUTH=true
abstract final class FeatureFlags {
  static const auth = bool.fromEnvironment('FEATURE_AUTH');
  static const subscriptions = bool.fromEnvironment('FEATURE_SUBSCRIPTIONS');
  static const cloudSync = bool.fromEnvironment('FEATURE_CLOUD_SYNC');
  static const shopping = bool.fromEnvironment('FEATURE_SHOPPING');

  static const all = <String, bool>{
    'FEATURE_AUTH': auth,
    'FEATURE_SUBSCRIPTIONS': subscriptions,
    'FEATURE_CLOUD_SYNC': cloudSync,
    'FEATURE_SHOPPING': shopping,
  };
}

abstract final class AppInfo {
  static const name = 'Atelier';
  static const version = '0.0.0'; // Phase 0
}
