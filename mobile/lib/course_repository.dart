import "package:connectivity_plus/connectivity_plus.dart";
import "package:uuid/uuid.dart";

import "api_client.dart";
import "data/lms_db.dart";
import "models.dart";

class CourseRepository {
  CourseRepository({
    required ApiClient api,
    required Connectivity connectivity,
  })  : _api = api,
        _connectivity = connectivity;

  final ApiClient _api;
  final Connectivity _connectivity;
  bool _autoSyncStarted = false;
  final Uuid _uuid = const Uuid();

  /// Вызывается после успешной синхронизации прогресса и при локальной отметке «выполнено».
  void Function()? onLearnContentStale;

  Future<List<Course>> getCoursesCacheFirst() async {
    final local = await LmsDb.getCourses();
    final online = await _isOnline();
    if (!online) return local;

    try {
      final fresh = await _api.courses();
      await LmsDb.upsertCourses(fresh);
      return fresh;
    } catch (_) {
      return local;
    }
  }

  Future<void> startCourse({
    required String lessonId,
  }) async {
    await _api.sendProgressBatch({
      "items": [
        {
          "lesson_id": lessonId,
          "status": "started",
          "updated_at": DateTime.now().toUtc().toIso8601String(),
          "client_event_id": _uuid.v4(),
        },
      ],
    });
    onLearnContentStale?.call();
  }

  Future<bool> isCourseStarted({
    required String courseId,
  }) async {
    final all = await _api.courses();
    for (final c in all) {
      if (c.id == courseId) return c.isStarted || c.progressPercent > 0;
    }
    return false;
  }

  Future<List<Course>> getMyCoursesCacheFirst() async {
    final all = await _api.courses();
    return all.where((c) => c.isStarted || c.progressPercent > 0).toList();
  }

  Future<CourseDetails?> getCourseDetailsCacheFirst(String courseId) async {
    final online = await _isOnline();
    final cachedLessons = await LmsDb.getLessonsForCourse(courseId);
    if (!online && cachedLessons.isEmpty) return null;

    if (!online) {
      final courses = await LmsDb.getCourses();
      Course? c;
      for (final x in courses) {
        if (x.id == courseId) c = x;
      }
      if (c == null) return null;
      return CourseDetails(
        id: c.id,
        title: c.title,
        description: c.description,
        difficulty: c.difficulty,
        estimatedMinutes: c.estimatedMinutes,
        contentVersion: c.contentVersion,
        progressPercent: c.progressPercent,
        lessons: cachedLessons,
      );
    }

    try {
      final d = await _api.courseDetails(courseId);
      await LmsDb.replaceLessonsForCourse(courseId, d.lessons);
      await LmsDb.upsertCourses([
        Course(
          id: d.id,
          title: d.title,
          description: d.description,
          difficulty: d.difficulty,
          estimatedMinutes: d.estimatedMinutes,
          contentVersion: d.contentVersion,
          progressPercent: d.progressPercent,
        ),
      ]);
      return d;
    } catch (_) {
      if (cachedLessons.isNotEmpty) {
        final courses = await LmsDb.getCourses();
        Course? c;
        for (final x in courses) {
          if (x.id == courseId) c = x;
        }
        if (c != null) {
          return CourseDetails(
            id: c.id,
            title: c.title,
            description: c.description,
            difficulty: c.difficulty,
            estimatedMinutes: c.estimatedMinutes,
            contentVersion: c.contentVersion,
            progressPercent: c.progressPercent,
            lessons: cachedLessons,
          );
        }
      }
      return null;
    }
  }

  /// Статус для UI: не даём «забыть» локально завершённый урок из‑за устаревшего extra с экрана курса.
  static String mergeLessonUiStatus(String? cached, String? fromRoute) {
    if (cached == "done" || fromRoute == "done") return "done";
    return fromRoute ?? cached ?? "available";
  }

  Future<LessonDetail?> getLessonCacheFirst({
    required String lessonId,
    required String courseId,
    LessonSummary? summary,
    String? etag,
  }) async {
    final cached = await LmsDb.getLessonCached(lessonId);
    final online = await _isOnline();

    if (online) {
      try {
        final raw = await _api.lesson(lessonId, ifNoneMatch: etag);
        if (raw == null && cached != null) {
          return _lessonDetailMergedWithRoute(cached, summary?.status, lessonId);
        }
        if (raw != null) {
          final ui = mergeLessonUiStatus(cached?.uiStatus, summary?.status);
          final ord = summary?.orderIndex ?? cached?.orderIndex ?? 0;
          final detail = LessonDetail.fromApi(
            raw,
            courseId: courseId,
            orderIndex: ord,
            uiStatus: ui,
          );
          await LmsDb.upsertLessonDetail(detail);
          return detail;
        }
      } catch (_) {
        if (cached != null) {
          return _lessonDetailMergedWithRoute(cached, summary?.status, lessonId);
        }
      }
    }
    if (cached != null) {
      return _lessonDetailMergedWithRoute(cached, summary?.status, lessonId);
    }
    return null;
  }

  Future<LessonDetail> _lessonDetailMergedWithRoute(
    LessonDetail cached,
    String? summaryStatus,
    String lessonId,
  ) async {
    final merged = mergeLessonUiStatus(cached.uiStatus, summaryStatus);
    if (merged == cached.uiStatus) return cached;
    await LmsDb.updateLessonUiStatus(lessonId, merged);
    return LessonDetail(
      id: cached.id,
      courseId: cached.courseId,
      title: cached.title,
      orderIndex: cached.orderIndex,
      uiStatus: merged,
      contentVersion: cached.contentVersion,
      blocksJson: cached.blocksJson,
    );
  }

  Future<void> queueProgress(Map<String, dynamic> progressPayload) async {
    await _api.sendProgressBatch({"items": [progressPayload]});
  }

  Future<void> queueLessonProgress({
    required String lessonId,
    required String status,
    int? score,
    Map<String, dynamic>? answers,
  }) async {
    if (status == "completed") {
      await LmsDb.updateLessonUiStatus(lessonId, "done");
      onLearnContentStale?.call();
    }
    await queueProgress({
      "lesson_id": lessonId,
      "status": status,
      if (score != null) "score": score,
      if (answers != null) "answers": answers,
      "updated_at": DateTime.now().toUtc().toIso8601String(),
      "client_event_id": _uuid.v4(),
    });
  }

  void startAutoSync() {
    if (_autoSyncStarted) return;
    _autoSyncStarted = true;
    flushProgressQueue();
    _connectivity.onConnectivityChanged.listen((list) async {
      if (!list.contains(ConnectivityResult.none)) {
        await flushProgressQueue();
      }
    });
  }

  Future<bool> online() => _isOnline();

  Future<void> flushProgressQueue() async {
    // Progress is sent immediately in queueProgress; no local progress queue.
  }

  Future<bool> _isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}
