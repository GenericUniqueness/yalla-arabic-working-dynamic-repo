import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_provider.dart';
import 'favourites_provider.dart';
import '../services/analytics_service.dart';
import '../services/daily_usage_service.dart';
import '../services/firestore_progress_service.dart';

class ProgressProvider extends ChangeNotifier with WidgetsBindingObserver {
  int _totalSeconds = 0;
  int _todaySeconds = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  String _lastStreakDate = '';
  String _lastSaveDate = '';
  Map<String, double> _lessonProgress = {};
  Map<int, int> _courseSeconds = {};
  int _dailyGoalMinutes = 15;
  String? _uid;
  String? _storedUid;
  bool _localOnlyUser = false;
  final Completer<void> _loadCompleter = Completer<void>();
  bool _disposed = false;
  int _authGeneration = 0;
  AudioProvider? _audioProvider;
  FavouritesProvider? _favouritesProvider;
  Timer? _listeningFlushTimer;
  DateTime? _listeningStartedAt;
  AudioQueueItem? _activeListeningItem;
  int _activeListeningSessionSeconds = 0;
  Future<void> _listeningWriteQueue = Future<void>.value();
  bool _cloudLoadComplete = false;
  bool _backupDirty = false;
  bool _eligibleBackupDirty = false;
  bool _backupSyncInFlight = false;
  bool _cloudSyncSuspended = false;
  bool _dailyGoalDirty = false;
  int _backupMutationVersion = 0;
  Completer<void>? _cloudOperationCompleter;

  static const _listeningFlushInterval = Duration(seconds: 30);

  // Cached SharedPreferences instance — avoids re-initialising on every call.
  SharedPreferences? _prefs;
  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static const Map<int, int> courseTotalSeconds = {
    1: 1599,
    2: 60972,
    3: 89332,
    4: 81243,
    5: 122838,
    6: 32000,
    7: 7458,
    8: 9056,
  };

  int get totalSeconds => _totalSeconds;
  int get todaySeconds => _todaySeconds;
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  int get dailyGoalMinutes => _dailyGoalMinutes;
  int get dailyGoalSeconds => _dailyGoalMinutes * 60;
  bool get goalReachedToday => _todaySeconds >= dailyGoalSeconds;
  bool get hasPendingCloudBackup =>
      _backupDirty || (_favouritesProvider?.hasPendingCloudSave ?? false);
  int getCourseSeconds(int courseId) => _courseSeconds[courseId] ?? 0;
  double getLessonProgress(String key) => _lessonProgress[key] ?? 0.0;

  double getCourseCompletionFraction(int courseId, List<String> lessonKeys) {
    if (lessonKeys.isEmpty) return 0.0;
    final total =
        lessonKeys.fold(0.0, (sum, k) => sum + (_lessonProgress[k] ?? 0.0));
    return (total / lessonKeys.length).clamp(0.0, 1.0);
  }

  ProgressProvider() {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  /// Called by ProxyProvider whenever auth state changes.
  void setUser(String? uid, {bool localOnly = false}) {
    if (uid == _uid && localOnly == _localOnlyUser) return;
    _authGeneration++;
    final generation = _authGeneration;
    _uid = uid;
    _localOnlyUser = localOnly;
    _cloudLoadComplete = false;
    _backupDirty = false;
    _eligibleBackupDirty = false;
    _dailyGoalDirty = false;
    _loadCompleter.future.then((_) async {
      await _favouritesProvider?.loaded;
      if (_disposed || generation != _authGeneration) return;
      if (localOnly) {
        notifyListeners();
        return;
      }
      if (uid == null) {
        await _wipeLocal();
        return;
      }
      if (uid != _storedUid) {
        await _wipeLocal();
        await _favouritesProvider?.resetForUserSwitch();
        _storedUid = uid;
        final prefs = await _getPrefs();
        await prefs.setString('active_uid', uid);
      }
      if (_disposed || generation != _authGeneration) return;
      await _loadCloudAndSyncEligible(uid, generation);
    });
  }

  void bindAudioProvider(AudioProvider audioProvider) {
    if (identical(_audioProvider, audioProvider)) return;
    _audioProvider?.removeListener(_handleAudioProviderChanged);
    _audioProvider = audioProvider;
    _audioProvider!.addListener(_handleAudioProviderChanged);
    _handleAudioProviderChanged();
  }

  void bindFavouritesProvider(FavouritesProvider favouritesProvider) {
    if (identical(_favouritesProvider, favouritesProvider)) return;
    _favouritesProvider = favouritesProvider;
    favouritesProvider.bindCombinedBackupDirtyCallback(_markBackupDirty);
    unawaited(favouritesProvider.markExistingDirtyForCombinedBackup());
  }

  void _handleAudioProviderChanged() {
    if (_disposed) return;
    final audio = _audioProvider;
    final item = audio?.currentQueueItem;
    final playbackContinues = audio != null &&
        item != null &&
        audio.isPlaying &&
        !audio.isPlaybackTerminal;
    final sameContext = _activeListeningItem != null && _samePlaybackItem(item);
    final now = DateTime.now();

    if (_activeListeningItem != null && (!playbackContinues || !sameContext)) {
      _finishListeningSession(now);
    }

    if (!playbackContinues) return;

    if (_activeListeningItem == null) {
      _activeListeningItem = item;
      _activeListeningSessionSeconds = 0;
    }

    if (audio.isPlaybackActive) {
      _resumeListeningClock(now);
    } else {
      _pauseListeningClock(now);
    }
  }

  bool _samePlaybackItem(AudioQueueItem? item) {
    final active = _activeListeningItem;
    return active != null &&
        item != null &&
        active.courseId == item.courseId &&
        active.lessonId == item.lessonId &&
        active.typeFolder == item.typeFolder;
  }

  void _resumeListeningClock(DateTime now) {
    if (_listeningStartedAt != null) return;
    _listeningStartedAt = now;
    _listeningFlushTimer?.cancel();
    _listeningFlushTimer = Timer.periodic(_listeningFlushInterval, (_) {
      _accountListeningElapsed(DateTime.now());
    });
  }

  void _pauseListeningClock(DateTime now) {
    _listeningFlushTimer?.cancel();
    _listeningFlushTimer = null;
    _accountListeningElapsed(now);
    _listeningStartedAt = null;
  }

  void _accountListeningElapsed(DateTime now) {
    final startedAt = _listeningStartedAt;
    final item = _activeListeningItem;
    if (startedAt == null || item == null) return;

    final seconds = now.difference(startedAt).inSeconds;
    if (seconds <= 0) return;

    _listeningStartedAt = startedAt.add(Duration(seconds: seconds));
    _activeListeningSessionSeconds += seconds;
    _enqueueListeningWrite(() {
      return addLearningTime(
        seconds,
        courseId: item.courseId,
      );
    });
  }

  void _finishListeningSession(DateTime now) {
    final item = _activeListeningItem;
    if (item == null) return;

    _pauseListeningClock(now);
    final sessionSeconds = _activeListeningSessionSeconds;
    _activeListeningItem = null;
    _activeListeningSessionSeconds = 0;

    if (sessionSeconds <= 0) return;
    _enqueueListeningWrite(() async {
      await _persistProgressSnapshot();
      if (sessionSeconds >= 10) {
        await AnalyticsService.logListeningSession(
          courseId: item.courseId,
          lessonId: item.lessonId,
          durationSeconds: sessionSeconds,
        );
      }
    });
  }

  void _enqueueListeningWrite(Future<void> Function() action) {
    _listeningWriteQueue =
        _listeningWriteQueue.then((_) => action()).catchError(
      (_) {
        // A failed local write must not prevent later playback time from
        // entering the serial queue.
      },
    );
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  bool _wasYesterday(String d) {
    try {
      final p = d.split('-');
      final date = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
      final y = DateTime.now().subtract(const Duration(days: 1));
      return date.year == y.year && date.month == y.month && date.day == y.day;
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    final prefs = await _getPrefs();
    _storedUid = prefs.getString('active_uid');
    _totalSeconds = prefs.getInt('total_seconds') ?? 0;
    _currentStreak = prefs.getInt('current_streak') ?? 0;
    _bestStreak = prefs.getInt('best_streak') ?? 0;
    _lastStreakDate = prefs.getString('last_streak_date') ?? '';
    _lastSaveDate = prefs.getString('last_save_date') ?? '';
    _dailyGoalMinutes = prefs.getInt('daily_goal_minutes') ?? 15;

    final today = _todayKey();
    if (_lastSaveDate == today) {
      _todaySeconds = prefs.getInt('today_seconds') ?? 0;
    } else {
      _todaySeconds = 0;
      if (_lastSaveDate.isNotEmpty && !_wasYesterday(_lastSaveDate)) {
        _currentStreak = 0;
        prefs.setInt('current_streak', 0);
      }
    }

    final keys = prefs.getStringList('lesson_progress_keys') ?? [];
    for (final k in keys) {
      final v = prefs.getDouble('lp_$k');
      if (v != null) _lessonProgress[k] = v;
    }
    final courseIds = prefs.getStringList('course_seconds_ids') ?? [];
    for (final idStr in courseIds) {
      final courseId = int.tryParse(idStr);
      if (courseId == null) continue;
      final v = prefs.getInt('course_seconds_$courseId') ?? 0;
      if (v > 0) _courseSeconds[courseId] = v;
    }

    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
    notifyListeners();
  }

  Future<void> _wipeLocal() async {
    _totalSeconds = 0;
    _todaySeconds = 0;
    _currentStreak = 0;
    _bestStreak = 0;
    _lastStreakDate = '';
    _lastSaveDate = '';
    _lessonProgress = {};
    _courseSeconds = {};
    _dailyGoalMinutes = 15;
    _backupMutationVersion = 0;
    _dailyGoalDirty = false;
    notifyListeners();

    final prefs = await _getPrefs();
    await _clearPrefs(prefs);
  }

  Future<void> suspendCloudSyncForAccountDeletion() async {
    _cloudSyncSuspended = true;
    final pendingOperation = _cloudOperationCompleter?.future;
    if (pendingOperation != null) {
      await pendingOperation;
    }
  }

  void resumeCloudSyncAfterAccountDeletionFailure() {
    _cloudSyncSuspended = false;
  }

  Future<void> _clearPrefs(SharedPreferences prefs) async {
    await prefs.remove('active_uid');
    await prefs.remove('total_seconds');
    await prefs.remove('today_seconds');
    await prefs.remove('current_streak');
    await prefs.remove('best_streak');
    await prefs.remove('last_streak_date');
    await prefs.remove('last_save_date');
    await prefs.remove('daily_goal_minutes');
    final keys = prefs.getStringList('lesson_progress_keys') ?? [];
    for (final k in keys) {
      await prefs.remove('lp_$k');
    }
    await prefs.remove('lesson_progress_keys');
    final courseIds = prefs.getStringList('course_seconds_ids') ?? [];
    for (final idStr in courseIds) {
      await prefs.remove('course_seconds_$idStr');
    }
    await prefs.remove('course_seconds_ids');
  }

  String _backupDirtyKey(String uid) => 'progress_backup_dirty_$uid';
  String _backupDirtyDateKey(String uid) => 'progress_backup_dirty_date_$uid';
  String _dailyGoalDirtyKey(String uid) => 'daily_goal_dirty_$uid';

  void _beginCloudOperation() {
    _backupSyncInFlight = true;
    _cloudOperationCompleter = Completer<void>();
  }

  void _endCloudOperation() {
    _backupSyncInFlight = false;
    final completer = _cloudOperationCompleter;
    _cloudOperationCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _markBackupDirty() async {
    final uid = _uid;
    if (uid == null || _localOnlyUser) return;
    _backupMutationVersion++;
    _backupDirty = true;
    final prefs = await _getPrefs();
    await prefs.setBool(_backupDirtyKey(uid), true);
    await prefs.setString(_backupDirtyDateKey(uid), _todayKey());
  }

  Future<void> _loadCloudAndSyncEligible(
    String uid,
    int generation,
  ) async {
    if (_backupSyncInFlight || _cloudSyncSuspended) return;
    _beginCloudOperation();
    try {
      final prefs = await _getPrefs();
      final progressWasDirty = prefs.getBool(_backupDirtyKey(uid)) == true;
      final wasDirty = progressWasDirty ||
          (_favouritesProvider?.hasPendingCloudSave ?? false);
      _dailyGoalDirty = prefs.getBool(_dailyGoalDirtyKey(uid)) == true;
      _backupDirty = wasDirty;
      if (!_cloudLoadComplete) {
        _eligibleBackupDirty = wasDirty;
      }

      Map<String, dynamic>? remote;
      try {
        remote = await FirestoreProgressService.load(uid);
      } catch (_) {
        return;
      }
      if (_disposed || generation != _authGeneration || uid != _uid) return;

      if (remote != null) {
        await _mergeRemoteProgress(
          remote,
          preserveDailyGoal: _dailyGoalDirty,
        );
        await _favouritesProvider?.mergeCloudData(
          remote,
          preserveLocalChanges:
              _favouritesProvider?.hasPendingCloudSave ?? false,
        );
      }
      _cloudLoadComplete = true;
      _storedUid = uid;
      await prefs.setString('active_uid', uid);
      notifyListeners();
    } finally {
      _endCloudOperation();
    }

    if (_eligibleBackupDirty) {
      await syncPendingCloudBackup();
    }
  }

  Future<void> _mergeRemoteProgress(
    Map<String, dynamic> remote, {
    required bool preserveDailyGoal,
  }) async {
    final prefs = await _getPrefs();

    final remoteTotal = (remote['totalSeconds'] as num?)?.toInt() ?? 0;
    if (remoteTotal > _totalSeconds) {
      _totalSeconds = remoteTotal;
      await prefs.setInt('total_seconds', _totalSeconds);
    }

    final today = _todayKey();
    final remoteLastSave = remote['lastSaveDate'] as String? ?? '';
    if (remoteLastSave == today) {
      _lastSaveDate = today;
      await prefs.setString('last_save_date', _lastSaveDate);
      final remoteTodaySeconds = (remote['todaySeconds'] as num?)?.toInt() ?? 0;
      if (remoteTodaySeconds > _todaySeconds) {
        _todaySeconds = remoteTodaySeconds;
        await prefs.setInt('today_seconds', _todaySeconds);
      }
    }

    final remoteStreak = (remote['currentStreak'] as num?)?.toInt() ?? 0;
    final remoteBest = (remote['bestStreak'] as num?)?.toInt() ?? 0;
    if (remoteStreak > _currentStreak) {
      _currentStreak = remoteStreak;
      _lastStreakDate = remote['lastStreakDate'] as String? ?? '';
      await prefs.setInt('current_streak', _currentStreak);
      await prefs.setString('last_streak_date', _lastStreakDate);
    }
    if (remoteBest > _bestStreak) {
      _bestStreak = remoteBest;
      await prefs.setInt('best_streak', _bestStreak);
    }

    final remoteLp = (remote['lessonProgress'] as Map<String, dynamic>?) ?? {};
    for (final entry in remoteLp.entries) {
      final remoteVal = (entry.value as num?)?.toDouble() ?? 0.0;
      if (remoteVal > (_lessonProgress[entry.key] ?? 0.0)) {
        _lessonProgress[entry.key] = remoteVal;
        await prefs.setDouble('lp_${entry.key}', remoteVal);
      }
    }
    if (remoteLp.isNotEmpty) {
      await prefs.setStringList(
          'lesson_progress_keys', _lessonProgress.keys.toList());
    }

    final remoteCourseMap =
        (remote['courseSeconds'] as Map<String, dynamic>?) ?? {};
    for (final entry in remoteCourseMap.entries) {
      final courseId = int.tryParse(entry.key);
      if (courseId == null) continue;
      final remoteVal = (entry.value as num?)?.toInt() ?? 0;
      if (remoteVal > (_courseSeconds[courseId] ?? 0)) {
        _courseSeconds[courseId] = remoteVal;
        await prefs.setInt('course_seconds_$courseId', remoteVal);
      }
    }
    await prefs.setStringList(
        'course_seconds_ids', _courseSeconds.keys.map((k) => '$k').toList());

    final remoteDailyGoal = (remote['dailyGoalMinutes'] as num?)?.toInt();
    if (!preserveDailyGoal &&
        remoteDailyGoal != null &&
        remoteDailyGoal != _dailyGoalMinutes) {
      _dailyGoalMinutes = remoteDailyGoal;
      await prefs.setInt('daily_goal_minutes', _dailyGoalMinutes);
    }

    await _persistProgressSnapshot();
  }

  Map<String, dynamic> _combinedCloudBackup() => {
        'totalSeconds': _totalSeconds,
        'todaySeconds': _todaySeconds,
        'currentStreak': _currentStreak,
        'bestStreak': _bestStreak,
        'lastStreakDate': _lastStreakDate,
        'lastSaveDate': _lastSaveDate,
        'dailyGoalMinutes': _dailyGoalMinutes,
        'lessonProgress': Map<String, dynamic>.from(_lessonProgress),
        'courseSeconds': {
          for (final id in _courseSeconds.keys) '$id': _courseSeconds[id] ?? 0
        },
        ...?_favouritesProvider?.cloudBackupFields,
      };

  Future<bool> syncPendingCloudBackup({bool forceCurrent = false}) async {
    final uid = _uid;
    if (_disposed ||
        _localOnlyUser ||
        uid == null ||
        _cloudSyncSuspended ||
        _backupSyncInFlight) {
      return false;
    }

    if (forceCurrent && _activeListeningItem != null) {
      _finishListeningSession(DateTime.now());
    }
    await _listeningWriteQueue;

    final prefs = await _getPrefs();
    final dirty = prefs.getBool(_backupDirtyKey(uid)) == true ||
        (_favouritesProvider?.hasPendingCloudSave ?? false);
    if (!dirty) {
      _backupDirty = false;
      _eligibleBackupDirty = false;
      return true;
    }
    if (!forceCurrent && !_eligibleBackupDirty) return true;

    if (!_cloudLoadComplete) {
      await _loadCloudAndSyncEligible(uid, _authGeneration);
      return !hasPendingCloudBackup;
    }

    _beginCloudOperation();
    final progressVersion = _backupMutationVersion;
    final favouritesVersion = _favouritesProvider?.cloudMutationVersion ?? 0;
    final data = _combinedCloudBackup();
    try {
      final saved = await FirestoreProgressService.save(uid, data);
      if (!saved || _disposed || uid != _uid) return false;

      _eligibleBackupDirty = false;
      final unchanged = progressVersion == _backupMutationVersion &&
          favouritesVersion == (_favouritesProvider?.cloudMutationVersion ?? 0);
      if (unchanged) {
        _backupDirty = false;
        await prefs.setBool(_backupDirtyKey(uid), false);
        await prefs.remove(_backupDirtyDateKey(uid));
        _dailyGoalDirty = false;
        await prefs.remove(_dailyGoalDirtyKey(uid));
        await _favouritesProvider?.markCombinedBackupSynced(favouritesVersion);
      }
      return true;
    } finally {
      _endCloudOperation();
    }
  }

  Future<void> addLearningTime(
    int seconds, {
    int courseId = 0,
  }) async {
    if (seconds <= 0) return;
    final today = _todayKey();
    if (_lastSaveDate != today) {
      if (_lastSaveDate.isNotEmpty && !_wasYesterday(_lastSaveDate)) {
        _currentStreak = 0;
      }
      _todaySeconds = 0;
      _lastSaveDate = today;
    }

    _totalSeconds += seconds;
    _todaySeconds += seconds;
    if (courseId > 0) {
      _courseSeconds[courseId] = (_courseSeconds[courseId] ?? 0) + seconds;
    }

    if (_todaySeconds >= dailyGoalSeconds && _lastStreakDate != today) {
      _lastStreakDate = today;
      _currentStreak++;
      if (_currentStreak > _bestStreak) _bestStreak = _currentStreak;
    }

    // Each 30-second playback checkpoint is durable locally. This does not
    // trigger Firestore; the combined cloud backup waits for a later eligible
    // app open/resume.
    await _persistProgressSnapshot();
    await DailyUsageService.addListeningSeconds(seconds);
    await _markBackupDirty();

    await _checkListeningMilestones();
    notifyListeners();
  }

  Future<void> _persistProgressSnapshot() async {
    final prefs = await _getPrefs();
    await prefs.setInt('total_seconds', _totalSeconds);
    await prefs.setInt('today_seconds', _todaySeconds);
    await prefs.setInt('current_streak', _currentStreak);
    await prefs.setInt('best_streak', _bestStreak);
    await prefs.setString('last_streak_date', _lastStreakDate);
    await prefs.setString('last_save_date', _lastSaveDate);
    if (_uid != null) await prefs.setString('active_uid', _uid!);
    for (final entry in _courseSeconds.entries) {
      await prefs.setInt('course_seconds_${entry.key}', entry.value);
    }
    await prefs.setStringList(
      'course_seconds_ids',
      _courseSeconds.keys.map((id) => '$id').toList(),
    );
  }

  Future<void> _checkListeningMilestones() async {
    final uid = _uid;
    if (uid == null || _localOnlyUser) return;
    const milestones = {
      10 * 60: '10m',
      60 * 60: '1h',
      5 * 60 * 60: '5h',
      20 * 60 * 60: '20h',
    };
    final prefs = await _getPrefs();
    for (final milestone in milestones.entries) {
      if (_totalSeconds < milestone.key) continue;
      final key = 'listening_milestone_${uid}_${milestone.value}';
      if (prefs.getBool(key) == true) continue;
      final logged =
          await AnalyticsService.logListeningMilestone(milestone.value);
      if (logged) await prefs.setBool(key, true);
    }
  }

  Future<void> setDailyGoalMinutes(int minutes) async {
    _dailyGoalMinutes = minutes;
    _dailyGoalDirty = true;
    final prefs = await _getPrefs();
    await prefs.setInt('daily_goal_minutes', minutes);
    final uid = _uid;
    if (uid != null && !_localOnlyUser) {
      await prefs.setBool(_dailyGoalDirtyKey(uid), true);
    }
    await _markBackupDirty();
    notifyListeners();
  }

  Future<void> updateLessonProgress(String key, double fraction) async {
    _lessonProgress[key] = fraction;
    final prefs = await _getPrefs();
    await prefs.setDouble('lp_$key', fraction);
    await prefs.setStringList(
        'lesson_progress_keys', _lessonProgress.keys.toList());
    await _markBackupDirty();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_retryEligibleBackupOnResume());
  }

  Future<void> _retryEligibleBackupOnResume() async {
    final uid = _uid;
    if (uid == null || _localOnlyUser || _cloudSyncSuspended) return;
    final prefs = await _getPrefs();
    final dirty = prefs.getBool(_backupDirtyKey(uid)) == true ||
        (_favouritesProvider?.hasPendingCloudSave ?? false);
    _backupDirty = dirty;
    final dirtyDate = prefs.getString(_backupDirtyDateKey(uid));
    if (dirty && dirtyDate != null && dirtyDate != _todayKey()) {
      _eligibleBackupDirty = true;
    }
    if (!_cloudLoadComplete) {
      await _loadCloudAndSyncEligible(uid, _authGeneration);
    } else if (_eligibleBackupDirty) {
      await syncPendingCloudBackup();
    }
  }

  @override
  void dispose() {
    _audioProvider?.removeListener(_handleAudioProviderChanged);
    _finishListeningSession(DateTime.now());
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
