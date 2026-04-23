import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:go_router/go_router.dart";

import "api_client.dart";
import "app_services.dart";
import "app_theme.dart";
import "config.dart";
import "course_repository.dart";
import "router/app_router.dart";
import "services/auth_storage.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient(baseUrl: AppConfig.apiBaseUri.toString());
  final connectivity = Connectivity();
  final repository = CourseRepository(api: api, connectivity: connectivity);
  appServices = AppServices(
    api: api,
    repository: repository,
    authStorage: AuthStorage(),
    connectivity: connectivity,
  );
  repository.onLearnContentStale = () => appServices.notifyLearnContentChanged();
  api.configureAuthLifecycle(
    refreshSession: () async {
      final stored = await appServices.authStorage.readSession();
      if (stored == null) return null;
      final next = await appServices.api.refresh(stored.refreshToken);
      await appServices.authStorage.saveSession(
        accessToken: next.accessToken,
        refreshToken: next.refreshToken,
        role: next.role,
        userId: next.userId,
        email: next.email,
        name: next.name,
      );
      appServices.currentSession.value = next;
      return next;
    },
    onUnauthorized: () async {
      await appServices.authStorage.clear();
      appServices.currentSession.value = null;
      appServices.api.setAccessToken(null);
    },
  );
  appServices.repository.startAutoSync();

  runApp(const LmsApp());
}

class LmsApp extends StatefulWidget {
  const LmsApp({super.key});

  @override
  State<LmsApp> createState() => _LmsAppState();
}

class _LmsAppState extends State<LmsApp> with WidgetsBindingObserver {
  late final GoRouter _router = createAppRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      appServices.repository.flushProgressQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "MyCourses",
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      locale: const Locale("ru"),
      supportedLocales: const [Locale("ru"), Locale("en")],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}
