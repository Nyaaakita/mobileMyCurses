import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_services.dart";
import "../models.dart";
import "../widgets/empty_state.dart";

enum _MyCoursesFilter { active, completed }

class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  late Future<List<Course>> _coursesFuture;
  _MyCoursesFilter _filter = _MyCoursesFilter.active;

  @override
  void initState() {
    super.initState();
    _coursesFuture = appServices.repository.getMyCoursesCacheFirst();
    appServices.learnContentEpoch.addListener(_reload);
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _coursesFuture = appServices.repository.getMyCoursesCacheFirst();
    });
  }

  @override
  void dispose() {
    appServices.learnContentEpoch.removeListener(_reload);
    super.dispose();
  }

  String _difficultyLabel(String value) {
    switch (value) {
      case "beginner":
        return "Начальный";
      case "intermediate":
        return "Средний";
      case "advanced":
        return "Продвинутый";
      default:
        return value;
    }
  }

  List<Course> _filtered(List<Course> all) {
    if (_filter == _MyCoursesFilter.active) {
      return all.where((c) => c.progressPercent < 100).toList();
    }
    return all.where((c) => c.progressPercent >= 100).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Мои курсы")),
      body: FutureBuilder<List<Course>>(
        future: _coursesFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          if (all.isEmpty) {
            return const EmptyState(
              title: "Вы еще не начали курсы",
              message: "Откройте курс в каталоге и нажмите \"Начать курс\".",
              icon: Icons.school_outlined,
            );
          }
          final list = _filtered(all);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<_MyCoursesFilter>(
                segments: const [
                  ButtonSegment<_MyCoursesFilter>(
                    value: _MyCoursesFilter.active,
                    label: Text("Активные"),
                  ),
                  ButtonSegment<_MyCoursesFilter>(
                    value: _MyCoursesFilter.completed,
                    label: Text("Завершенные"),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (values) {
                  setState(() => _filter = values.first);
                },
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                EmptyState(
                  title: _filter == _MyCoursesFilter.active
                      ? "Нет активных курсов"
                      : "Нет завершенных курсов",
                  message: _filter == _MyCoursesFilter.active
                      ? "Начните новый курс в каталоге."
                      : "Завершите хотя бы один курс, чтобы увидеть его здесь.",
                  icon: _filter == _MyCoursesFilter.active
                      ? Icons.play_circle_outline
                      : Icons.check_circle_outline,
                )
              else
                ...list.map(
                  (c) => Card(
                    child: ListTile(
                      title: Text(c.title),
                      subtitle: Text(
                        "${_difficultyLabel(c.difficulty)} · ${c.progressPercent}%",
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push("/course/${c.id}"),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
