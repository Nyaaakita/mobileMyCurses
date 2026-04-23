import "models.dart";

class LessonRouteExtra {
  LessonRouteExtra({required this.courseId, this.summary});

  final String courseId;
  final LessonSummary? summary;
}

class QuizRouteExtra {
  QuizRouteExtra({this.title});
  final String? title;
}

class AssignmentRouteExtra {
  AssignmentRouteExtra({this.title});
  final String? title;
}
