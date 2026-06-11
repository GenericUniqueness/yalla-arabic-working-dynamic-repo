import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'daily_usage_service.dart';

class AppUsageTimeService extends ChangeNotifier with WidgetsBindingObserver {
  static const _flushInterval = Duration(seconds: 30);

  String? _uid;
  bool _localOnly = false;
  int _totalSeconds = 0;
  int _todaySeconds = 0;
  String _todayDate = '';
  DateTime? _foregroundStartedAt;
  Timer? _flushTimer;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _flushQueue = Future<void>.value();

  AppUsageTimeService() {
    WidgetsBinding.instance.addObserver(this);
  }

  int get totalSeconds => _totalSeconds;
  int get todaySeconds => _todaySeconds;

  void setUser(String? uid, {bool localOnly = false}) {
    if (uid == _uid && localOnly == _localOnly) return;
    _generation++;
    unawaited(_switchUser(uid, localOnly, _generation));
  }

  Future<void> _switchUser(
    String? uid,
    bool localOnly,
    int generation,
  ) async {
    _stopTimer();
    await _flushElapsed(endSession: true);
    if (_disposed || generation != _generation) return;

    _uid = uid;
    _localOnly = localOnly;
    _totalSeconds = 0;
    _todaySeconds = 0;
    _todayDate = DailyUsageService.dateKey();
    _foregroundStartedAt = null;

    await DailyUsageService.setActiveUser(uid, localOnly: localOnly);
    if (_disposed || generation != _generation) return;

    if (uid != null) {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed || generation != _generation) return;
      _totalSeconds = prefs.getInt(_totalKey(uid)) ?? 0;
      final storedDate = prefs.getString(_todayDateKey(uid));
      if (storedDate == _todayDate) {
        _todaySeconds = prefs.getInt(_todaySecondsKey(uid)) ?? 0;
      } else {
        await prefs.setString(_todayDateKey(uid), _todayDate);
        await prefs.setInt(_todaySecondsKey(uid), 0);
      }
      if (!_localOnly) {
        unawaited(DailyUsageService.syncPreviousDays(uid));
      }
      _resumeTrackingIfForeground();
    }
    notifyListeners();
  }

  String _totalKey(String uid) => 'app_usage_total_seconds_$uid';
  String _todayDateKey(String uid) => 'app_usage_today_date_$uid';
  String _todaySecondsKey(String uid) => 'app_usage_today_seconds_$uid';

  void _resumeTrackingIfForeground() {
    if (_uid == null || _foregroundStartedAt != null) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) {
      _foregroundStartedAt = DateTime.now();
      _flushTimer = Timer.periodic(_flushInterval, (_) {
        unawaited(_flushElapsed());
      });
    }
  }

  void _stopTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  Future<void> _flushElapsed({bool endSession = false}) async {
    _flushQueue = _flushQueue
        .then((_) => _flushElapsedNow(endSession: endSession))
        .catchError((_) {});
    await _flushQueue;
  }

  Future<void> _flushElapsedNow({bool endSession = false}) async {
    final uid = _uid;
    final startedAt = _foregroundStartedAt;
    if (uid == null || startedAt == null) return;

    final now = DateTime.now();
    _foregroundStartedAt = endSession ? null : now;
    final seconds = now.difference(startedAt).inSeconds;
    if (seconds <= 0) return;

    final currentDate = DailyUsageService.dateKey(now);
    if (_todayDate != currentDate) {
      _todayDate = currentDate;
      _todaySeconds = 0;
    }
    _totalSeconds += seconds;
    _todaySeconds += seconds;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalKey(uid), _totalSeconds);
    await prefs.setString(_todayDateKey(uid), _todayDate);
    await prefs.setInt(_todaySecondsKey(uid), _todaySeconds);
    await DailyUsageService.addAppForegroundSeconds(seconds);

    if (!_disposed) notifyListeners();
  }

  Future<void> prepareForAccountDeletion(String uid) async {
    _generation++;
    _stopTimer();
    _foregroundStartedAt = null;
    await _flushQueue;
    if (_uid != uid && _uid != null) return;

    _uid = null;
    _localOnly = false;
    _totalSeconds = 0;
    _todaySeconds = 0;
    _todayDate = DailyUsageService.dateKey();
    await DailyUsageService.setActiveUser(null, localOnly: false);
    if (!_disposed) notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeTrackingIfForeground();
      final uid = _uid;
      if (uid != null && !_localOnly) {
        unawaited(DailyUsageService.syncPreviousDays(uid));
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopTimer();
      unawaited(_flushElapsed(endSession: true));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_flushElapsed(endSession: true));
    super.dispose();
  }
}
