import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/material.dart";

/// Полоска под заголовком: офлайн-режим (подписка + первичная проверка).
class OfflineStrip extends StatefulWidget {
  const OfflineStrip({super.key, required this.connectivity});

  final Connectivity connectivity;

  @override
  State<OfflineStrip> createState() => _OfflineStripState();
}

class _OfflineStripState extends State<OfflineStrip> {
  List<ConnectivityResult> _status = const [];
  bool _ready = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get _offline => _status.contains(ConnectivityResult.none) || _status.isEmpty;

  @override
  void initState() {
    super.initState();
    widget.connectivity.checkConnectivity().then((v) {
      if (mounted) setState(() {
        _status = v;
        _ready = true;
      });
    });
    _sub = widget.connectivity.onConnectivityChanged.listen((v) {
      if (mounted) {
        setState(() {
          _status = v;
          _ready = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || !_offline) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.wifi_off_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Нет сети — показано из локального кэша",
                  style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
