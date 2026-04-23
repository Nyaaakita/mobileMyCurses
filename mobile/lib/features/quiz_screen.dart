import "dart:convert";

import "package:flutter/material.dart";

import "../api_error_message.dart";
import "../app_services.dart";
import "../route_args.dart";
import "../widgets/empty_state.dart";

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.quizId, this.extra});

  final String quizId;
  final QuizRouteExtra? extra;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final Map<String, String> _selected = {};
  Map<String, dynamic>? _result;
  String? _error;

  late final Future<Map<String, dynamic>> _quizFuture =
      appServices.api.quizForAttempt(widget.quizId);

  Future<void> _submit(List<Map<String, dynamic>> qs) async {
    if (_selected.length < qs.length) return;
    final answers = qs.map((q) {
      final id = q["id"] as String;
      return {
        "question_id": id,
        "selected_option_ids": [_selected[id]!],
      };
    }).toList();
    try {
      final r = await appServices.api.quizSubmit(widget.quizId, {"answers": answers});
      appServices.notifyLearnContentChanged();
      setState(() => _result = r);
    } catch (e) {
      setState(
        () => _error = readableApiError(
          e,
          authFailure: "Не удалось отправить ответы",
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.extra?.title ?? "Тест")),
      body: _result != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      "Балл: ${_result!["score"]}/${_result!["max_score"]}\nПройден: ${_result!["passed"]}",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
            )
          : FutureBuilder<Map<String, dynamic>>(
              future: _quizFuture,
              builder: (context, snap) {
                if (snap.hasError) {
                  return EmptyState(
                    title: "Не удалось загрузить тест",
                    message: readableApiError(
                      snap.error!,
                      authFailure: "Проверьте подключение и попробуйте снова",
                    ),
                    icon: Icons.quiz_outlined,
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final raw = snap.data!["questions"];
                final list = (raw is String ? jsonDecode(raw) : raw) as List<dynamic>;
                final qs = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    for (final q in qs) _QuestionCard(
                      question: q,
                      selectedOptionId: _selected[q["id"] as String],
                      onPick: (optId) => setState(() => _selected[q["id"] as String] = optId),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _selected.length >= qs.length ? () => _submit(qs) : null,
                      child: const Text("Проверить"),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.selectedOptionId,
    required this.onPick,
  });

  final Map<String, dynamic> question;
  final String? selectedOptionId;
  final void Function(String optionId) onPick;

  @override
  Widget build(BuildContext context) {
    final opts = (question["options"] as List<dynamic>? ?? [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question["text"] as String? ?? "", style: const TextStyle(fontWeight: FontWeight.w600)),
            RadioGroup<String>(
              groupValue: selectedOptionId,
              onChanged: (value) {
                if (value != null) onPick(value);
              },
              child: Column(
                children: [
                  for (final o in opts)
                    RadioListTile<String>(
                      value: o["id"] as String,
                      title: Text(o["text"] as String? ?? ""),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
