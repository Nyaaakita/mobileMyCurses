import "package:dio/dio.dart";

import "models.dart";

typedef RefreshSessionFn = Future<Session?> Function();
typedef UnauthorizedHandlerFn = Future<void> Function();

class ApiClient {
  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (!_shouldAttemptRefresh(error)) {
            handler.next(error);
            return;
          }
          try {
            final session = await _runRefreshFlow();
            if (session == null) {
              await _onUnauthorized?.call();
              handler.next(error);
              return;
            }
            final response = await _retryWithAccessToken(error.requestOptions, session.accessToken);
            handler.resolve(response);
            return;
          } catch (_) {
            await _onUnauthorized?.call();
            handler.next(error);
            return;
          }
        },
      ),
    );
  }

  final Dio _dio;
  String? _accessToken;
  RefreshSessionFn? _refreshSession;
  UnauthorizedHandlerFn? _onUnauthorized;
  Future<Session?>? _refreshingFuture;

  void configureAuthLifecycle({
    required RefreshSessionFn refreshSession,
    required UnauthorizedHandlerFn onUnauthorized,
  }) {
    _refreshSession = refreshSession;
    _onUnauthorized = onUnauthorized;
  }

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Future<Session> login(String email, String password) async {
    final response = await _dio.post("/api/v1/auth/login", data: {
      "email": email,
      "password": password,
    });
    final token = response.data["access_token"] as String;
    final profile = await fetchMe(tokenOverride: token);
    _accessToken = token;
    return Session(
      accessToken: token,
      refreshToken: response.data["refresh_token"] as String? ?? token,
      role: profile["role"] as String? ?? "student",
      userId: profile["id"] as String?,
      email: profile["email"] as String?,
      name: profile["name"] as String?,
    );
  }

  Future<Session> register(String email, String password, String name) async {
    final response = await _dio.post("/api/v1/auth/register", data: {
      "email": email,
      "password": password,
      "name": name,
    });
    final token = response.data["access_token"] as String;
    final profile = await fetchMe(tokenOverride: token);
    _accessToken = token;
    return Session(
      accessToken: token,
      refreshToken: response.data["refresh_token"] as String? ?? token,
      role: profile["role"] as String? ?? "student",
      userId: profile["id"] as String?,
      email: profile["email"] as String?,
      name: profile["name"] as String?,
    );
  }

  Future<List<Course>> courses() async {
    final response = await _dio.get(
      "/api/v1/courses",
      options: Options(headers: _headers()),
    );
    final data = (response.data as List).cast<Map<String, dynamic>>();
    return data.map(Course.fromJson).toList();
  }

  Future<CourseDetails> courseDetails(String courseId) async {
    final response = await _dio.get(
      "/api/v1/courses/$courseId",
      options: Options(headers: _headers()),
    );
    return CourseDetails.fromJson((response.data as Map).cast<String, dynamic>());
  }

  /// Возвращает тело урока или null при 304 Not Modified.
  Future<Map<String, dynamic>?> lesson(
    String lessonId, {
    String? ifNoneMatch,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      "/api/v1/lessons/$lessonId",
      options: Options(
        headers: {
          ..._headers(),
          if (ifNoneMatch != null) "If-None-Match": ifNoneMatch,
        },
        validateStatus: (s) => s != null && (s == 200 || s == 304),
      ),
    );
    if (response.statusCode == 304) return null;
    return response.data;
  }

  Future<Map<String, dynamic>> quizForAttempt(String quizId) async {
    final response = await _dio.get(
      "/api/v1/quizzes/$quizId",
      options: Options(headers: _headers()),
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> quizSubmit(String quizId, Map<String, dynamic> body) async {
    final response = await _dio.post(
      "/api/v1/quizzes/$quizId/submit",
      data: body,
      options: Options(headers: _headers()),
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> assignmentSubmit(String assignmentId, Map<String, dynamic> body) async {
    final response = await _dio.post(
      "/api/v1/assignments/$assignmentId/submit",
      data: body,
      options: Options(headers: _headers()),
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> fetchMe({String? tokenOverride}) async {
    final response = await _dio.get(
      "/api/v1/auth/me",
      options: Options(headers: _headers(tokenOverride: tokenOverride)),
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Session> refresh(String refreshToken) async {
    final response = await _dio.post("/api/v1/auth/refresh", data: {
      "refresh_token": refreshToken,
    });
    final token = response.data["access_token"] as String;
    final profile = await fetchMe(tokenOverride: token);
    _accessToken = token;
    return Session(
      accessToken: token,
      refreshToken: response.data["refresh_token"] as String? ?? token,
      role: profile["role"] as String? ?? "student",
      userId: profile["id"] as String?,
      email: profile["email"] as String?,
      name: profile["name"] as String?,
    );
  }

  Future<void> sendProgressBatch(Map<String, dynamic> batch) async {
    await _dio.put(
      "/api/v1/progress/batch",
      data: batch,
      options: Options(headers: _headers()),
    );
  }

  Future<Map<String, dynamic>> adminCreateCourse(Map<String, dynamic> body) async {
    final r = await _dio.post(
      "/api/v1/admin/courses",
      data: body,
      options: Options(headers: _headers()),
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> adminCourses() async {
    final r = await _dio.get(
      "/api/v1/admin/courses",
      options: Options(headers: _headers()),
    );
    return (r.data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> adminUpdateCourse(String courseId, Map<String, dynamic> body) async {
    final r = await _dio.patch(
      "/api/v1/admin/courses/$courseId",
      data: body,
      options: Options(headers: _headers()),
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<void> adminDeleteCourse(String courseId) async {
    await _dio.delete(
      "/api/v1/admin/courses/$courseId",
      options: Options(headers: _headers()),
    );
  }

  Future<Map<String, dynamic>> adminCourseLearnersStats(String courseId) async {
    final r = await _dio.get(
      "/api/v1/admin/courses/$courseId/learners-stats",
      options: Options(headers: _headers()),
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> adminLessons(String courseId) async {
    final r = await _dio.get(
      "/api/v1/admin/courses/$courseId/lessons",
      options: Options(headers: _headers()),
    );
    return (r.data as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> adminCreateLesson(String courseId, Map<String, dynamic> body) async {
    final r = await _dio.post(
      "/api/v1/admin/courses/$courseId/lessons",
      data: body,
      options: Options(headers: _headers()),
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> adminUpdateLesson(String lessonId, Map<String, dynamic> body) async {
    final r = await _dio.patch(
      "/api/v1/admin/lessons/$lessonId",
      data: body,
      options: Options(headers: _headers()),
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<void> adminDeleteLesson(String lessonId) async {
    await _dio.delete(
      "/api/v1/admin/lessons/$lessonId",
      options: Options(headers: _headers()),
    );
  }

  Future<void> adminReorderLessons(String courseId, List<Map<String, dynamic>> lessonOrders) async {
    await _dio.patch(
      "/api/v1/admin/courses/$courseId/lessons/reorder",
      data: {"lesson_orders": lessonOrders},
      options: Options(headers: _headers()),
    );
  }

  Future<Map<String, dynamic>> adminQuizByLesson(String lessonId) async {
    final r = await _dio.get(
      "/api/v1/admin/lessons/$lessonId/quiz",
      options: Options(headers: _headers()),
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> adminCreateQuiz(String lessonId, Map<String, dynamic> body) async {
    final r = await _dio.post(
      "/api/v1/admin/lessons/$lessonId/quiz",
      data: body,
      options: Options(headers: _headers()),
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> adminUpdateQuiz(String quizId, Map<String, dynamic> body) async {
    final r = await _dio.patch(
      "/api/v1/admin/quizzes/$quizId",
      data: body,
      options: Options(headers: _headers()),
    );
    return (r.data as Map).cast<String, dynamic>();
  }

  Future<void> adminDeleteQuiz(String quizId) async {
    await _dio.delete(
      "/api/v1/admin/quizzes/$quizId",
      options: Options(headers: _headers()),
    );
  }

  Map<String, String> _headers({String? tokenOverride}) {
    final token = tokenOverride ?? _accessToken;
    if (token == null) return {};
    return {"Authorization": "Bearer $token"};
  }

  bool _shouldAttemptRefresh(DioException error) {
    final status = error.response?.statusCode ?? 0;
    if (status != 401) return false;
    final opts = error.requestOptions;
    final alreadyRetried = opts.extra["retried_with_refresh"] == true;
    if (alreadyRetried) return false;
    final path = opts.path;
    if (path.contains("/api/v1/auth/login") || path.contains("/api/v1/auth/register") || path.contains("/api/v1/auth/refresh")) {
      return false;
    }
    return _refreshSession != null;
  }

  Future<Session?> _runRefreshFlow() async {
    if (_refreshingFuture != null) {
      return _refreshingFuture;
    }
    final fn = _refreshSession;
    if (fn == null) return null;
    _refreshingFuture = fn();
    try {
      return await _refreshingFuture;
    } finally {
      _refreshingFuture = null;
    }
  }

  Future<Response<dynamic>> _retryWithAccessToken(RequestOptions source, String accessToken) {
    final headers = Map<String, dynamic>.from(source.headers);
    headers["Authorization"] = "Bearer $accessToken";
    final options = Options(
      method: source.method,
      headers: headers,
      responseType: source.responseType,
      contentType: source.contentType,
      extra: {
        ...source.extra,
        "retried_with_refresh": true,
      },
      followRedirects: source.followRedirects,
      listFormat: source.listFormat,
      maxRedirects: source.maxRedirects,
      receiveDataWhenStatusError: source.receiveDataWhenStatusError,
      receiveTimeout: source.receiveTimeout,
      requestEncoder: source.requestEncoder,
      responseDecoder: source.responseDecoder,
      sendTimeout: source.sendTimeout,
      validateStatus: source.validateStatus,
    );
    return _dio.request<dynamic>(
      source.path,
      data: source.data,
      queryParameters: source.queryParameters,
      options: options,
      cancelToken: source.cancelToken,
      onReceiveProgress: source.onReceiveProgress,
      onSendProgress: source.onSendProgress,
    );
  }
}
