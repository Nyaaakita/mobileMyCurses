import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_services.dart";
import "../design_tokens.dart";
import "../models.dart";
import "../widgets/empty_state.dart";

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  /// Пересоздаётся только по [learnContentEpoch] или первому открытию — не на каждый rebuild Shell.
  late Future<List<Course>> _coursesFuture;

  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;
  String _query = "";

  @override
  void initState() {
    super.initState();
    _coursesFuture = appServices.repository.getCoursesCacheFirst();
    appServices.learnContentEpoch.addListener(_onLearnContentChanged);
  }

  void _onLearnContentChanged() {
    if (!mounted) return;
    setState(() {
      _coursesFuture = appServices.repository.getCoursesCacheFirst();
    });
  }

  @override
  void dispose() {
    appServices.learnContentEpoch.removeListener(_onLearnContentChanged);
    _searchController.dispose();
    super.dispose();
  }

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

  List<Course> _filterCourses(List<Course> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((c) {
      return c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          _difficultyLabel(c.difficulty).toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: "Поиск по названию и описанию",
                  border: InputBorder.none,
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text("Каталог курсов"),
        actions: [
          if (_searchOpen)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: "Закрыть поиск",
              onPressed: () {
                setState(() {
                  _searchOpen = false;
                  _query = "";
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: "Поиск",
              onPressed: () => setState(() => _searchOpen = true),
            ),
        ],
      ),
      body: FutureBuilder<List<Course>>(
        future: _coursesFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return EmptyState(
              title: "Пока нет курсов",
              message: "Запустите бэкенд и миграции или подождите синхронизацию.",
            );
          }
          final filtered = _filterCourses(list);
          if (filtered.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: EmptyState(
                title: "Ничего не найдено",
                message: "Попробуйте другой запрос или сбросьте поиск.",
                icon: Icons.search_off_outlined,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final c = filtered[i];
              return Card(
                child: ListTile(
                  title: Text(c.title),
                  subtitle: Text("${_difficultyLabel(c.difficulty)} · ${c.progressPercent}%"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.push("/course/${c.id}");
                    if (!mounted) return;
                    _onLearnContentChanged();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
