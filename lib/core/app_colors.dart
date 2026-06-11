import 'package:flutter/material.dart';

abstract final class AppColors {
  // Semantic colors — theme-safe
  static const Color error = Color(0xFFCF3030);
  static const Color warning = Color(0xFFD97706);
  static const Color success = Color(0xFF16A34A);

  // CEFR badge colors — single source of truth
  static const Map<String, Color> cefr = {
    'A0': Color(0xFF4CAF50),
    'A1': Color(0xFF4CAF50),
    'A1-A2': Color(0xFF8BC34A),
    'A2': Color(0xFF8BC34A),
    'A2-B1': Color(0xFFCDDC39),
    'B1': Color(0xFFFF9800),
    'B1-B2': Color(0xFFFF9800),
    'B2': Color(0xFFFF5722),
    'B2-C1': Color(0xFFFF5722),
    'C1': Color(0xFF9C27B0),
    'C2': Color(0xFFE91E63),
  };

  static Color cefrColor(String? level) =>
      cefr[level] ?? Colors.grey;
}

abstract final class AppRadius {
  static const double chip = 999;
  static const double button = 16;
  static const double card = 16;
  static const double inner = 12;
  static const double badge = 6;
}
