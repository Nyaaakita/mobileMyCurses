import "dart:convert";

import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

import "../app_services.dart";
import "../models.dart";
import "../route_args.dart";
import "../widgets/empty_state.dart";

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lessonId, this.extra});

  final String lessonId;
  final LessonRouteExtra? extra;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  LessonDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await appServices.repository.getLessonCacheFirst(
        lessonId: widget.lessonId,
        courseId: widget.extra?.courseId ?? "",
        summary: widget.extra?.summary,
      );
      setState(() {
        _detail = d;
        _error = d == null ? "Нет данных урока" : null;
      });
    } catch (e) {
      setState(() => _error = "$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_detail?.title ?? "Урок")),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EmptyState(
                      title: "Не удалось открыть урок",
                      message: _error,
                      icon: Icons.error_outline,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _detail = null;
                        });
                        _load();
                      },
                      child: const Text("Повторить"),
                    ),
                  ],
                ),
              ),
            )
          : _detail == null
              ? const Center(child: CircularProgressIndicator())
              : _LessonBody(detail: _detail!),
      bottomNavigationBar: _detail == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _detail!.uiStatus == "done"
                  ? FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Урок выполнен"),
                    )
                  : FilledButton.icon(
                      onPressed: () async {
                        await appServices.repository.queueLessonProgress(
                          lessonId: _detail!.id,
                          status: "completed",
                        );
                        await appServices.repository.flushProgressQueue();
                        if (!context.mounted) return;
                        setState(() {
                          _detail = LessonDetail(
                            id: _detail!.id,
                            courseId: _detail!.courseId,
                            title: _detail!.title,
                            orderIndex: _detail!.orderIndex,
                            uiStatus: "done",
                            contentVersion: _detail!.contentVersion,
                            blocksJson: _detail!.blocksJson,
                          );
                        });
                        appServices.notifyLearnContentChanged();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Прогресс сохранён")),
                        );
                      },
                      icon: const Icon(Icons.check),
                      label: const Text("Отметить выполненным"),
                    ),
            ),
    );
  }
}

class _LessonBody extends StatelessWidget {
  const _LessonBody({required this.detail});

  final LessonDetail detail;

  @override
  Widget build(BuildContext context) {
    List<dynamic> blocks;
    try {
      blocks = jsonDecode(detail.blocksJson) as List<dynamic>;
    } catch (_) {
      blocks = [];
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final raw in blocks)
          _BlockTile(raw: raw as Map<String, dynamic>),
      ],
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.raw});

  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final type = raw["type"] as String? ?? "";
    final payload = raw["payload"] as Map<String, dynamic>? ?? {};
    switch (type) {
      case "markdown":
        final text = payload["text"] as String? ?? "";
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(text, style: const TextStyle(height: 1.4)),
        );
      case "video":
        final url = payload["url"] as String? ?? "";
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: url.isEmpty
                ? null
                : () async {
                    final uri = Uri.tryParse(url);
                    if (uri == null) return;
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
            child: Text(
              "Открыть материал",
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        );
      case "quiz":
        final qid = payload["quiz_id"] as String? ?? "";
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FilledButton(
            onPressed: qid.isEmpty
                ? null
                : () => context.push("/quiz/$qid", extra: QuizRouteExtra(title: "Тест")),
            child: const Text("Открыть тест"),
          ),
        );
      case "assignment":
        final aid = payload["assignment_id"] as String? ?? "";
        final assignmentText = payload["text"] as String? ?? "";
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: FilledButton.tonal(
            onPressed: () async {
              if (aid.isNotEmpty) {
                context.push("/assignment/$aid", extra: AssignmentRouteExtra(title: "Задание"));
                return;
              }
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Задание"),
                  content: Text(
                    assignmentText.isEmpty
                        ? "Для этого задания пока нет формы отправки. Обратитесь к преподавателю."
                        : assignmentText,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Понятно"),
                    ),
                  ],
                ),
              );
            },
            child: Text(aid.isNotEmpty ? "Открыть задание" : "Посмотреть задание"),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
