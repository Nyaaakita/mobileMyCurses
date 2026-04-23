import "package:flutter/material.dart";

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    /// Красная кнопка опасного действия (удаление).
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: destructive ? scheme.onError : scheme.onPrimary,
            ),
          )
        : Text(label);
    final style = destructive
        ? FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
            disabledBackgroundColor: scheme.error.withValues(alpha: 0.35),
            disabledForegroundColor: scheme.onError.withValues(alpha: 0.8),
          )
        : null;
    if (icon != null) {
      return FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: style,
        icon: Icon(icon),
        label: child,
      );
    }
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: child,
    );
  }
}
