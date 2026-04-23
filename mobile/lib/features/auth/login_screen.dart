import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../api_error_message.dart";
import "../../app_services.dart";
import "../../design_tokens.dart";
import "../../widgets/app_primary_button.dart";
import "../../widgets/app_text_field.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: "admin@example.com");
  final _pass = TextEditingController(text: "password123");
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Вход")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _email,
              label: "Электронная почта",
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpace.sm),
            AppTextField(
              controller: _pass,
              label: "Пароль",
              obscureText: true,
            ),
            const SizedBox(height: AppSpace.md),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            AppPrimaryButton(
              label: "Войти",
              loading: _loading,
              onPressed: () async {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      try {
                        final s = await appServices.api.login(_email.text.trim(), _pass.text);
                        await appServices.authStorage.saveSession(
                          accessToken: s.accessToken,
                          refreshToken: s.refreshToken,
                          role: s.role,
                          userId: s.userId,
                          email: s.email,
                          name: s.name,
                        );
                        appServices.currentSession.value = s;
                        if (mounted) context.go("/catalog");
                      } catch (e) {
                        setState(
                          () => _error = readableApiError(
                            e,
                            authFailure: "Неверный логин или пароль",
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
            ),
            TextButton(
              onPressed: () => context.go("/register"),
              child: const Text("Регистрация"),
            ),
          ],
        ),
      ),
    );
  }
}
