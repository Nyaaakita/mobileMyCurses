import "package:device_calendar/device_calendar.dart";
import "package:flutter/material.dart";
import "package:table_calendar/table_calendar.dart";
import "package:timezone/timezone.dart" as tz;

import "../widgets/empty_state.dart";

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarEventItem {
  const _CalendarEventItem({required this.calendarId, required this.event});

  final String calendarId;
  final Event event;
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool _loading = true;
  String? _error;
  List<Calendar> _calendars = const [];
  List<String> _calendarIds = const [];
  String? _writeCalendarId;
  List<_CalendarEventItem> _events = const [];
  final Map<DateTime, int> _eventCountByDay = {};

  @override
  void initState() {
    super.initState();
    _loadForSelectedDay(refreshMonthMarkers: true);
  }

  DateTime _normalizeDay(DateTime day) => DateTime(day.year, day.month, day.day);

  DateTime _startOfDay(DateTime day) => _normalizeDay(day);

  DateTime _endOfDay(DateTime day) => DateTime(day.year, day.month, day.day, 23, 59, 59);

  DateTime? _toLocalTime(DateTime? value) {
    if (value == null) return null;
    // device_calendar may return TZDateTime in UTC location.
    // Convert by epoch to device-local wall time reliably.
    return DateTime.fromMillisecondsSinceEpoch(
      value.millisecondsSinceEpoch,
      isUtc: true,
    ).toLocal();
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day, {
    bool isSelected = false,
    bool isToday = false,
  }) {
    final hasEvents = (_eventCountByDay[_normalizeDay(day)] ?? 0) > 0;
    final cs = Theme.of(context).colorScheme;
    final bgColor = isSelected
        ? cs.primary
        : isToday
            ? cs.primary.withValues(alpha: 0.14)
            : Colors.transparent;
    final textColor = isSelected
        ? cs.onPrimary
        : isToday
            ? cs.primary
            : Theme.of(context).textTheme.bodyMedium?.color;
    final borderColor = isSelected
        ? Colors.transparent
        : hasEvents
            ? cs.primary.withValues(alpha: 0.6)
            : Colors.transparent;

    return Center(
      child: SizedBox(
        width: 36,
        height: 36,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: borderColor == Colors.transparent ? 0 : 1.4,
            ),
          ),
          child: Center(
            child: Text(
              "${day.day}",
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _ensurePermission() async {
    final has = await _calendarPlugin.hasPermissions();
    if (has.isSuccess && (has.data ?? false)) return true;
    final req = await _calendarPlugin.requestPermissions();
    return req.isSuccess && (req.data ?? false);
  }

  Future<List<String>> _resolveReadableCalendarIds() async {
    final result = await _calendarPlugin.retrieveCalendars();
    if (!result.isSuccess || result.data == null || result.data!.isEmpty) {
      return const [];
    }
    return result.data!
        .map((c) => c.id)
        .whereType<String>()
        .toList();
  }

  String? _pickDefaultWritableCalendarId(List<Calendar> calendars) {
    final writable = calendars.where((c) => c.isReadOnly != true && c.id != null).toList();
    if (writable.isEmpty) return null;
    final googleLike = writable.where((c) {
      final t = (c.accountType ?? "").toLowerCase();
      final n = (c.accountName ?? "").toLowerCase();
      return t.contains("google") || n.contains("gmail");
    }).toList();
    if (googleLike.isNotEmpty) return googleLike.first.id;
    final defaultCalendar = writable.where((c) => c.isDefault == true).toList();
    if (defaultCalendar.isNotEmpty) return defaultCalendar.first.id;
    return writable.first.id;
  }

  bool _inMonth(DateTime day, DateTime month) =>
      day.year == month.year && day.month == month.month;

  Future<List<_CalendarEventItem>> _loadEventsForRange(DateTime start, DateTime end) async {
    final all = <_CalendarEventItem>[];
    for (final calId in _calendarIds) {
      final res = await _calendarPlugin.retrieveEvents(
        calId,
        RetrieveEventsParams(startDate: start, endDate: end),
      );
      if (res.isSuccess && res.data != null) {
        all.addAll(res.data!.map((e) => _CalendarEventItem(calendarId: calId, event: e)));
      }
    }
    all.sort((a, b) {
      final at = a.event.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.event.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      return at.compareTo(bt);
    });
    return all;
  }

  Future<void> _loadMonthMarkers() async {
    final nextCounts = <DateTime, int>{};
    final from = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final to = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);
    final events = await _loadEventsForRange(from, to);
    for (final e in events) {
      final start = e.event.start;
      if (start == null) continue;
      final day = _normalizeDay(start);
      nextCounts[day] = (nextCounts[day] ?? 0) + 1;
    }
    _eventCountByDay
      ..clear()
      ..addAll(nextCounts);
  }

  Future<void> _loadForSelectedDay({bool refreshMonthMarkers = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final granted = await _ensurePermission();
      if (!granted) {
        setState(() {
          _loading = false;
          _error = "Нет доступа к календарю телефона";
        });
        return;
      }
      final calendarsRes = await _calendarPlugin.retrieveCalendars();
      _calendars = calendarsRes.isSuccess ? (calendarsRes.data ?? const []) : const [];
      _calendarIds = _calendars.map((c) => c.id).whereType<String>().toList();
      if (_calendarIds.isEmpty) {
        final hasAnyCalendars = _calendars.isNotEmpty;
        final hasErrors = calendarsRes.errors.isNotEmpty;
        final details = hasErrors
            ? (calendarsRes.errors.first.errorMessage ?? "Ошибка получения календарей")
            : hasAnyCalendars
                ? "Календари найдены, но их идентификаторы недоступны в release-сборке."
                : "Плагин не вернул доступные системные календари.";
        setState(() {
          _loading = false;
          _events = const [];
          _error = "Календарь недоступен. $details";
        });
        return;
      }
      _writeCalendarId = _pickDefaultWritableCalendarId(_calendars);
      if (refreshMonthMarkers) {
        await _loadMonthMarkers();
      }
      final dayEvents = await _loadEventsForRange(
        _startOfDay(_selectedDay),
        _endOfDay(_selectedDay),
      );
      if (!mounted) return;
      setState(() {
        _events = dayEvents;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Не удалось загрузить события календаря";
      });
    }
  }

  Future<void> _addNoteDialog() async {
    final writableCalendarId = _writeCalendarId ?? _pickDefaultWritableCalendarId(_calendars);
    if (writableCalendarId == null) return;
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var selectedTime = const TimeOfDay(hour: 9, minute: 0);
    final timeCtrl = TextEditingController(
      text: "${selectedTime.hour.toString().padLeft(2, "0")}:${selectedTime.minute.toString().padLeft(2, "0")}",
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
          title: const Text("Новая заметка"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Название"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: "Текст заметки"),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(labelText: "Время (HH:MM)"),
                readOnly: true,
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (picked == null) return;
                  setDialogState(() {
                    selectedTime = picked;
                    timeCtrl.text =
                        "${picked.hour.toString().padLeft(2, "0")}:${picked.minute.toString().padLeft(2, "0")}";
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Отмена"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Сохранить"),
            ),
          ],
        ),
        );
      },
    );
    if (ok != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final localStart = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    // device_calendar expects TZDateTime absolute moment. Convert local wall-clock time to UTC.
    final start = tz.TZDateTime.from(localStart.toUtc(), tz.UTC);
    final end = start.add(const Duration(minutes: 30));
    final event = Event(
      writableCalendarId,
      title: title,
      description: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      start: start,
      end: end,
    );
    await _calendarPlugin.createOrUpdateEvent(event);
    await _loadForSelectedDay();
  }

  Future<void> _editEventDialog(_CalendarEventItem item) async {
    final e = item.event;
    final titleCtrl = TextEditingController(text: e.title ?? "");
    final noteCtrl = TextEditingController(text: e.description ?? "");
    final baseTime =
        _toLocalTime(e.start) ?? DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day, 9, 0);
    var selectedTime = TimeOfDay(hour: baseTime.hour, minute: baseTime.minute);
    final timeCtrl = TextEditingController(
      text: "${selectedTime.hour.toString().padLeft(2, "0")}:${selectedTime.minute.toString().padLeft(2, "0")}",
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
        title: const Text("Редактировать заметку"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Название")),
            const SizedBox(height: 8),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: "Текст заметки"),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: timeCtrl,
              decoration: const InputDecoration(labelText: "Время (HH:MM)"),
              readOnly: true,
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (picked == null) return;
                setDialogState(() {
                  selectedTime = picked;
                  timeCtrl.text =
                      "${picked.hour.toString().padLeft(2, "0")}:${picked.minute.toString().padLeft(2, "0")}";
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Сохранить")),
        ],
      ),
      ),
    );
    if (ok != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final eventDay = _toLocalTime(e.start) ?? _selectedDay;
    final localStart = DateTime(
      eventDay.year,
      eventDay.month,
      eventDay.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final start = tz.TZDateTime.from(localStart.toUtc(), tz.UTC);
    final end = start.add(const Duration(minutes: 30));
    if (e.eventId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Нельзя отредактировать это событие")),
      );
      return;
    }
    final updated = Event(
      item.calendarId,
      eventId: e.eventId,
      title: title,
      description: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
      start: start,
      end: end,
    );
    final result = await _calendarPlugin.createOrUpdateEvent(updated);
    if (!mounted) return;
    if (result == null || !result.isSuccess) {
      // Fallback for plugin-specific update errors on some devices:
      // recreate event with new time instead of update-in-place.
      if (e.eventId != null) {
        await _calendarPlugin.deleteEvent(item.calendarId, e.eventId!);
      }
      final recreated = Event(
        item.calendarId,
        title: title,
        description: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        start: start,
        end: end,
      );
      final recreateResult = await _calendarPlugin.createOrUpdateEvent(recreated);
      if (recreateResult == null || !recreateResult.isSuccess) {
        final msg = (recreateResult?.errors.isNotEmpty ?? false)
            ? recreateResult!.errors.first.errorMessage ?? "Не удалось сохранить изменения"
            : "Не удалось сохранить изменения";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }
    }
    await _loadForSelectedDay();
  }

  Future<void> _deleteEvent(_CalendarEventItem item) async {
    final e = item.event;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Удалить заметку"),
        content: const Text("Это действие нельзя отменить. Продолжить?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (e.eventId == null) return;
    final result = await _calendarPlugin.deleteEvent(item.calendarId, e.eventId!);
    if (!mounted) return;
    if (!result.isSuccess) {
      final msg = result.errors.isNotEmpty
          ? result.errors.first.errorMessage ?? "Не удалось удалить заметку"
          : "Не удалось удалить заметку";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }
    await _loadForSelectedDay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Календарь")),
      body: Column(
        children: [
          TableCalendar<Event>(
            locale: "ru_RU",
            firstDay: DateTime(2000),
            lastDay: DateTime(2100),
            focusedDay: _focusedDay,
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableCalendarFormats: const {CalendarFormat.month: "Месяц"},
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            eventLoader: (day) => const <Event>[],
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
              _loadForSelectedDay(refreshMonthMarkers: true);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _loadForSelectedDay();
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) => _buildDayCell(context, day),
              todayBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day, isToday: true),
              selectedBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day, isSelected: true),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? EmptyState(
                        title: "Календарь недоступен",
                        message: _error,
                        icon: Icons.event_busy_outlined,
                      )
                    : _events.isEmpty
                        ? const EmptyState(
                            title: "На выбранную дату событий нет",
                            icon: Icons.event_note_outlined,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: _events.length,
                            itemBuilder: (context, i) {
                              final item = _events[i];
                              final e = item.event;
                              final start = _toLocalTime(e.start);
                              final hh = start?.hour.toString().padLeft(2, "0") ?? "--";
                              final mm = start?.minute.toString().padLeft(2, "0") ?? "--";
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.event_outlined),
                                  title: Text(e.title?.trim().isNotEmpty == true ? e.title! : "Без названия"),
                                  subtitle: Text(
                                    "${hh}:$mm${(e.description?.trim().isNotEmpty ?? false) ? "\n${e.description}" : ""}",
                                  ),
                                  isThreeLine: e.description?.trim().isNotEmpty == true,
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == "edit") {
                                        _editEventDialog(item);
                                      } else if (value == "delete") {
                                        _deleteEvent(item);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: "edit", child: Text("Редактировать")),
                                      PopupMenuItem(value: "delete", child: Text("Удалить")),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _calendarIds.isEmpty ? null : _addNoteDialog,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text("Добавить заметку"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
