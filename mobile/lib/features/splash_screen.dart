import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../app_services.dart";
import "../design_tokens.dart";
import "../models.dart";

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final stored = await appServices.authStorage.readSession();
    if (!mounted) return;
    if (stored == null) {
      context.go("/login");
      return;
    }
    appServices.api.setAccessToken(stored.accessToken);
    try {
      final me = await appServices.api.fetchMe();
      final session = Session(
        accessToken: stored.accessToken,
        refreshToken: stored.refreshToken,
        role: me["role"] as String? ?? stored.role,
        userId: me["id"] as String? ?? stored.userId,
        email: me["email"] as String? ?? stored.email,
        name: me["name"] as String? ?? stored.name,
      );
      appServices.currentSession.value = session;
      if (mounted) context.go("/catalog");
    } catch (_) {
      try {
        final session = await appServices.api.refresh(stored.refreshToken);
        await appServices.authStorage.saveSession(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          role: session.role,
          userId: session.userId,
          email: session.email,
          name: session.name,
        );
        appServices.currentSession.value = session;
        if (mounted) context.go("/catalog");
      } catch (_) {
        await appServices.authStorage.clear();
        if (mounted) context.go("/login");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sky,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  "assets/branding/app_icon.png",
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
