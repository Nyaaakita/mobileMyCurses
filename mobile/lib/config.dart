/// Базовый URL Go API (не PostgreSQL — с БД общается только бэкенд).
///
/// По умолчанию [10.0.2.2] — «localhost ПК» только у **Android-эмулятора**.
/// На **физическом телефоне** укажите IPv4 компьютера в той же Wi‑Fi-сети, например:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080`
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    "API_BASE_URL",
    defaultValue: "http://10.0.2.2:8080",
  );

  static Uri get apiBaseUri {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError("Invalid API_BASE_URL: $apiBaseUrl");
    }
    return uri;
  }
}
