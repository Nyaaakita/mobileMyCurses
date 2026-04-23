import "package:go_router/go_router.dart";

import "../app_services.dart";
import "../features/admin_course_edit_screen.dart";
import "../features/admin_course_analytics_screen.dart";
import "../features/admin_course_create_screen.dart";
import "../features/admin_home_screen.dart";
import "../features/admin_lesson_content_screen.dart";
import "../features/admin_lessons_screen.dart";
import "../features/admin_quiz_editor_screen.dart";
import "../features/auth/login_screen.dart";
import "../features/auth/register_screen.dart";
import "../features/assignment_screen.dart";
import "../features/catalog_screen.dart";
import "../features/calendar_screen.dart";
import "../features/course_detail_screen.dart";
import "../features/lesson_screen.dart";
import "../features/my_courses_screen.dart";
import "../features/profile_screen.dart";
import "../features/quiz_screen.dart";
import "../features/splash_screen.dart";
import "../route_args.dart";
import "../widgets/app_shell.dart";

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: "/splash",
    refreshListenable: appServices.currentSession,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggedIn = appServices.currentSession.value != null;
      final public = loc == "/splash" || loc == "/login" || loc == "/register";
      if (!loggedIn && !public) return "/login";
      if (loggedIn && (loc == "/login" || loc == "/register")) return "/catalog";
      if (loc.startsWith("/admin") && appServices.currentSession.value?.role != "admin") return "/catalog";
      if (loc == "/progress") return "/catalog";
      return null;
    },
    routes: [
      GoRoute(path: "/splash", builder: (ctx, st) => const SplashScreen()),
      GoRoute(path: "/login", builder: (ctx, st) => const LoginScreen()),
      GoRoute(path: "/register", builder: (ctx, st) => const RegisterScreen()),
      ShellRoute(
        builder: (ctx, st, child) => AppShell(child: child),
        routes: [
          GoRoute(path: "/catalog", builder: (ctx, st) => const CatalogScreen()),
          GoRoute(path: "/my-courses", builder: (ctx, st) => const MyCoursesScreen()),
          GoRoute(path: "/calendar", builder: (ctx, st) => const CalendarScreen()),
          GoRoute(path: "/profile", builder: (ctx, st) => const ProfileScreen()),
          GoRoute(path: "/admin", builder: (ctx, st) => const AdminHomeScreen()),
          GoRoute(path: "/admin/course/create", builder: (ctx, st) => const AdminCourseCreateScreen()),
          GoRoute(
            path: "/admin/course/:courseId/edit",
            builder: (ctx, st) => AdminCourseEditScreen(
              courseId: st.pathParameters["courseId"]!,
              initial: st.extra is Map<String, dynamic> ? st.extra as Map<String, dynamic> : null,
            ),
          ),
          GoRoute(
            path: "/admin/course/:courseId/lessons",
            builder: (ctx, st) => AdminLessonsScreen(courseId: st.pathParameters["courseId"]!),
          ),
          GoRoute(
            path: "/admin/course/:courseId/analytics",
            builder: (ctx, st) => AdminCourseAnalyticsScreen(
              courseId: st.pathParameters["courseId"]!,
              courseTitle: st.extra is String ? st.extra as String : null,
            ),
          ),
          GoRoute(
            path: "/admin/lesson/:lessonId/quiz",
            builder: (ctx, st) => AdminQuizEditorScreen(
              lessonId: st.pathParameters["lessonId"]!,
              initialLesson: st.extra is Map<String, dynamic> ? st.extra as Map<String, dynamic> : null,
            ),
          ),
          GoRoute(
            path: "/admin/lesson/:lessonId/content",
            builder: (ctx, st) => AdminLessonContentScreen(
              lessonId: st.pathParameters["lessonId"]!,
              initial: st.extra is Map<String, dynamic> ? st.extra as Map<String, dynamic> : null,
            ),
          ),
        ],
      ),
      GoRoute(
        path: "/course/:courseId",
        builder: (ctx, st) => CourseDetailScreen(courseId: st.pathParameters["courseId"]!),
      ),
      GoRoute(
        path: "/lesson/:lessonId",
        builder: (ctx, st) => LessonScreen(
          lessonId: st.pathParameters["lessonId"]!,
          extra: st.extra is LessonRouteExtra ? st.extra as LessonRouteExtra : null,
        ),
      ),
      GoRoute(
        path: "/quiz/:quizId",
        builder: (ctx, st) => QuizScreen(
          quizId: st.pathParameters["quizId"]!,
          extra: st.extra is QuizRouteExtra ? st.extra as QuizRouteExtra : null,
        ),
      ),
      GoRoute(
        path: "/assignment/:assignmentId",
        builder: (ctx, st) => AssignmentScreen(
          assignmentId: st.pathParameters["assignmentId"]!,
          extra: st.extra is AssignmentRouteExtra ? st.extra as AssignmentRouteExtra : null,
        ),
      ),
    ],
  );
}
