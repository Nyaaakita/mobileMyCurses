import "package:flutter/material.dart";

/// Брендовые цвета: синий, голубой, белый. Красный — только для удаления / ошибок (через [ColorScheme.error]).
class AppColors {
  AppColors._();

  /// Приглушённый синий (меньше насыщенности, комфортнее для глаз).
  static const Color primaryBlue = Color(0xFF3D6D9A);
  static const Color sky = Color(0xFFF2F7FA);
  static const Color skyStrong = Color(0xFFD9E6EF);
  static const Color accentBlue = Color(0xFF5C8AAB);
  static const Color textOnLight = Color(0xFF2A4A62);
}

class AppRadius {
  AppRadius._();
  static const double md = 12;
  static const double lg = 16;
}

class AppSpace {
  AppSpace._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
}

class AppDurations {
  AppDurations._();
  static const Duration short = Duration(milliseconds: 180);
}
