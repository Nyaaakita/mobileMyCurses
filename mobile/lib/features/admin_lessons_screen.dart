import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../api_error_message.dart";
import "../app_services.dart";
import "../design_tokens.dart";
import "../widgets/app_card.dart";
import "../widgets/app_primary_button.dart";
import "../widgets/app_text_field.dart";
import "../widgets/empty_state.dart";

class AdminLessonsScreen extends StatefulWidget {
  const AdminLessonsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  State<AdminLessonsScreen> createState() => _AdminLessonsScreenState();
}

class _AdminLessonsScreenState extends State<AdminLessonsScreen> {
  final _title = TextEditingController();
  bool _loading = false;
  bool _reordering = false;
  String? _message;
  Future<List<Map<String, dynamic>>>? _future;
  /// Загружается вместе со списком уроков — без вложенного FutureBuilder на каждой карточке
  /// (иначе после reorder кнопки «мигают» и высота карточек прыгает).
  Map<String, bool> _lessonHasQuiz = {};

  int _orderIndex(Map<String, dynamic> lesson) {
    final v = lesson["order_index"];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _loadLessonsAndQuizFlags();
    });
  }

  Future<List<Map<String, dynamic>>> _loadLessonsAndQuizFlags() async {
    final lessons = await appServices.api.adminLessons(widget.courseId);
    if (lessons.isEmpty) {
      _lessonHasQuiz = {};
      return lessons;
    }
    final entries = await Future.wait(
      lessons.map((l) async {
        final id = l["id"] as String;
        try {
          await appServices.api.adminQuizByLesson(id);
          return MapEntry(id, true);
        } catch (_) {
          return MapEntry(id, false);
        }
      }),
    );
    _lessonHasQuiz = Map.fromEntries(entries);
    return lessons;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<bool> _confirmDeleteLesson(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить урок"),
        content: Text("Удалить урок \"$title\"?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Уроки курса")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(controller: _title, label: "Название урока"),
                const SizedBox(height: AppSpace.sm),
                AppPrimaryButton(
                  label: "Добавить урок",
                  loading: _loading,
                  onPressed: () async {
                    setState(() {
                      _loading = true;
                      _message = null;
                    });
                    try {
                      await appServices.api.adminCreateLesson(widget.courseId, {
                        "title": _title.text.trim(),
                        "blocks": [],
                      });
                      _title.clear();
                      appServices.notifyLearnContentChanged();
                      _reload();
                    } catch (e) {
                      setState(
                        () => _message = readableApiError(
                          e,
                          authFailure: "Не удалось создать урок",
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                ),
              ],
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpace.md),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return EmptyState(
                  title: "Не удалось загрузить уроки",
                  message: readableApiError(snap.error!, authFailure: "Попробуйте позже"),
                );
              }
              final lessons = [...(snap.data ?? const [])];
              if (lessons.isEmpty) return const EmptyState(title: "Пока нет уроков");
              lessons.sort((a, b) => _orderIndex(a).compareTo(_orderIndex(b)));
              return Column(
                children: [
                  for (var i = 0; i < lessons.length; i++)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: AppSpace.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            lessons[i]["title"]?.toString() ?? "Урок",
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            "Порядок: ${_orderIndex(lessons[i])}",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: AppSpace.md),
                          FilledButton(
                            onPressed: () async {
                              final saved = await context.push<bool>(
                                "/admin/lesson/${lessons[i]["id"]}/content",
                                extra: lessons[i],
                              );
                              if (saved == true && mounted) {
                                appServices.notifyLearnContentChanged();
                                _reload();
                              }
                            },
                            child: const Text("Посмотреть урок"),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          FilledButton.tonal(
                            onPressed: () async {
                              await context.push(
                                "/admin/lesson/${lessons[i]["id"]}/quiz",
                                extra: lessons[i],
                              );
                              if (mounted) {
                                appServices.notifyLearnContentChanged();
                                _reload();
                              }
                            },
                            child: Text(
                              _lessonHasQuiz[lessons[i]["id"]] == true
                                  ? "Редактировать квиз"
                                  : "Создать квиз",
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: AppSpace.lg),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: i == 0 || _reordering
                                      ? null
                                      : () async {
                                          final prev = lessons[i - 1];
                                          final cur = lessons[i];
                                          setState(() => _reordering = true);
                                          try {
                                            await appServices.api.adminReorderLessons(widget.courseId, [
                                              {
                                                "lesson_id": cur["id"],
                                                "order_index": _orderIndex(prev),
                                              },
                                              {
                                                "lesson_id": prev["id"],
                                                "order_index": _orderIndex(cur),
                                              },
                                            ]);
                                            if (mounted) {
                                              appServices.notifyLearnContentChanged();
                                              _reload();
                                            }
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  readableApiError(e, authFailure: "Не удалось изменить порядок"),
                                                ),
                                              ),
                                            );
                                          } finally {
                                            if (mounted) setState(() => _reordering = false);
                                          }
                                        },
                                  child: const Text("Поднять"),
                                ),
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: i == lessons.length - 1 || _reordering
                                      ? null
                                      : () async {
                                          final nxt = lessons[i + 1];
                                          final cur = lessons[i];
                                          setState(() => _reordering = true);
                                          try {
                                            await appServices.api.adminReorderLessons(widget.courseId, [
                                              {
                                                "lesson_id": cur["id"],
                                                "order_index": _orderIndex(nxt),
                                              },
                                              {
                                                "lesson_id": nxt["id"],
                                                "order_index": _orderIndex(cur),
                                              },
                                            ]);
                                            if (mounted) {
                                              appServices.notifyLearnContentChanged();
                                              _reload();
                                            }
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  readableApiError(e, authFailure: "Не удалось изменить порядок"),
                                                ),
                                              ),
                                            );
                                          } finally {
                                            if (mounted) setState(() => _reordering = false);
                                          }
                                        },
                                  child: const Text("Опустить"),
                                ),
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final title = lessons[i]["title"]?.toString() ?? "урок";
                                    final ok = await _confirmDeleteLesson(title);
                                    if (!ok || !mounted) return;
                                    await appServices.api.adminDeleteLesson(lessons[i]["id"] as String);
                                    appServices.notifyLearnContentChanged();
                                    _reload();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.error,
                                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                                  ),
                                  child: const Text("Удалить"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
