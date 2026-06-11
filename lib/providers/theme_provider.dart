import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  final String name;
  final Color bg;
  final Color card;
  final Color playerBar;
  final Color accent;
  final Color textPrimary;
  final Color textSub;
  const AppTheme({
    required this.name,
    required this.bg,
    required this.card,
    required this.playerBar,
    required this.accent,
    this.textPrimary = Colors.white,
    // NOTE: textSub defaults to Colors.white54 which is appropriate for dark
    // themes only. Light themes (Cloud, Parchment) MUST explicitly override
    // both textPrimary and textSub — see examples in ThemeProvider.themes below.
    // Any new dark theme can rely on this default; any new light theme must not.
    this.textSub = Colors.white54,
  });
}

class ThemeProvider extends ChangeNotifier {
  static const themes = [
    // ── Dark themes ──────────────────────────────────────────────────────────
    AppTheme(
      name: 'Maroon',
      bg: Color(0xFF1C0A14), card: Color(0xFF2E1120),
      playerBar: Color(0xFF100608), accent: Color(0xFFE8A040),
    ),
    AppTheme(
      name: 'Midnight',
      bg: Color(0xFF080D1A), card: Color(0xFF0F1830),
      playerBar: Color(0xFF05090F), accent: Color(0xFF6B8EE8),
    ),
    AppTheme(
      name: 'Forest',
      bg: Color(0xFF0A1E10), card: Color(0xFF142918),
      playerBar: Color(0xFF071209), accent: Color(0xFF5EBF62),
    ),
    AppTheme(
      name: 'Charcoal',
      bg: Color(0xFF1A1A1A), card: Color(0xFF2C2C2E),
      playerBar: Color(0xFF111111), accent: Color(0xFFFF9500),
    ),
    // ── Light themes ─────────────────────────────────────────────────────────
    AppTheme(
      name: 'Cloud',
      bg: Color(0xFFF0F4F8), card: Color(0xFFFFFFFF),
      playerBar: Color(0xFFDDE8F4), accent: Color(0xFF2E78C8),
      textPrimary: Color(0xFF1A1A2E), textSub: Color(0xFF666680),
    ),
    AppTheme(
      name: 'Ember',
      bg: Color(0xFF1A0C08), card: Color(0xFF2C1812),
      playerBar: Color(0xFF110805), accent: Color(0xFFFF6040),
    ),
    AppTheme(
      name: 'Ocean',
      bg: Color(0xFF061520), card: Color(0xFF0C2535),
      playerBar: Color(0xFF040D18), accent: Color(0xFF00D4E8),
    ),
    AppTheme(
      name: 'Parchment',
      bg: Color(0xFFFDF6EB), card: Color(0xFFFFFFFF),
      playerBar: Color(0xFFF2E6CE), accent: Color(0xFFB85C30),
      textPrimary: Color(0xFF2A1A0A), textSub: Color(0xFF7A5A40),
    ),
  ];

  int _index = 3; // default Charcoal
  AppTheme get current => themes[_index];
  int get index => _index;

  ThemeProvider() { _load(); }

  Future<void> setTheme(int i) async {
    _index = i.clamp(0, themes.length - 1);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_index', _index);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _index = (prefs.getInt('theme_index') ?? 3).clamp(0, themes.length - 1);
    notifyListeners();
  }
}
