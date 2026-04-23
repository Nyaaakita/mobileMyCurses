import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/foundation.dart";

import "api_client.dart";
import "course_repository.dart";
import "models.dart";
import "services/auth_storage.dart";

/// Глобальные зависимости для go_router и экранов (без DI-фреймворка).
late AppServices appServices;

class AppServices {
  AppServices({
    required this.api,
    required this.repository,
    required this.authStorage,
    required this.connectivity,
  });

  final ApiClient api;
  final CourseRepository repository;
  final AuthStorage authStorage;
  final Connectivity connectivity;

  final ValueNotifier<Session?> currentSession = ValueNotifier<Session?>(null);

  /// Увеличить при изменении курсов/уроков/прогресса на сервере или локально —
  /// экраны каталога и курса подписываются и перезагружают данные.
  final ValueNotifier<int> learnContentEpoch = ValueNotifier<int>(0);

  void notifyLearnContentChanged() {
    learnContentEpoch.value++;
  }
}
