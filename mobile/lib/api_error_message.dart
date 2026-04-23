import "package:dio/dio.dart";

/// Сообщение для пользователя по исключению Dio (сеть, 401, 5xx).
String readableApiError(Object error, {required String authFailure}) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Сервер не отвечает. Запустите API на ПК и проверьте адрес (см. комментарий в lib/config.dart).";
      case DioExceptionType.connectionError:
        return "Нет связи с API. На физическом телефоне укажите IP вашего компьютера в Wi‑Fi, например:\n"
            "flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8080\n"
            "(10.0.2.2 работает только в эмуляторе.) Убедитесь, что бэкенд слушает 0.0.0.0:8080 или доступен в LAN.";
      case DioExceptionType.badResponse:
        final c = error.response?.statusCode ?? 0;
        final payload = error.response?.data;
        if (payload is Map) {
          final code = payload["error_code"]?.toString();
          final msg = payload["message"]?.toString();
          if (code == "VALIDATION_ERROR" && msg != null && msg.isNotEmpty) {
            return "Проверьте поля: $msg";
          }
          if (code == "RATE_LIMITED") {
            return "Слишком много запросов. Подождите и попробуйте снова.";
          }
          if (msg != null && msg.isNotEmpty) {
            return msg;
          }
        }
        if (c == 401 || c == 403) return authFailure;
        if (c == 404) return "Нужные данные не найдены.";
        if (c == 409) return "Конфликт данных. Обновите экран и попробуйте снова.";
        if (c == 429) return "Слишком много запросов. Повторите позже.";
        if (c >= 500) {
          return "Ошибка на сервере ($c). Проверьте, что PostgreSQL запущен и миграции прошли.";
        }
        return "Запрос отклонён ($c).";
      case DioExceptionType.cancel:
        return "Запрос отменён.";
      default:
        break;
    }
  }
  return authFailure;
}
