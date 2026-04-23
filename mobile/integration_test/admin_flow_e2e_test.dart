import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:lms_mobile/api_client.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const runE2E = bool.fromEnvironment("RUN_ADMIN_E2E", defaultValue: false);
  const apiBaseUrl = String.fromEnvironment("API_BASE_URL", defaultValue: "http://10.0.2.2:8080");
  const adminEmail = String.fromEnvironment("ADMIN_EMAIL", defaultValue: "admin@example.com");
  const adminPassword = String.fromEnvironment("ADMIN_PASSWORD", defaultValue: "password123");

  testWidgets("admin can create course lesson and quiz through API", (tester) async {
    if (!runE2E) {
      return;
    }
    final api = ApiClient(baseUrl: apiBaseUrl);
    final session = await api.login(adminEmail, adminPassword);
    api.setAccessToken(session.accessToken);

    final created = await api.adminCreateCourse({
      "title": "E2E Course ${DateTime.now().millisecondsSinceEpoch}",
      "description": "Course created from integration test flow",
      "difficulty": "beginner",
      "is_published": true,
    });
    final courseId = created["id"] as String;

    final lesson = await api.adminCreateLesson(courseId, {
      "title": "E2E Lesson",
      "blocks": [],
    });
    final lessonId = lesson["id"] as String;

    final quiz = await api.adminCreateQuiz(lessonId, {
      "title": "E2E Quiz",
      "questions": jsonDecode(
        """
[
  {
    "id": "q1",
    "text": "2+2?",
    "options": [
      {"id": "a", "text": "4", "is_correct": true},
      {"id": "b", "text": "5", "is_correct": false}
    ]
  }
]
""",
      ),
    });
    expect(quiz["id"], isNotNull);
  });
}
