import "dart:io" show Platform;

/// Базовый URL Go API (не PostgreSQL — с БД общается только бэкенд).
///
/// По умолчанию: **Android-эмулятор** — [10.0.2.2], **iOS Simulator** — [127.0.0.1].
/// На **физическом устройстве** укажите IPv4 ПК в Wi‑Fi:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080`
class AppConfig {
  AppConfig._();

  static const String _fromEnv = String.fromEnvironment("API_BASE_URL", defaultValue: "");

  /// Переопределение: `--dart-define=API_BASE_URL=...`; иначе — платформенный хост.
  static String get apiBaseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (Platform.isAndroid) return "http://10.0.2.2:8080";
    if (Platform.isIOS) return "http://127.0.0.1:8080";
    return "http://127.0.0.1:8080";
  }

  static Uri get apiBaseUri {
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError("Invalid API_BASE_URL: $apiBaseUrl");
    }
    return uri;
  }
}
