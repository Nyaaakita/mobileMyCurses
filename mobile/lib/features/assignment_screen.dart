import "package:flutter/material.dart";

import "../api_error_message.dart";
import "../app_services.dart";
import "../route_args.dart";

class AssignmentScreen extends StatefulWidget {
  const AssignmentScreen({super.key, required this.assignmentId, this.extra});

  final String assignmentId;
  final AssignmentRouteExtra? extra;

  @override
  State<AssignmentScreen> createState() => _AssignmentScreenState();
}

class _AssignmentScreenState extends State<AssignmentScreen> {
  final _ctrl = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await appServices.api.assignmentSubmit(widget.assignmentId, {
        "answer_text": _ctrl.text.trim(),
      });
      appServices.notifyLearnContentChanged();
      setState(() => _result = r);
    } catch (e) {
      setState(
        () => _error = readableApiError(
          e,
          authFailure: "Не удалось отправить задание",
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.extra?.title ?? "Задание")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _result != null
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Статус: ${_result!["status"]}\nОтвет: ${_result!["feedback"]}",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(labelText: "Ваш ответ"),
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  FilledButton(
                    onPressed: _loading ? null : _send,
                    child: Text(_loading ? "…" : "Отправить"),
                  ),
                ],
              ),
      ),
    );
  }
}
