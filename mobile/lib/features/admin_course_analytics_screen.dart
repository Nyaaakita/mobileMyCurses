import "package:flutter/material.dart";

import "../api_error_message.dart";
import "../app_services.dart";
import "../widgets/empty_state.dart";

enum _AnalyticsView { progress, tests }

class AdminCourseAnalyticsScreen extends StatefulWidget {
  const AdminCourseAnalyticsScreen({
    super.key,
    required this.courseId,
    this.courseTitle,
  });

  final String courseId;
  final String? courseTitle;

  @override
  State<AdminCourseAnalyticsScreen> createState() => _AdminCourseAnalyticsScreenState();
}

class _AdminCourseAnalyticsScreenState extends State<AdminCourseAnalyticsScreen> {
  late Future<Map<String, dynamic>> _future;
  _AnalyticsView _view = _AnalyticsView.progress;

  @override
  void initState() {
    super.initState();
    _future = appServices.api.adminCourseLearnersStats(widget.courseId);
    appServices.learnContentEpoch.addListener(_reload);
  }

  @override
  void dispose() {
    appServices.learnContentEpoch.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _future = appServices.api.adminCourseLearnersStats(widget.courseId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseTitle?.trim().isNotEmpty == true ? widget.courseTitle! : "Аналитика курса"),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              title: "Не удалось загрузить статистику",
              message: readableApiError(
                snap.error!,
                authFailure: "Проверьте подключение и попробуйте снова",
              ),
              icon: Icons.analytics_outlined,
            );
          }
          final data = snap.data ?? const <String, dynamic>{};
          final learners = (data["learners"] as List<dynamic>? ?? const [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
          if (learners.isEmpty) {
            return const EmptyState(
              title: "Пока нет активных учеников",
              message: "Никто еще не начал этот курс.",
              icon: Icons.groups_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
              Text("Учеников: ${learners.length}", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<_AnalyticsView>(
                segments: const [
                  ButtonSegment<_AnalyticsView>(
                    value: _AnalyticsView.progress,
                    label: Text("Прогресс"),
                  ),
                  ButtonSegment<_AnalyticsView>(
                    value: _AnalyticsView.tests,
                    label: Text("Тесты"),
                  ),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
              const SizedBox(height: 12),
              if (_view == _AnalyticsView.progress)
                ...learners.map(
                  (u) => Card(
                    child: ListTile(
                      title: Text(
                        u["name"]?.toString().trim().isNotEmpty == true ? u["name"].toString() : "Без имени",
                      ),
                      subtitle: Text(
                        "${u["email"] ?? "—"}\n"
                        "Прогресс: ${u["progress_percent"] ?? 0}% "
                        "(${u["completed_lessons"] ?? 0}/${u["total_lessons"] ?? 0})",
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.trending_up_outlined),
                    ),
                  ),
                )
              else ...[
                for (final u in learners)
                  Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.quiz_outlined),
                      title: Text(
                        u["name"]?.toString().trim().isNotEmpty == true ? u["name"].toString() : "Без имени",
                      ),
                      subtitle: Text("${u["email"] ?? "—"}"),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        if ((u["quiz_stats_by_test"] as List<dynamic>? ?? const []).isEmpty)
                          const ListTile(
                            dense: true,
                            title: Text("Нет прохождений тестов"),
                          )
                        else
                          ...(u["quiz_stats_by_test"] as List<dynamic>).map((e) {
                            final t = (e as Map).cast<String, dynamic>();
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text("${t["lesson_title"] ?? "Урок"} - ${t["quiz_title"] ?? "Тест"}"),
                              subtitle: Text(
                                "Попытки: ${t["attempts_count"] ?? 0}\n"
                                "1-я: ${t["first_score"] ?? 0}, "
                                "последняя: ${t["last_score"] ?? 0}, "
                                "средний: ${((t["average_score"] as num?) ?? 0).toStringAsFixed(1)}",
                              ),
                              isThreeLine: true,
                            );
                          }),
                      ],
                    ),
                  ),
              ],
              ],
            ),
          );
        },
      ),
    );
  }
}

