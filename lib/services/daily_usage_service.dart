import 'dart:async';
import 'dart:convert';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';
import 'firestore_progress_service.dart';

class DailyUsageSummary {
  final String date;
  final int appSeconds;
  final int listeningSeconds;
  final int lessonOpenCount;
  final int lessonCompleteCount;
  final int reviewQuizStartedCount;
  final int reviewQuizCompletedCount;
  final int grammarOpenedCount;
  final int grammarCompletedCount;
  final int savedWordAddCount;
  final int favoriteLessonAddCount;
  final bool synced;

  const DailyUsageSummary({
    required this.date,
    this.appSeconds = 0,
    this.listeningSeconds = 0,
    this.lessonOpenCount = 0,
    this.lessonCompleteCount = 0,
    this.reviewQuizStartedCount = 0,
    this.reviewQuizCompletedCount = 0,
    this.grammarOpenedCount = 0,
    this.grammarCompletedCount = 0,
    this.savedWordAddCount = 0,
    this.favoriteLessonAddCount = 0,
    this.synced = false,
  });

  DailyUsageSummary copyWith({
    int? appSeconds,
    int? listeningSeconds,
    int? lessonOpenCount,
    int? lessonCompleteCount,
    int? reviewQuizStartedCount,
    int? reviewQuizCompletedCount,
    int? grammarOpenedCount,
    int? grammarCompletedCount,
    int? savedWordAddCount,
    int? favoriteLessonAddCount,
    bool? synced,
  }) {
    return DailyUsageSummary(
      date: date,
      appSeconds: appSeconds ?? this.appSeconds,
      listeningSeconds: listeningSeconds ?? this.listeningSeconds,
      lessonOpenCount: lessonOpenCount ?? this.lessonOpenCount,
      lessonCompleteCount: lessonCompleteCount ?? this.lessonCompleteCount,
      reviewQuizStartedCount:
          reviewQuizStartedCount ?? this.reviewQuizStartedCount,
      reviewQuizCompletedCount:
          reviewQuizCompletedCount ?? this.reviewQuizCompletedCount,
      grammarOpenedCount: grammarOpenedCount ?? this.grammarOpenedCount,
      grammarCompletedCount:
          grammarCompletedCount ?? this.grammarCompletedCount,
      savedWordAddCount: savedWordAddCount ?? this.savedWordAddCount,
      favoriteLessonAddCount:
          favoriteLessonAddCount ?? this.favoriteLessonAddCount,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'appSeconds': appSeconds,
        'listeningSeconds': listeningSeconds,
        'lessonOpenCount': lessonOpenCount,
        'lessonCompleteCount': lessonCompleteCount,
        'reviewQuizStartedCount': reviewQuizStartedCount,
        'reviewQuizCompletedCount': reviewQuizCompletedCount,
        'grammarOpenedCount': grammarOpenedCount,
        'grammarCompletedCount': grammarCompletedCount,
        'savedWordAddCount': savedWordAddCount,
        'favoriteLessonAddCount': favoriteLessonAddCount,
        'synced': synced,
      };

  Map<String, dynamic> toFirestore({String? appVersion}) => {
        'date': date,
        'appSeconds': appSeconds,
        'listeningSeconds': listeningSeconds,
        'lessonOpenCount': lessonOpenCount,
        'lessonCompleteCount': lessonCompleteCount,
        'reviewQuizStartedCount': reviewQuizStartedCount,
        'reviewQuizCompletedCount': reviewQuizCompletedCount,
        'grammarOpenedCount': grammarOpenedCount,
        'grammarCompletedCount': grammarCompletedCount,
        'savedWordAddCount': savedWordAddCount,
        'favoriteLessonAddCount': favoriteLessonAddCount,
        if (appVersion != null) 'appVersion': appVersion,
        'schemaVersion': 1,
      };

  factory DailyUsageSummary.fromJson(
    Map<String, dynamic> json, {
    required String fallbackDate,
  }) {
    int readInt(String key) => (json[key] as num?)?.toInt() ?? 0;

    return DailyUsageSummary(
      date: json['date']?.toString() ?? fallbackDate,
      appSeconds: readInt('appSeconds'),
      listeningSeconds: readInt('listeningSeconds'),
      lessonOpenCount: readInt('lessonOpenCount'),
      lessonCompleteCount: readInt('lessonCompleteCount'),
      reviewQuizStartedCount: readInt('reviewQuizStartedCount'),
      reviewQuizCompletedCount: readInt('reviewQuizCompletedCount'),
      grammarOpenedCount: readInt('grammarOpenedCount'),
      grammarCompletedCount: readInt('grammarCompletedCount'),
      savedWordAddCount: readInt('savedWordAddCount'),
      favoriteLessonAddCount: readInt('favoriteLessonAddCount'),
      synced: json['synced'] == true,
    );
  }
}

class DailyUsageService {
  const DailyUsageService._();

  static String? _activeScope;
  static bool _localOnly = false;
  static Future<void> _queue = Future<void>.value();
  static String? _cachedAppVersion;
  static final Map<String, Future<void>> _syncsInFlight = {};
  static final Set<String> _suspendedSyncScopes = {};

  static Future<T> _serialise<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static Future<void> setActiveUser(
    String? uid, {
    required bool localOnly,
  }) async {
    await _serialise(() async {
      _activeScope = uid;
      _localOnly = localOnly;
    });
  }

  static String dateKey([DateTime? value]) {
    final date = value ?? DateTime.now();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _datesKey(String scope) => 'daily_usage_dates_$scope';
  static String _dayKey(String scope, String date) =>
      'daily_usage_${scope}_$date';
  static String _completedLessonsKey(String scope, String date) =>
      'daily_usage_completed_lessons_${scope}_$date';

  static Future<DailyUsageSummary> _loadDay(
    SharedPreferences prefs,
    String scope,
    String date,
  ) async {
    final raw = prefs.getString(_dayKey(scope, date));
    if (raw == null) return DailyUsageSummary(date: date);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return DailyUsageSummary.fromJson(
          Map<String, dynamic>.from(decoded),
          fallbackDate: date,
        );
      }
    } catch (_) {}
    return DailyUsageSummary(date: date);
  }

  static Future<void> _saveDay(
    SharedPreferences prefs,
    String scope,
    DailyUsageSummary summary,
  ) async {
    await prefs.setString(
      _dayKey(scope, summary.date),
      jsonEncode(summary.toJson()),
    );
    final dates = (prefs.getStringList(_datesKey(scope)) ?? []).toSet();
    dates.add(summary.date);
    final sorted = dates.toList()..sort();
    await prefs.setStringList(_datesKey(scope), sorted);
  }

  static Future<void> _updateToday(
    DailyUsageSummary Function(DailyUsageSummary current) update,
  ) {
    return _serialise(() async {
      final scope = _activeScope;
      if (scope == null) return;
      final prefs = await SharedPreferences.getInstance();
      final date = dateKey();
      final current = await _loadDay(prefs, scope, date);
      await _saveDay(prefs, scope, update(current).copyWith(synced: false));
    });
  }

  static Future<void> addAppForegroundSeconds(int seconds) {
    if (seconds <= 0) return Future<void>.value();
    return _updateToday(
      (current) => current.copyWith(appSeconds: current.appSeconds + seconds),
    );
  }

  static Future<void> addListeningSeconds(int seconds) {
    if (seconds <= 0) return Future<void>.value();
    return _updateToday(
      (current) => current.copyWith(
        listeningSeconds: current.listeningSeconds + seconds,
      ),
    );
  }

  static Future<void> recordLessonOpened() {
    return _updateToday(
      (current) => current.copyWith(
        lessonOpenCount: current.lessonOpenCount + 1,
      ),
    );
  }

  static Future<bool> recordLessonCompleted({
    required int courseId,
    required int lessonId,
  }) {
    return _serialise(() async {
      final scope = _activeScope;
      if (scope == null) return false;
      final prefs = await SharedPreferences.getInstance();
      final date = dateKey();
      final key = '${courseId}_$lessonId';
      final completed =
          (prefs.getStringList(_completedLessonsKey(scope, date)) ?? [])
              .toSet();
      if (!completed.add(key)) return false;

      await prefs.setStringList(
        _completedLessonsKey(scope, date),
        completed.toList(),
      );
      final current = await _loadDay(prefs, scope, date);
      await _saveDay(
        prefs,
        scope,
        current.copyWith(
          lessonCompleteCount: current.lessonCompleteCount + 1,
          synced: false,
        ),
      );
      return true;
    });
  }

  static Future<void> recordReviewQuizStarted() {
    return _updateToday(
      (current) => current.copyWith(
        reviewQuizStartedCount: current.reviewQuizStartedCount + 1,
      ),
    );
  }

  static Future<void> recordReviewQuizCompleted() {
    return _updateToday(
      (current) => current.copyWith(
        reviewQuizCompletedCount: current.reviewQuizCompletedCount + 1,
      ),
    );
  }

  static Future<void> recordGrammarOpened() {
    return _updateToday(
      (current) => current.copyWith(
        grammarOpenedCount: current.grammarOpenedCount + 1,
      ),
    );
  }

  static Future<void> recordGrammarCompleted() {
    return _updateToday(
      (current) => current.copyWith(
        grammarCompletedCount: current.grammarCompletedCount + 1,
      ),
    );
  }

  static Future<void> recordSavedWordAdded() {
    return _updateToday(
      (current) => current.copyWith(
        savedWordAddCount: current.savedWordAddCount + 1,
      ),
    );
  }

  static Future<void> recordFavoriteLessonAdded() {
    return _updateToday(
      (current) => current.copyWith(
        favoriteLessonAddCount: current.favoriteLessonAddCount + 1,
      ),
    );
  }

  static Future<String?> _appVersion() async {
    if (_cachedAppVersion != null) return _cachedAppVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedAppVersion = '${info.version}+${info.buildNumber}';
      return _cachedAppVersion;
    } catch (_) {
      return null;
    }
  }

  static Future<void> syncPreviousDays(String uid) async {
    if (_localOnly ||
        uid != _activeScope ||
        _suspendedSyncScopes.contains(uid)) {
      return;
    }

    final existing = _syncsInFlight[uid];
    if (existing != null) return existing;

    late final Future<void> sync;
    sync = _syncPreviousDays(uid).whenComplete(() {
      if (identical(_syncsInFlight[uid], sync)) {
        _syncsInFlight.remove(uid);
      }
    });
    _syncsInFlight[uid] = sync;
    return sync;
  }

  static Future<void> suspendCloudSyncForAccountDeletion(String uid) async {
    _suspendedSyncScopes.add(uid);
    final inFlight = _syncsInFlight[uid];
    if (inFlight == null) return;
    try {
      await inFlight;
    } catch (_) {}
  }

  static void resumeCloudSyncAfterAccountDeletionFailure(String uid) {
    _suspendedSyncScopes.remove(uid);
  }

  static Future<void> _syncPreviousDays(String uid) async {
    if (_suspendedSyncScopes.contains(uid)) return;
    final summaries = await _serialise(() async {
      final prefs = await SharedPreferences.getInstance();
      final dates = prefs.getStringList(_datesKey(uid)) ?? const [];
      final today = dateKey();
      final pending = <DailyUsageSummary>[];
      for (final date in dates) {
        if (date == today) continue;
        final summary = await _loadDay(prefs, uid, date);
        if (!summary.synced) pending.add(summary);
      }
      return pending;
    });

    final appVersion = await _appVersion();
    for (final summary in summaries) {
      if (uid != _activeScope ||
          _localOnly ||
          _suspendedSyncScopes.contains(uid)) {
        return;
      }
      final firestoreSaved = await FirestoreProgressService.saveUsageDay(
        uid,
        summary.date,
        summary.toFirestore(appVersion: appVersion),
      );
      if (!firestoreSaved) continue;

      await _serialise(() async {
        if (uid != _activeScope) return;
        final prefs = await SharedPreferences.getInstance();
        final latest = await _loadDay(prefs, uid, summary.date);
        await _saveDay(prefs, uid, latest.copyWith(synced: true));
      });

      await AnalyticsService.logDailySummary(
        appSeconds: summary.appSeconds,
        listeningSeconds: summary.listeningSeconds,
        lessonOpenCount: summary.lessonOpenCount,
        lessonCompleteCount: summary.lessonCompleteCount,
        reviewQuizStartedCount: summary.reviewQuizStartedCount,
        reviewQuizCompletedCount: summary.reviewQuizCompletedCount,
        grammarOpenedCount: summary.grammarOpenedCount,
        grammarCompletedCount: summary.grammarCompletedCount,
        savedWordAddCount: summary.savedWordAddCount,
        favoriteLessonAddCount: summary.favoriteLessonAddCount,
      );
    }
  }
}
