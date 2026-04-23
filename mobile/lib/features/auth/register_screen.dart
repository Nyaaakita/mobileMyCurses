import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../../api_error_message.dart";
import "../../app_services.dart";
import "../../design_tokens.dart";
import "../../widgets/app_primary_button.dart";
import "../../widgets/app_text_field.dart";

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Регистрация")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: _firstName, label: "Имя"),
            const SizedBox(height: AppSpace.sm),
            AppTextField(controller: _lastName, label: "Фамилия"),
            const SizedBox(height: AppSpace.sm),
            AppTextField(
              controller: _email,
              label: "Электронная почта",
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpace.sm),
            AppTextField(
              controller: _pass,
              label: "Пароль (минимум 8)",
              obscureText: true,
            ),
            const SizedBox(height: AppSpace.md),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            AppPrimaryButton(
              label: "Создать аккаунт",
              loading: _loading,
              onPressed: () async {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      try {
                        final first = _firstName.text.trim();
                        final last = _lastName.text.trim();
                        if (first.length < 2 || last.length < 2) {
                          setState(() {
                            _error = "Укажите имя и фамилию (минимум 2 символа)";
                            _loading = false;
                          });
                          return;
                        }
                        final s = await appServices.api.register(
                          _email.text.trim(),
                          _pass.text,
                          "$first $last",
                        );
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
                            authFailure: "Не удалось зарегистрироваться (проверьте данные)",
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
            ),
            TextButton(onPressed: () => context.go("/login"), child: const Text("Уже есть аккаунт")),
          ],
        ),
      ),
    );
  }
}
