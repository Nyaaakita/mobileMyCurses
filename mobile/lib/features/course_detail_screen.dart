import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_services.dart";
import "../models.dart";
import "../route_args.dart";
import "../widgets/empty_state.dart";

class CourseDetailScreen extends StatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late Future<CourseDetails?> _detailsFuture;
  bool _started = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _detailsFuture =
        appServices.repository.getCourseDetailsCacheFirst(widget.courseId);
    _loadStartedState();
    appServices.learnContentEpoch.addListener(_onLearnContentChanged);
  }

  Future<void> _loadStartedState() async {
    final started = await appServices.repository.isCourseStarted(
      courseId: widget.courseId,
    );
    if (!mounted) return;
    setState(() => _started = started);
  }

  void _onLearnContentChanged() {
    if (!mounted) return;
    setState(() {
      _detailsFuture =
          appServices.repository.getCourseDetailsCacheFirst(widget.courseId);
    });
  }

  @override
  void dispose() {
    appServices.learnContentEpoch.removeListener(_onLearnContentChanged);
    super.dispose();
  }

  String _lessonStatusLabel(String status) {
    switch (status) {
      case "done":
        return "Завершен";
      case "locked":
        return "Закрыт";
      case "available":
        return "Доступен";
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Курс")),
      body: FutureBuilder<CourseDetails?>(
        future: _detailsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data;
          if (d == null) {
            return Column(
              children: [
                const Expanded(
                  child: EmptyState(
                    title: "Курс недоступен",
                    message: "Не удалось загрузить курс: нет сети или курса нет в локальном кэше.",
                    icon: Icons.menu_book_outlined,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text("Назад"),
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(d.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(d.description),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _started || _starting
                      ? null
                      : () async {
                          setState(() => _starting = true);
                          try {
                            final lessons = d.lessons;
                            if (lessons.isEmpty) return;
                            await appServices.repository.startCourse(
                              lessonId: lessons.first.id,
                            );
                            if (!mounted) return;
                            final persisted = await appServices.repository.isCourseStarted(
                              courseId: widget.courseId,
                            );
                            setState(() => _started = persisted);
                            if (!persisted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Не удалось отметить курс как начатый")),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _starting = false);
                          }
                        },
                  child: Text(
                    _started
                        ? "Курс уже начат"
                        : _starting
                            ? "Запуск..."
                            : "Начать курс",
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text("Прогресс: ${d.progressPercent}%"),
              const Divider(height: 32),
              const Text("Уроки", style: TextStyle(fontWeight: FontWeight.bold)),
              ...d.lessons.map(
                (l) => ListTile(
                  title: Text(l.title),
                  subtitle: Text(_lessonStatusLabel(l.status)),
                  enabled: l.status != "locked",
                  trailing: const Icon(Icons.play_circle_outline),
                  onTap: l.status == "locked"
                      ? null
                      : () async {
                          await context.push(
                            "/lesson/${l.id}",
                            extra: LessonRouteExtra(courseId: widget.courseId, summary: l),
                          );
                          if (!mounted) return;
                          _onLearnContentChanged();
                        },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
