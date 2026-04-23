import "package:flutter/material.dart";

import "../api_error_message.dart";
import "../app_services.dart";
import "../design_tokens.dart";
import "../widgets/app_primary_button.dart";
import "../widgets/app_text_field.dart";

class AdminCourseCreateScreen extends StatefulWidget {
  const AdminCourseCreateScreen({super.key});

  @override
  State<AdminCourseCreateScreen> createState() => _AdminCourseCreateScreenState();
}

class _AdminCourseCreateScreenState extends State<AdminCourseCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _difficulty = "beginner";
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Создать курс")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(controller: _title, label: "Название"),
                  const SizedBox(height: AppSpace.sm),
                  AppTextField(controller: _desc, label: "Описание (минимум 10 символов)"),
                  const SizedBox(height: AppSpace.md),
                  Text("Сложность", style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: AppSpace.xs),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: "beginner", label: Text("Начальный")),
                      ButtonSegment(value: "intermediate", label: Text("Средний")),
                      ButtonSegment(value: "advanced", label: Text("Продвинутый")),
                    ],
                    selected: {_difficulty},
                    onSelectionChanged: (s) {
                      if (s.isNotEmpty) setState(() => _difficulty = s.first);
                    },
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    "Курс сохранится как черновик. Опубликовать можно позже в редактировании.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  AppPrimaryButton(
                    label: "Создать",
                    loading: _loading,
                    onPressed: () async {
                      setState(() {
                        _loading = true;
                        _message = null;
                      });
                      try {
                        final c = await appServices.api.adminCreateCourse({
                          "title": _title.text.trim(),
                          "description": _desc.text.trim(),
                          "difficulty": _difficulty,
                          "is_published": false,
                        });
                        if (!mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text("Черновик создан: ${c["title"]}")));
                        appServices.notifyLearnContentChanged();
                        Navigator.of(context).pop(true);
                      } catch (e) {
                        if (!mounted) return;
                        setState(
                          () => _message = readableApiError(
                            e,
                            authFailure: "Не удалось создать черновик курса",
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
          ),
        ],
      ),
    );
  }
}
