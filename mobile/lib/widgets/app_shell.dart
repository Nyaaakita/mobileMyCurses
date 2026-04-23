import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_services.dart";
import "../models.dart";
import "offline_banner.dart";

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _indexForPath(String path, {required bool isAdmin}) {
    if (path.startsWith("/my-courses")) return 1;
    if (path.startsWith("/calendar")) return 2;
    if (path.startsWith("/profile")) return 3;
    if (path.startsWith("/admin") && isAdmin) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;

    return ValueListenableBuilder<Session?>(
      valueListenable: appServices.currentSession,
      builder: (context, session, _) {
        final isAdmin = session?.role == "admin";
        final idx = _indexForPath(loc, isAdmin: isAdmin);
        final destinations = <NavigationDestination>[
          const NavigationDestination(icon: Icon(Icons.school_outlined), label: "Курсы"),
          const NavigationDestination(icon: Icon(Icons.play_lesson_outlined), label: "Мои"),
          const NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: "Календарь"),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: "Профиль"),
          if (isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: "Админ",
            ),
        ];
        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OfflineStrip(connectivity: appServices.connectivity),
              Expanded(child: child),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx >= destinations.length ? 0 : idx,
            onDestinationSelected: (i) {
              switch (i) {
                case 0:
                  context.go("/catalog");
                  break;
                case 1:
                  context.go("/my-courses");
                  break;
                case 2:
                  context.go("/calendar");
                  break;
                case 3:
                  context.go("/profile");
                  break;
                case 4:
                  if (isAdmin) context.go("/admin");
                  break;
              }
            },
            destinations: destinations,
          ),
        );
      },
    );
  }
}
