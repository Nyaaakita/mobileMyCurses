import "package:flutter/material.dart";

import "../api_error_message.dart";
import "../app_services.dart";
import "../design_tokens.dart";
import "../widgets/app_primary_button.dart";
import "../widgets/app_text_field.dart";

class AdminCourseEditScreen extends StatefulWidget {
  const AdminCourseEditScreen({super.key, required this.courseId, this.initial});

  final String courseId;
  final Map<String, dynamic>? initial;

  @override
  State<AdminCourseEditScreen> createState() => _AdminCourseEditScreenState();
}

class _AdminCourseEditScreenState extends State<AdminCourseEditScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?["title"]?.toString() ?? "");
  late final TextEditingController _desc =
      TextEditingController(text: widget.initial?["description"]?.toString() ?? "");
  String _difficulty = "beginner";
  bool _published = true;
  String? _message;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initial?["difficulty"]?.toString();
    if (d == "beginner" || d == "intermediate" || d == "advanced") {
      _difficulty = d!;
    }
    _published = widget.initial?["is_published"] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Редактировать курс")),
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
                  AppTextField(controller: _desc, label: "Описание"),
                  const SizedBox(height: AppSpace.md),
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
                  SwitchListTile(
                    title: const Text("Опубликован"),
                    value: _published,
                    onChanged: (v) => setState(() => _published = v),
                  ),
                  if (_message != null)
                    Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  AppPrimaryButton(
                    label: "Сохранить",
                    loading: _loading,
                    onPressed: () async {
                      setState(() {
                        _loading = true;
                        _message = null;
                      });
                      try {
                        await appServices.api.adminUpdateCourse(widget.courseId, {
                          "title": _title.text.trim(),
                          "description": _desc.text.trim(),
                          "difficulty": _difficulty,
                          "is_published": _published,
                        });
                        if (!mounted) return;
                        appServices.notifyLearnContentChanged();
                        Navigator.of(context).pop(true);
                      } catch (e) {
                        setState(
                          () => _message = readableApiError(
                            e,
                            authFailure: "Не удалось сохранить курс",
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
