import "dart:convert";

import "package:flutter/material.dart";

import "../api_error_message.dart";
import "../app_services.dart";
import "../design_tokens.dart";
import "../widgets/app_primary_button.dart";
import "../widgets/app_text_field.dart";

class AdminQuizEditorScreen extends StatefulWidget {
  const AdminQuizEditorScreen({super.key, required this.lessonId, this.initialLesson});

  final String lessonId;
  final Map<String, dynamic>? initialLesson;

  @override
  State<AdminQuizEditorScreen> createState() => _AdminQuizEditorScreenState();
}

class _AdminQuizEditorScreenState extends State<AdminQuizEditorScreen> {
  final _title = TextEditingController();
  List<Map<String, dynamic>> _questions = [];
  bool _loading = false;
  String? _quizId;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final q = await appServices.api.adminQuizByLesson(widget.lessonId);
      _quizId = q["id"]?.toString();
      _title.text = q["title"]?.toString() ?? "";
      final raw = q["questions"];
      if (raw is List) {
        _questions = raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
    } catch (_) {
      // quiz may be absent; this is fine for create flow
    }
    if (_questions.isEmpty) {
      _questions = [
        {
          "id": "q1",
          "text": "",
          "options": [
            {"id": "a", "text": "", "is_correct": true},
            {"id": "b", "text": "", "is_correct": false},
          ],
        },
      ];
    }
    _normalizeAllQuestionOptions();
    if (mounted) setState(() {});
  }

  static String _nextOptionId(List<Map<String, dynamic>> existing) {
    final used = existing.map((o) => o["id"]?.toString() ?? "").toSet();
    for (var c = 0; c < 26; c++) {
      final id = String.fromCharCode(97 + c);
      if (!used.contains(id)) return id;
    }
    return "opt_${existing.length}_${DateTime.now().microsecondsSinceEpoch}";
  }

  static List<Map<String, dynamic>> _coerceOptionsList(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Минимум два варианта, ровно один помечен как верный.
  void _normalizeAllQuestionOptions() {
    for (final q in _questions) {
      var opts = _coerceOptionsList(q["options"]);
      while (opts.length < 2) {
        opts.add({"id": _nextOptionId(opts), "text": "", "is_correct": opts.isEmpty});
      }
      _ensureSingleCorrect(opts);
      q["options"] = opts;
    }
  }

  static void _ensureSingleCorrect(List<Map<String, dynamic>> opts) {
    var idx = opts.indexWhere((o) => o["is_correct"] == true);
    if (idx < 0) {
      for (final o in opts) {
        o["is_correct"] = false;
      }
      opts[0]["is_correct"] = true;
      return;
    }
    for (var i = 0; i < opts.length; i++) {
      opts[i]["is_correct"] = i == idx;
    }
  }

  List<Map<String, dynamic>> _normalizeBlocks(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => (e as Map).cast<String, dynamic>()).toList();
        }
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      final next = _questions.length + 1;
      _questions.add({
        "id": "q$next",
        "text": "",
        "options": [
          {"id": "a", "text": "", "is_correct": true},
          {"id": "b", "text": "", "is_correct": false},
        ],
      });
    });
  }

  void _addOption(int questionIndex) {
    setState(() {
      var raw = _questions[questionIndex]["options"];
      if (raw is! List) {
        raw = <dynamic>[];
        _questions[questionIndex]["options"] = raw;
      }
      final opts = raw;
      final maps = opts.map((e) => e as Map<String, dynamic>).toList();
      opts.add({
        "id": _nextOptionId(maps),
        "text": "",
        "is_correct": false,
      });
    });
  }

  void _removeOption(int questionIndex, int optionIndex) {
    setState(() {
      final opts = _questions[questionIndex]["options"] as List;
      if (opts.length <= 2) return;
      opts.removeAt(optionIndex);
      _ensureSingleCorrect(opts.cast<Map<String, dynamic>>());
    });
  }

  Future<void> _removeQuestion(int index) async {
    if (_questions.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Нельзя удалить последний вопрос")),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить вопрос"),
        content: Text("Удалить вопрос ${index + 1}? Это действие можно отменить только до сохранения."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _questions.removeAt(index);
      _normalizeAllQuestionOptions();
    });
  }

  Widget _buildQuestionCard(BuildContext context, int i) {
    final raw = _questions[i]["options"];
    final opts = (raw is List ? raw : const <dynamic>[]).cast<Map<String, dynamic>>();
    var correctIndex = opts.indexWhere((o) => o["is_correct"] == true);
    if (correctIndex < 0) correctIndex = 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text("Вопрос ${i + 1}", style: Theme.of(context).textTheme.titleSmall),
                ),
                if (_questions.length > 1)
                  IconButton(
                    tooltip: "Удалить вопрос",
                    onPressed: () => _removeQuestion(i),
                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xs),
            TextFormField(
              initialValue: (_questions[i]["text"] ?? "").toString(),
              decoration: const InputDecoration(labelText: "Текст вопроса"),
              onChanged: (v) => _questions[i]["text"] = v,
            ),
            const SizedBox(height: AppSpace.sm),
            Text("Варианты ответа", style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpace.xs),
            for (var j = 0; j < opts.length; j++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      key: ValueKey("${_questions[i]["id"]}_${opts[j]["id"]}"),
                      initialValue: (opts[j]["text"] ?? "").toString(),
                      decoration: InputDecoration(
                        labelText: "Вариант ${j + 1}",
                      ),
                      onChanged: (v) => opts[j]["text"] = v,
                    ),
                  ),
                  if (opts.length > 2)
                    IconButton(
                      tooltip: "Удалить вариант",
                      onPressed: () => _removeOption(i, j),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.xs),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addOption(i),
                icon: const Icon(Icons.add),
                label: const Text("Добавить вариант"),
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            DropdownButtonFormField<int>(
              value: correctIndex.clamp(0, opts.length - 1),
              decoration: const InputDecoration(
                labelText: "Правильный ответ",
                border: OutlineInputBorder(),
              ),
              items: [
                for (var j = 0; j < opts.length; j++)
                  DropdownMenuItem(value: j, child: Text("Вариант ${j + 1}")),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  for (var k = 0; k < opts.length; k++) {
                    opts[k]["is_correct"] = k == v;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Квиз урока")),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.md),
        children: [
          AppTextField(controller: _title, label: "Название квиза"),
          const SizedBox(height: AppSpace.sm),
          for (var i = 0; i < _questions.length; i++) _buildQuestionCard(context, i),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: _addQuestion,
              child: const Text("Добавить вопрос"),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: AppSpace.md),
          AppPrimaryButton(
            label: _quizId == null ? "Создать квиз" : "Сохранить квиз",
            loading: _loading,
            onPressed: () async {
              setState(() {
                _loading = true;
                _message = null;
              });
              try {
                final body = {
                  "title": _title.text.trim(),
                  "questions": _questions,
                };
                if (_quizId == null) {
                  final created = await appServices.api.adminCreateQuiz(widget.lessonId, body);
                  _quizId = created["id"]?.toString();
                } else {
                  await appServices.api.adminUpdateQuiz(_quizId!, body);
                }
                if (_quizId != null) {
                  final existingBlocks = _normalizeBlocks(widget.initialLesson?["blocks"]);
                  final hasQuizBlock = existingBlocks.any(
                    (b) =>
                        b["type"] == "quiz" &&
                        ((b["payload"] as Map?)?["quiz_id"]?.toString() ?? "") == (_quizId ?? ""),
                  );
                  if (!hasQuizBlock) {
                    existingBlocks.add({
                      "type": "quiz",
                      "payload": {"quiz_id": _quizId},
                    });
                    await appServices.api.adminUpdateLesson(widget.lessonId, {
                      "blocks": existingBlocks,
                    });
                  }
                }
                if (!mounted) return;
                appServices.notifyLearnContentChanged();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Квиз сохранен и добавлен в урок")),
                );
              } catch (e) {
                setState(
                  () => _message = readableApiError(
                    e,
                    authFailure: "Не удалось сохранить квиз",
                  ),
                );
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
          ),
          if (_quizId != null) ...[
            const SizedBox(height: AppSpace.sm),
            AppPrimaryButton(
              label: "Удалить квиз",
              destructive: true,
              onPressed: () async {
                try {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Удалить квиз"),
                      content: const Text("Вы уверены? Это действие нельзя отменить."),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                          ),
                          child: const Text("Удалить"),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await appServices.api.adminDeleteQuiz(_quizId!);
                  if (!mounted) return;
                  appServices.notifyLearnContentChanged();
                  Navigator.of(context).pop(true);
                } catch (e) {
                  setState(
                    () => _message = readableApiError(
                      e,
                      authFailure: "Не удалось удалить квиз",
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
