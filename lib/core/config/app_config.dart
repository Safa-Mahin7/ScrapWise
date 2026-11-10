/// Application configuration — centralised so environment-specific
/// values (e.g. API base URL) can be changed without touching feature code.
class AppConfig {
  AppConfig._();

  /// Base URL for the FastAPI backend.
  /// Override this via compile-time `--dart-define=API_BASE_URL=https://...`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
