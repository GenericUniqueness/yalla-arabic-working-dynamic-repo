import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_language.dart';

class SettingsProvider extends ChangeNotifier {
  static const _appLanguageKey = 'app_language';

  double _englishFontSize = 16.0;
  double _arabicFontSize = 13.0;
  AppLanguage _appLanguage = AppLanguage.english;
  bool _autoClosePopup = false;
  int _autoCloseSeconds = 5;
  bool _neverSleep = true;
  bool _showArabicTranslation = true;
  bool _dailyNotification = true;
  double _pronunciationSpeed = 1.0;
  bool _autoPlay = true;
  bool _pauseOnWordTap = true;

  // Cached SharedPreferences instance — avoids creating a new Future on every setter.
  SharedPreferences? _prefs;
  Future<void> _ensurePrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  double get englishFontSize => _englishFontSize;
  double get arabicFontSize => _arabicFontSize;
  AppLanguage get appLanguage => _appLanguage;
  bool get autoClosePopup => _autoClosePopup;
  int get autoCloseSeconds => _autoCloseSeconds;
  bool get neverSleep => _neverSleep;
  bool get showArabicTranslation => _showArabicTranslation;
  bool get dailyNotification => _dailyNotification;
  double get pronunciationSpeed => _pronunciationSpeed;
  bool get autoPlay => _autoPlay;
  bool get pauseOnWordTap => _pauseOnWordTap;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    await _ensurePrefs();
    final prefs = _prefs!;
    _englishFontSize = prefs.getDouble('english_font_size') ?? 16.0;
    _arabicFontSize = prefs.getDouble('arabic_font_size') ?? 13.0;
    _appLanguage = appLanguageFromStorage(prefs.getString(_appLanguageKey));
    _autoClosePopup = prefs.getBool('auto_close_popup') ?? false;
    _autoCloseSeconds = prefs.getInt('auto_close_seconds') ?? 5;
    _neverSleep = prefs.getBool('never_sleep') ?? true;
    _showArabicTranslation = prefs.getBool('show_arabic_translation') ?? true;
    _dailyNotification = prefs.getBool('daily_notification') ?? true;
    _pronunciationSpeed = prefs.getDouble('pronunciation_speed') ?? 1.0;
    _autoPlay = prefs.getBool('auto_play') ?? true;
    _pauseOnWordTap = prefs.getBool('pause_on_word_tap') ?? true;
    notifyListeners();
  }

  Future<void> setEnglishFontSize(double v) async {
    _englishFontSize = v;
    await _ensurePrefs();
    _prefs!.setDouble('english_font_size', v);
    notifyListeners();
  }

  Future<void> setArabicFontSize(double v) async {
    _arabicFontSize = v;
    await _ensurePrefs();
    _prefs!.setDouble('arabic_font_size', v);
    notifyListeners();
  }

  Future<void> setAppLanguage(AppLanguage language) async {
    if (_appLanguage == language) return;
    _appLanguage = language;
    await _ensurePrefs();
    await _prefs!.setString(_appLanguageKey, language.storageValue);
    notifyListeners();
  }

  Future<void> setAutoClosePopup(bool v) async {
    _autoClosePopup = v;
    await _ensurePrefs();
    _prefs!.setBool('auto_close_popup', v);
    notifyListeners();
  }

  Future<void> setAutoCloseSeconds(int v) async {
    _autoCloseSeconds = v;
    await _ensurePrefs();
    _prefs!.setInt('auto_close_seconds', v);
    notifyListeners();
  }

  Future<void> setNeverSleep(bool v) async {
    _neverSleep = v;
    await _ensurePrefs();
    _prefs!.setBool('never_sleep', v);
    notifyListeners();
  }

  Future<void> setShowArabicTranslation(bool v) async {
    _showArabicTranslation = v;
    await _ensurePrefs();
    _prefs!.setBool('show_arabic_translation', v);
    notifyListeners();
  }

  Future<void> setDailyNotification(bool v) async {
    _dailyNotification = v;
    await _ensurePrefs();
    _prefs!.setBool('daily_notification', v);
    notifyListeners();
  }

  Future<void> setPronunciationSpeed(double v) async {
    _pronunciationSpeed = v.clamp(0.5, 1.0);
    await _ensurePrefs();
    _prefs!.setDouble('pronunciation_speed', _pronunciationSpeed);
    notifyListeners();
  }

  Future<void> setAutoPlay(bool v) async {
    _autoPlay = v;
    await _ensurePrefs();
    _prefs!.setBool('auto_play', v);
    notifyListeners();
  }

  Future<void> setPauseOnWordTap(bool v) async {
    _pauseOnWordTap = v;
    await _ensurePrefs();
    _prefs!.setBool('pause_on_word_tap', v);
    notifyListeners();
  }
}
