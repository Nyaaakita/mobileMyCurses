import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../api_error_message.dart";
import "../app_services.dart";
import "../design_tokens.dart";
import "../widgets/app_card.dart";
import "../widgets/empty_state.dart";
import "../widgets/app_primary_button.dart";
import "../widgets/app_text_field.dart";

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  Future<List<Map<String, dynamic>>>? _coursesFuture;
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

  Future<bool> _confirmDelete(String title) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Подтвердите удаление"),
        content: Text("Удалить \"$title\"? Это действие нельзя отменить."),
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
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _coursesFuture = appServices.api.adminCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (appServices.currentSession.value?.role != "admin") {
      return Scaffold(
        appBar: AppBar(title: const Text("Админ")),
        body: const EmptyState(
          title: "Нужна роль администратора",
          message: "Войдите под учётной записью с правами администратора.",
          icon: Icons.lock_outline,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Курсы администратора")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppPrimaryButton(
            label: "Создать курс",
            onPressed: () async {
              final created = await context.push<bool>("/admin/course/create");
              if (created == true && mounted) {
                appServices.notifyLearnContentChanged();
                _reload();
              }
            },
          ),
          const SizedBox(height: AppSpace.lg),
          Text("Ваши курсы", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpace.sm),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _coursesFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return EmptyState(
                  title: "Не удалось загрузить курсы",
                  message: readableApiError(
                    snap.error!,
                    authFailure: "Проверьте подключение и попробуйте снова",
                  ),
                );
              }
              final items = snap.data ?? const [];
              if (items.isEmpty) {
                return const EmptyState(title: "Пока нет курсов");
              }
              return Column(
                children: [
                  for (final c in items)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: AppSpace.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c["title"]?.toString() ?? "Без названия"),
                          const SizedBox(height: AppSpace.xs),
                          Text(c["description"]?.toString() ?? "", maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: AppSpace.xs),
                          Wrap(
                            spacing: 6,
                            children: [
                              Chip(label: Text(_difficultyLabel(c["difficulty"]?.toString() ?? ""))),
                              Chip(
                                label: Text(c["is_published"] == true ? "Опубликован" : "Черновик"),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.tonal(
                                  onPressed: () => context.push("/admin/course/${c["id"]}/lessons"),
                                  child: const Text("Уроки"),
                                ),
                              ),
                              const SizedBox(width: AppSpace.xs),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final ok = await _confirmDelete(c["title"]?.toString() ?? "курс");
                                    if (!ok || !mounted) return;
                                    try {
                                      await appServices.api.adminDeleteCourse(c["id"] as String);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Курс удален")),
                                      );
                                      appServices.notifyLearnContentChanged();
                                      _reload();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            readableApiError(e, authFailure: "Не удалось удалить курс"),
                                          ),
                                        ),
                                      );
                                    }
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
                          const SizedBox(height: AppSpace.xs),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed: () async {
                                final saved = await context.push<bool>(
                                  "/admin/course/${c["id"]}/edit",
                                  extra: c,
                                );
                                if (saved == true && mounted) {
                                  appServices.notifyLearnContentChanged();
                                  _reload();
                                }
                              },
                              child: const Text("Редактировать"),
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonal(
                              onPressed: () => context.push(
                                "/admin/course/${c["id"]}/analytics",
                                extra: c["title"]?.toString() ?? "",
                              ),
                              child: const Text("Статистика"),
                            ),
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
