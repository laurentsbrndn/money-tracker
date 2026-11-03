/// Build-time configuration injected with `--dart-define-from-file=env/<name>.json`.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );
  static const String revenueCatAndroidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
  );
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Terms of service and privacy policy pages, shown on the paywall. Empty
  /// hides the links.
  static const String termsUrl = String.fromEnvironment('TERMS_URL');
  static const String privacyUrl = String.fromEnvironment('PRIVACY_URL');
}
