import "package:flutter/material.dart";

import "../api_error_message.dart";
import "../app_services.dart";
import "../design_tokens.dart";
import "../widgets/app_card.dart";
import "../widgets/app_primary_button.dart";
import "../widgets/app_text_field.dart";

class AdminLessonContentScreen extends StatefulWidget {
  const AdminLessonContentScreen({
    super.key,
    required this.lessonId,
    this.initial,
  });

  final String lessonId;
  final Map<String, dynamic>? initial;

  @override
  State<AdminLessonContentScreen> createState() => _AdminLessonContentScreenState();
}

class _AdminLessonContentScreenState extends State<AdminLessonContentScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initial?["title"]?.toString() ?? "");
  List<Map<String, dynamic>> _blocks = [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final raw = widget.initial?["blocks"];
    if (raw is List) {
      _blocks = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _addMarkdownBlock() {
    setState(() {
      _blocks.add({
        "type": "markdown",
        "payload": {"text": ""},
      });
    });
  }

  void _addVideoBlock() {
    setState(() {
      _blocks.add({
        "type": "video",
        "payload": {"url": ""},
      });
    });
  }

  void _addAssignmentBlock() {
    setState(() {
      _blocks.add({
        "type": "assignment",
        "payload": {"text": ""},
      });
    });
  }

  /// Русское название типа блока для UI (в коде остаётся markdown, video и т.д.).
  String _typeLabel(String t) {
    switch (t) {
      case "markdown":
        return "Текст";
      case "video":
        return "Ссылка (видео или статья)";
      case "assignment":
        return "Задание";
      case "quiz":
        return "Квиз";
      default:
        return t;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await appServices.api.adminUpdateLesson(widget.lessonId, {
        "title": _title.text.trim(),
        "blocks": _blocks,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Контент урока сохранен")),
      );
      appServices.notifyLearnContentChanged();
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = readableApiError(e, authFailure: "Не удалось сохранить урок");
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Контент урока")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          AppTextField(controller: _title, label: "Название урока"),
          const SizedBox(height: AppSpace.sm),
          Text(
            "Добавьте блоки контента. Потом они будут отображаться студенту в уроке.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.tonal(onPressed: _addMarkdownBlock, child: const Text("Добавить текст")),
              const SizedBox(height: AppSpace.xs),
              FilledButton.tonal(
                onPressed: _addVideoBlock,
                child: const Text("Добавить ссылку на видео или статью"),
              ),
              const SizedBox(height: AppSpace.xs),
              FilledButton.tonal(onPressed: _addAssignmentBlock, child: const Text("Добавить задание")),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          for (var i = 0; i < _blocks.length; i++)
            AppCard(
              margin: const EdgeInsets.only(bottom: AppSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Блок ${i + 1}: ${_typeLabel(_blocks[i]["type"]?.toString() ?? "")}",
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpace.xs),
                  if (_blocks[i]["type"] == "markdown")
                    TextFormField(
                      initialValue: (_blocks[i]["payload"]?["text"] ?? "").toString(),
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: "Введите учебный текст для урока",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _blocks[i]["payload"] = {"text": value};
                      },
                    ),
                  if (_blocks[i]["type"] == "video")
                    TextFormField(
                      initialValue: (_blocks[i]["payload"]?["url"] ?? "").toString(),
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: "Ссылка на видео или статью (https://...)",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _blocks[i]["payload"] = {"url": value};
                      },
                    ),
                  if (_blocks[i]["type"] == "assignment")
                    TextFormField(
                      initialValue: (_blocks[i]["payload"]?["text"] ?? "").toString(),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: "Напишите, что должен сделать студент",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _blocks[i]["payload"] = {"text": value};
                      },
                    ),
                  if (_blocks[i]["type"] == "quiz")
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "Квиз редактируется на отдельном экране «Редактировать квиз».",
                      ),
                    ),
                  const SizedBox(height: AppSpace.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _blocks.removeAt(i);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
                      ),
                      child: const Text("Удалить блок"),
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: AppSpace.sm),
          AppPrimaryButton(
            label: "Сохранить контент",
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
