import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/link.dart";

import "../app_services.dart";

const _adminRequestMailUri = "mailto:nikitafritsler@gmail.com";

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _roleLabel(String? role) {
    switch (role) {
      case "student":
        return "Ученик";
      case "admin":
        return "Администратор";
      case null:
      case "":
        return "—";
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Профиль")),
      body: ValueListenableBuilder(
        valueListenable: appServices.currentSession,
        builder: (context, session, _) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Имя: ${session?.name ?? "—"}",
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text("Email: ${session?.email ?? "—"}", style: Theme.of(context).textTheme.bodyLarge),
                Text("Роль: ${_roleLabel(session?.role)}"),
                if (session?.role != "admin") ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          const TextSpan(text: "Хотите стать администратором? "),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: Link(
                              uri: Uri.parse(_adminRequestMailUri),
                              builder: (context, followLink) {
                                return GestureDetector(
                                  onTap: followLink,
                                  child: Text(
                                    "Свяжитесь, чтобы получить доступ.",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await appServices.authStorage.clear();
                    appServices.api.setAccessToken(null);
                    appServices.currentSession.value = null;
                    if (context.mounted) context.go("/login");
                  },
                  child: const Text("Выйти"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
