import "dart:convert";

class Session {
  const Session({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    this.userId,
    this.email,
    this.name,
  });

  final String accessToken;
  final String refreshToken;
  final String role;
  final String? userId;
  final String? email;
  final String? name;
}

class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.contentVersion,
    this.progressPercent = 0,
    this.isStarted = false,
  });

  final String id;
  final String title;
  final String description;
  final String difficulty;
  final int estimatedMinutes;
  final int contentVersion;
  final int progressPercent;
  final bool isStarted;

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json["id"] as String,
      title: json["title"] as String? ?? "",
      description: json["description"] as String? ?? "",
      difficulty: json["difficulty"] as String? ?? "beginner",
      estimatedMinutes: json["estimated_minutes"] as int? ?? 0,
      contentVersion: json["content_version"] as int? ?? 1,
      progressPercent: json["progress_percent"] as int? ?? 0,
      isStarted: json["is_started"] as bool? ?? false,
    );
  }
}

class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.title,
    required this.orderIndex,
    required this.status,
    this.contentVersion = 1,
  });

  final String id;
  final String title;
  final int orderIndex;
  /// locked | available | done
  final String status;
  final int contentVersion;

  factory LessonSummary.fromJson(Map<String, dynamic> json) {
    return LessonSummary(
      id: json["id"] as String,
      title: json["title"] as String? ?? "",
      orderIndex: json["order_index"] as int? ?? 0,
      status: json["status"] as String? ?? "locked",
      contentVersion: json["content_version"] as int? ?? 1,
    );
  }
}

class CourseDetails {
  const CourseDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.contentVersion,
    required this.progressPercent,
    required this.lessons,
  });

  final String id;
  final String title;
  final String description;
  final String difficulty;
  final int estimatedMinutes;
  final int contentVersion;
  final int progressPercent;
  final List<LessonSummary> lessons;

  factory CourseDetails.fromJson(Map<String, dynamic> json) {
    final raw = (json["lessons"] as List<dynamic>? ?? [])
        .map((e) => LessonSummary.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return CourseDetails(
      id: json["id"] as String,
      title: json["title"] as String? ?? "",
      description: json["description"] as String? ?? "",
      difficulty: json["difficulty"] as String? ?? "",
      estimatedMinutes: json["estimated_minutes"] as int? ?? 0,
      contentVersion: json["content_version"] as int? ?? 1,
      progressPercent: json["progress_percent"] as int? ?? 0,
      lessons: raw,
    );
  }
}

class LessonDetail {
  const LessonDetail({
    required this.id,
    required this.courseId,
    required this.title,
    required this.orderIndex,
    required this.uiStatus,
    required this.contentVersion,
    required this.blocksJson,
  });

  final String id;
  final String courseId;
  final String title;
  final int orderIndex;
  final String uiStatus;
  final int contentVersion;
  final String blocksJson;

  factory LessonDetail.fromApi(
    Map<String, dynamic> json, {
    required String courseId,
    int orderIndex = 0,
    String uiStatus = "available",
  }) {
    final raw = json["blocks"];
    final blocksJson = raw == null
        ? "[]"
        : raw is String
            ? raw
            : jsonEncode(raw);
    return LessonDetail(
      id: json["id"] as String,
      courseId: (json["course_id"] as String?)?.trim().isNotEmpty == true
          ? json["course_id"] as String
          : courseId,
      title: json["title"] as String? ?? "",
      orderIndex: orderIndex,
      uiStatus: uiStatus,
      contentVersion: json["content_version"] as int? ?? 1,
      blocksJson: blocksJson,
    );
  }
}
