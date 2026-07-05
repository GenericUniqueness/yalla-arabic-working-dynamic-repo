import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/course.dart';
import '../../models/sentence.dart';
import '../../providers/audio_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/favourites_provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/download_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/daily_usage_service.dart';
import 'lesson_coach_tour.dart';
import '../../services/content_source_config.dart';
import '../../services/word_definition_service.dart';
import 'word_definition_overlay.dart';

class PlayerScreen extends StatefulWidget {
  final Lesson lesson;
  final LessonType? initialType;
  const PlayerScreen({super.key, required this.lesson, this.initialType});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

enum _RepeatCount { once, three, five, infinite }

class _RepeatQueueItem {
  final int index;
  final SentenceData sentence;

  const _RepeatQueueItem({required this.index, required this.sentence});
}

class _PlayerScreenState extends State<PlayerScreen> {
  late LessonType _selectedType;
  final ScrollController _scrollController = ScrollController();

  // Cached provider references — captured once in initState to avoid
  // context.read() races inside Timer callbacks and dispose().
  late final AudioProvider _audioProvider;
  late final SettingsProvider _settingsProvider;
  late final ProgressProvider _progressProvider;

  // Auto-scroll state
  final Map<int, GlobalKey> _sentenceKeys = {};
  bool _userHasScrolled = false;
  bool _isProgrammaticScroll = false;
  Timer? _resumeScrollTimer;
  int _lastScrolledToIndex = -1;

  // Sleep timer
  static const _sleepOptions = [0, 15, 30, 45, 60];
  int _sleepIndex = 0;
  Timer? _sleepTimer;

  bool _isOfflineUncached = false;
  bool _showingLessonTips = false;

  // Queue sync
  int _lastKnownQueueIndex = -1;

  Timer? _wakelockTracker;
  final Set<String> _trackedLessonOpens = {};
  bool _lessonCompletionRequested = false;
  bool _temporaryArabicVocabularyReady = false;

  // Temporary repeat/shadowing mode
  final List<_RepeatQueueItem> _repeatQueue = [];
  Timer? _repeatTimer;
  Timer? _repeatDelayTimer;
  VoidCallback? _repeatOverlayRefresh;
  bool _repeatModeOpen = false;
  bool _repeatKeepQueueAfterClose = false;
  bool _repeatWasPlaying = false;
  Duration _repeatRestorePosition = Duration.zero;
  double _repeatRestoreSpeed = 1.0;
  int _repeatIndex = 0;
  int _repeatCompletedForCurrent = 0;
  _RepeatCount _repeatCount = _RepeatCount.three;
  double _repeatSpeed = 1.0;
  int _repeatDelaySeconds = 1;
  bool _handlingBoundary = false;
  bool _repeatIsPlaying = false;

  static const _tabOrder = {
    LessonType.mainStory: 0,
    LessonType.pov: 1,
    LessonType.miniStory: 2,
    LessonType.conversation: 3,
    LessonType.commentary: 4,
    LessonType.vocabulary: 5,
  };

  LessonType _firstDisplayType() {
    return ([...widget.lesson.availableTypes]
          ..sort((a, b) => (_tabOrder[a] ?? 99).compareTo(_tabOrder[b] ?? 99)))
        .first;
  }

  @override
  void initState() {
    super.initState();
    _audioProvider = context.read<AudioProvider>();
    _settingsProvider = context.read<SettingsProvider>();
    _progressProvider = context.read<ProgressProvider>();
    final requestedType = widget.initialType;
    final current = _audioProvider.currentQueueItem;
    if (requestedType != null &&
        widget.lesson.availableTypes.contains(requestedType)) {
      _selectedType = requestedType;
    } else if (current != null &&
        current.courseId == widget.lesson.courseId &&
        current.lessonId == widget.lesson.id) {
      // If this lesson is already loaded in the audio queue, resume it rather than restarting
      _selectedType = widget.lesson.availableTypes.firstWhere(
        (t) => t.assetFolder == current.typeFolder,
        orElse: () => _firstDisplayType(),
      );
      _lastKnownQueueIndex = _audioProvider.queueIndex;
    } else {
      _selectedType = _firstDisplayType();
    }
    unawaited(_loadTemporaryArabicVocabulary());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _audioProvider.addListener(_onAudioProviderChanged);
      // Check tips before loading so autoplay is gated correctly.
      await _checkLessonTips();
      if (mounted) _loadLesson();
    });
    _wakelockTracker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      WakelockPlus.toggle(
        enable: _settingsProvider.neverSleep && _audioProvider.isPlaying,
      );
    });
  }

  void _onAudioProviderChanged() {
    if (!mounted) return;
    final audio = _audioProvider;

    if (audio.queueIndex == _lastKnownQueueIndex) return;
    _lastKnownQueueIndex = audio.queueIndex;

    final item = audio.currentQueueItem;
    if (item == null) return;
    if (item.courseId != widget.lesson.courseId ||
        item.lessonId != widget.lesson.id) return;

    final newType = widget.lesson.availableTypes.firstWhere(
      (t) => t.assetFolder == item.typeFolder,
      orElse: () => _selectedType,
    );
    if (newType != _selectedType) {
      setState(() {
        _selectedType = newType;
        _lastScrolledToIndex = -1;
        _userHasScrolled = false;
        _sentenceKeys.clear();
      });
    }
  }

  @override
  void dispose() {
    _stopRepeatTimers();
    _audioProvider.removeListener(_onAudioProviderChanged);
    _resumeScrollTimer?.cancel();
    _sleepTimer?.cancel();
    _wakelockTracker?.cancel();
    WakelockPlus.disable();
    _saveProgress();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveProgress() {
    if (_audioProvider.duration.inSeconds > 0) {
      final fraction = (_audioProvider.position.inSeconds /
              _audioProvider.duration.inSeconds)
          .clamp(0.0, 1.0);
      final key = '${widget.lesson.courseId}_${widget.lesson.id}';
      _progressProvider.updateLessonProgress(key, fraction);
      if (fraction >= 0.8 && !_lessonCompletionRequested) {
        _lessonCompletionRequested = true;
        unawaited(_trackLessonCompletion());
      }
    }
  }

  Future<void> _trackLessonCompletion() async {
    final isNewCompletion = await DailyUsageService.recordLessonCompleted(
      courseId: widget.lesson.courseId,
      lessonId: widget.lesson.id,
    );
    if (!isNewCompletion) return;
    await AnalyticsService.logLessonCompleted(
      courseId: widget.lesson.courseId,
      lessonId: widget.lesson.id,
    );
  }

  Future<void> _trackLessonOpened() async {
    final type = _selectedType.assetFolder;
    if (!_trackedLessonOpens.add(type)) return;
    await DailyUsageService.recordLessonOpened();
    await AnalyticsService.logLessonOpened(
      courseId: widget.lesson.courseId,
      lessonId: widget.lesson.id,
      lessonType: type,
    );
  }

  Future<void> _loadTemporaryArabicVocabulary() async {
    await WordDefinitionService.load();
    if (!mounted) return;
    setState(() {
      _temporaryArabicVocabularyReady =
          WordDefinitionService.temporaryArabicVocabulary.isNotEmpty;
    });
  }

  static String _audioPathFor(int courseId, int lessonId, String typeFolder) {
    final c = courseId.toString().padLeft(2, '0');
    final l = lessonId.toString().padLeft(2, '0');
    return 'assets/courses/course_$c/lesson_$l/$typeFolder/audio.opus';
  }

  static String _jsonPathFor(int courseId, int lessonId, String typeFolder) {
    final c = courseId.toString().padLeft(2, '0');
    final l = lessonId.toString().padLeft(2, '0');
    return 'assets/courses/course_$c/lesson_$l/$typeFolder/content.json';
  }

  List<AudioQueueItem> _buildCourseQueue() {
    final courses = context.read<CourseProvider>().courses;
    final course = courses.firstWhere((c) => c.id == widget.lesson.courseId);
    final items = <AudioQueueItem>[];
    for (final lesson in course.lessons) {
      for (final type in lesson.availableTypes) {
        final assetPath = _audioPathFor(
          lesson.courseId,
          lesson.id,
          type.assetFolder,
        );
        items.add(
          AudioQueueItem(
            courseId: lesson.courseId,
            lessonId: lesson.id,
            typeFolder: type.assetFolder,
            audioPath: assetPath,
            jsonPath: _jsonPathFor(
              lesson.courseId,
              lesson.id,
              type.assetFolder,
            ),
            title:
                'Course ${lesson.courseId}: Lesson ${lesson.id.toString().padLeft(2, '0')} — ${type.displayName}',
            remotePath: lesson.courseId == 1 ? '' : assetPath,
          ),
        );
      }
    }
    return items;
  }

  Future<void> _loadLesson() async {
    // Skip reload if this lesson/type is already playing — preserves background playback
    final current = _audioProvider.currentQueueItem;
    if (current != null &&
        current.courseId == widget.lesson.courseId &&
        current.lessonId == widget.lesson.id &&
        current.typeFolder == _selectedType.assetFolder) {
      unawaited(_trackLessonOpened());
      return;
    }
    // Check offline before touching audio state
    final audioPath = DownloadProvider.audioPath(
      widget.lesson.courseId,
      widget.lesson.id,
      _selectedType.assetFolder,
    );
    final isCached = context.read<DownloadProvider>().isPathCached(audioPath);
    if (!isCached && !ContentSourceConfig.isLocalOverride) {
      final online = await _checkOnline();
      if (!online) {
        if (mounted) setState(() => _isOfflineUncached = true);
        return;
      }
    }
    if (mounted && _isOfflineUncached)
      setState(() => _isOfflineUncached = false);

    unawaited(_trackLessonOpened());
    _saveProgress();
    setState(() {
      _lastScrolledToIndex = -1;
      _userHasScrolled = false;
      _sentenceKeys.clear();
    });
    final queue = _buildCourseQueue();
    final idx = queue
        .indexWhere(
          (item) =>
              item.lessonId == widget.lesson.id &&
              item.typeFolder == _selectedType.assetFolder,
        )
        .clamp(0, queue.length - 1);
    _lastKnownQueueIndex = idx;
    await _audioProvider.loadQueue(queue, idx);
    if (mounted &&
        !_audioProvider.isPlaying &&
        _settingsProvider.autoPlay &&
        !_showingLessonTips) {
      await _audioProvider.togglePlayPause();
    }
    // Auto-download all types for this lesson in the background
    if (mounted) {
      context.read<DownloadProvider>().downloadLesson(widget.lesson);
    }
  }

  Future<bool> _checkOnline() async {
    if (kIsWeb) return true;
    try {
      final r = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 4));
      return r.isNotEmpty && r[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkLessonTips() async {
    if (!mounted) return;
    setState(() => _showingLessonTips = false);
  }

  Future<void> _onLessonTipsDone() async {
    setState(() => _showingLessonTips = false);
    if (_settingsProvider.autoPlay && !_audioProvider.isPlaying) {
      await _audioProvider.togglePlayPause();
    }
  }

  static String _fmtSpeed(double s) {
    final str = s.toString();
    return str.endsWith('.0')
        ? '${str.substring(0, str.length - 2)}x'
        : '${str}x';
  }

  void _cycleSleepTimer() {
    _sleepTimer?.cancel();
    setState(() {
      _sleepIndex = (_sleepIndex + 1) % _sleepOptions.length;
    });
    final minutes = _sleepOptions[_sleepIndex];
    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        if (!mounted) return;
        if (_audioProvider.isPlaying) _audioProvider.togglePlayPause();
        setState(() => _sleepIndex = 0);
      });
    }
  }

  // ── Auto-scroll (teleprompter style) ──────────────────────────────────────
  // Only scrolls when the active sentence drifts past 55% of the viewport.
  // When scrolling, brings it to ~20% from the top so it feels natural.

  void _autoScrollTo(int index) {
    if (_userHasScrolled || _isProgrammaticScroll) return;
    if (!_scrollController.hasClients) return;
    if (index == _lastScrolledToIndex) return;

    final key = _sentenceKeys[index];

    if (key?.currentContext == null) {
      // Not rendered yet — jump to estimated position and retry
      final max = _scrollController.position.maxScrollExtent;
      final total = _sentenceKeys.length.clamp(1, 999999);
      final estimated = (index / total * max).clamp(0.0, max);
      _isProgrammaticScroll = true;
      _scrollController.jumpTo(estimated);
      _isProgrammaticScroll = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoScrollTo(index);
      });
      return;
    }

    final box = key!.currentContext!.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    try {
      final viewport = RenderAbstractViewport.of(box);
      final scrollOffset = _scrollController.offset;
      final viewportHeight = _scrollController.position.viewportDimension;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final itemTop = viewport.getOffsetToReveal(box, 0.0).offset;

      // Item already in upper 70% of screen — don't scroll, just mark handled
      if (itemTop >= scrollOffset &&
          itemTop < scrollOffset + viewportHeight * 0.70) {
        _lastScrolledToIndex = index;
        return;
      }

      // Item is in lower 30% or off screen — scroll to bring it to ~20% from top
      _lastScrolledToIndex = index;
      final target = (itemTop - viewportHeight * 0.2).clamp(0.0, maxScroll);
      if ((target - scrollOffset).abs() < 8) return;

      _isProgrammaticScroll = true;
      _scrollController
          .animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      )
          .then((_) {
        if (mounted) _isProgrammaticScroll = false;
      });
    } catch (_) {}
  }

  void _checkResumeAutoScroll() {
    if (!mounted || !_userHasScrolled) return;
    final index = _audioProvider.currentSentenceIndex;
    final key = _sentenceKeys[index];
    if (key != null && _isKeyInViewport(key)) {
      setState(() {
        _userHasScrolled = false;
        _lastScrolledToIndex = -1;
      });
    }
  }

  bool _isKeyInViewport(GlobalKey key) {
    try {
      if (!_scrollController.hasClients) return false;
      final ctx = key.currentContext;
      if (ctx == null) return false;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return false;

      final viewport = RenderAbstractViewport.of(box);
      final scrollOffset = _scrollController.offset;
      final viewportDimension = _scrollController.position.viewportDimension;
      final offsetTop = viewport.getOffsetToReveal(box, 0.0).offset;
      final offsetBottom = viewport.getOffsetToReveal(box, 1.0).offset;

      return offsetBottom >= scrollOffset &&
          offsetTop <= scrollOffset + viewportDimension;
    } catch (_) {
      return false;
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Title detection ───────────────────────────────────────────────────────
  bool _looksLikeTitle(String text) {
    final t = text.trim();
    if (t.isEmpty || t.length > 70) return false;
    if (t.split(' ').length > 8) return false;
    if (t.endsWith('.') || t.endsWith('?') || t.endsWith('!')) return false;
    if (t.contains(',')) return false;
    final greetings = RegExp(
      r'^(hi|hello|welcome|okay|ok|hey|so|now|let|well|and|the |a |an |i |my |this|alright|great|today|first|next|in |it |you|we |they)',
      caseSensitive: false,
    );
    return !greetings.hasMatch(t);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final th = context.watch<ThemeProvider>().current;
    final scaffold = Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        backgroundColor: th.bg,
        leading: BackButton(color: th.textPrimary),
        title: Text(
          'Lesson ${widget.lesson.id.toString().padLeft(2, "0")} ${widget.lesson.title}',
          style: TextStyle(color: th.textPrimary, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bedtime_rounded,
              color: _sleepOptions[_sleepIndex] > 0 ? th.accent : th.textSub,
              size: 22,
            ),
            tooltip: _sleepOptions[_sleepIndex] > 0
                ? 'Sleep in ${_sleepOptions[_sleepIndex]}m'
                : 'Sleep timer off',
            onPressed: _cycleSleepTimer,
          ),
          Consumer<FavouritesProvider>(
            builder: (_, favs, __) {
              final isFav = favs.isFavourite(
                widget.lesson.courseId,
                widget.lesson.id,
              );
              return IconButton(
                tooltip: isFav ? 'Remove from favourites' : 'Add to favourites',
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFav ? th.accent : th.textSub,
                ),
                onPressed: () => context.read<FavouritesProvider>().toggle(
                      widget.lesson.courseId,
                      widget.lesson.id,
                    ),
              );
            },
          ),
          IconButton(
            tooltip: 'Playback settings',
            icon: Icon(Icons.settings_rounded, color: th.textSub),
            onPressed: () => _showSettingsSheet(context, th),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isOfflineUncached
          ? _buildOfflineError(th)
          : Column(
              children: [
                if (ContentSourceConfig.transcriptDebugEnabled)
                  _buildContentSourceBanner(th),
                if (ContentSourceConfig.transcriptDebugEnabled)
                  _buildTranscriptCalibrationPanel(th),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        color: th.textSub.withValues(alpha: 0.4),
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Tap any word to look it up',
                        style: TextStyle(
                          color: th.textSub.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildSentenceList(th)),
                if (widget.lesson.availableTypes.length > 1)
                  _buildTypeSelector(th),
                _buildAudioControls(th),
              ],
            ),
    );

    if (_showingLessonTips) {
      return Stack(
        children: [
          scaffold,
          LessonCoachTour(th: th, onDone: _onLessonTipsDone),
        ],
      );
    }
    return scaffold;
  }

  Widget _buildOfflineError(AppTheme th) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              color: th.textSub.withValues(alpha: 0.4),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Not available offline',
              style: TextStyle(
                color: th.textSub,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "This lesson hasn't been downloaded.\nConnect to the internet or download it first.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: th.textSub.withValues(alpha: 0.6),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSourceBanner(AppTheme th) {
    return Consumer<AudioProvider>(
      builder: (_, audio, __) {
        final isLocal = ContentSourceConfig.isLocalOverride;
        final bg = isLocal
            ? Colors.green.withValues(alpha: 0.14)
            : th.textSub.withValues(alpha: 0.08);
        final fg = isLocal ? Colors.greenAccent.shade400 : th.textSub;
        final mode = isLocal ? 'LOCAL FIXTURE MODE' : 'PRODUCTION R2 MODE';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          color: bg,
          child: Row(
            children: [
              Icon(
                isLocal ? Icons.science_rounded : Icons.cloud_done_rounded,
                color: fg,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$mode  |  Transcript: ${audio.transcriptSource}  |  Audio: ${audio.audioSource}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscriptCalibrationPanel(AppTheme th) {
    return Consumer<AudioProvider>(
      builder: (_, audio, __) {
        final raw = audio.position.inMilliseconds / 1000.0;
        final effective = audio.effectiveHighlightSeconds;
        final offset = audio.debugHighlightOffsetSeconds;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          color: th.playerBar.withValues(alpha: 0.92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, color: th.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Transcript calibration  |  raw ${raw.toStringAsFixed(2)}s  |  highlight ${effective.toStringAsFixed(2)}s  |  offset ${offset >= 0 ? '+' : ''}${offset.toStringAsFixed(1)}s',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: th.textSub,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _debugOffsetButton(th, '-1.5s', () {
                    audio.adjustDebugHighlightOffset(-1.5);
                  }),
                  _debugOffsetButton(th, '-1.0s', () {
                    audio.adjustDebugHighlightOffset(-1.0);
                  }),
                  _debugOffsetButton(th, '-0.5s', () {
                    audio.adjustDebugHighlightOffset(-0.5);
                  }),
                  _debugOffsetButton(th, 'Reset', () {
                    audio.setDebugHighlightOffset(0);
                  }),
                  _debugOffsetButton(th, '+0.5s', () {
                    audio.adjustDebugHighlightOffset(0.5);
                  }),
                  _debugOffsetButton(th, '+1.0s', () {
                    audio.adjustDebugHighlightOffset(1.0);
                  }),
                  _debugOffsetButton(th, '+1.5s', () {
                    audio.adjustDebugHighlightOffset(1.5);
                  }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _debugOffsetButton(AppTheme th, String label, VoidCallback onPressed) {
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: th.textSub,
          side: BorderSide(color: th.textSub.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildSentenceList(AppTheme th) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (!_isProgrammaticScroll) {
          if (notification is ScrollUpdateNotification &&
              notification.dragDetails != null &&
              !_userHasScrolled) {
            setState(() => _userHasScrolled = true);
            _resumeScrollTimer?.cancel();
          } else if (notification is ScrollEndNotification &&
              _userHasScrolled) {
            _resumeScrollTimer?.cancel();
            _resumeScrollTimer = Timer(
              const Duration(milliseconds: 400),
              _checkResumeAutoScroll,
            );
          }
        }
        return false;
      },
      child: Consumer2<AudioProvider, SettingsProvider>(
        builder: (context, audio, settings, _) {
          if (audio.loadError != null) {
            return _buildLoadError(th, audio.loadError!);
          }
          if (audio.content == null) {
            return Center(child: CircularProgressIndicator(color: th.accent));
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _autoScrollTo(audio.currentSentenceIndex);
          });
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            scrollCacheExtent: const ScrollCacheExtent.pixels(800.0),
            itemCount: audio.content!.sentences.length,
            itemBuilder: (context, index) {
              _sentenceKeys.putIfAbsent(index, () => GlobalKey());
              final sentence = audio.content!.sentences[index];
              final isActive = audio.currentSentenceIndex == index;

              // Title detection: first sentence that is short, has no sentence-ending
              // punctuation, and doesn't start with a greeting/conversational word.
              final isTitle = index == 0 &&
                  _looksLikeTitle(
                    sentence.arabic.isNotEmpty
                        ? sentence.arabic
                        : sentence.english,
                  );

              final arabicText = sentence.arabic.isNotEmpty
                  ? sentence.arabic
                  : sentence.english;
              final englishText = sentence.english;

              if (isTitle) {
                return Container(
                  key: _sentenceKeys[index],
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Text(
                    arabicText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: th.accent,
                      fontSize: settings.arabicFontSize + 4,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              }

              final isQueued = _repeatQueue.any((q) => q.index == index);
              return Tooltip(
                message: 'Long press to repeat / add to learning queue',
                waitDuration: const Duration(seconds: 2),
                child: GestureDetector(
                  key: _sentenceKeys[index],
                  onTap: () => audio.seekToSentence(index),
                  onLongPress: () {
                    _showRepeatActionSheet(
                      context,
                      th,
                      _RepeatQueueItem(index: index, sentence: sentence),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? th.accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      border: isActive
                          ? Border(left: BorderSide(color: th.accent, width: 3))
                          : isQueued
                              ? Border(
                                  left: BorderSide(
                                    color: th.accent.withValues(alpha: 0.4),
                                    width: 2,
                                  ),
                                )
                              : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildArabicTranscriptText(
                            text: arabicText,
                            th: th,
                            settings: settings,
                            isActive: isActive,
                          ),
                        ),
                        if (settings.showArabicTranslation &&
                            englishText.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              englishText,
                              style: TextStyle(
                                color: isActive ? th.textPrimary : th.textSub,
                                fontSize: settings.englishFontSize,
                                height: 1.5,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ],
                        if (isQueued) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.playlist_add_check_rounded,
                                color: th.accent.withValues(alpha: 0.6),
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'In repeat queue',
                                style: TextStyle(
                                  color: th.accent.withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ), // GestureDetector
              ); // Tooltip
            },
          );
        },
      ),
    );
  }

  Widget _buildArabicTranscriptText({
    required String text,
    required AppTheme th,
    required SettingsProvider settings,
    required bool isActive,
  }) {
    final baseStyle = TextStyle(
      color: isActive ? th.textPrimary : th.textSub,
      fontSize: settings.arabicFontSize + 3,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      height: 1.7,
    );
    final matches = _temporaryArabicVocabularyReady
        ? WordDefinitionService.matchArabicTerms(text)
        : const <ArabicVocabularyMatch>[];
    if (matches.isEmpty) {
      return Text(
        text,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: baseStyle,
      );
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: _buildArabicVocabularySpans(text, matches, baseStyle, th),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
    );
  }

  List<InlineSpan> _buildArabicVocabularySpans(
    String text,
    List<ArabicVocabularyMatch> matches,
    TextStyle baseStyle,
    AppTheme th,
  ) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    final tappableStyle = baseStyle.copyWith(
      color: th.textPrimary,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: th.accent.withValues(alpha: 0.75),
      backgroundColor: th.accent.withValues(alpha: 0.07),
    );

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showTemporaryArabicVocabulary(match),
          child: Text(
            match.surfaceText,
            textDirection: TextDirection.rtl,
            style: tappableStyle,
          ),
        ),
      ));
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  void _showTemporaryArabicVocabulary(ArabicVocabularyMatch match) {
    showDialog(
      context: context,
      builder: (_) => WordDefinitionOverlay(
        word: match.entry.englishHeadword,
        clickedForm: match.surfaceText,
        englishMeaning: match.entry.englishHeadword,
        definition: match.entry.definition,
        arabicEntry: match.entry,
        temporaryDevVocabulary: true,
      ),
    );
  }

  Widget _buildLoadError(AppTheme th, String message) {
    final isLocal = ContentSourceConfig.isLocalOverride;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: th.accent, size: 44),
            const SizedBox(height: 14),
            Text(
              isLocal
                  ? 'Local fixture failed to load'
                  : 'Lesson failed to load',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: th.textSub, fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadLesson,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(AppTheme th) {
    final orderedTypes = [...widget.lesson.availableTypes]
      ..sort((a, b) => (_tabOrder[a] ?? 99).compareTo(_tabOrder[b] ?? 99));

    return Container(
      height: 44,
      decoration: BoxDecoration(color: th.playerBar),
      child: Row(
        children: orderedTypes.map((type) {
          final isSelected = _selectedType == type;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _selectedType = type);
                _loadLesson();
              },
              child: Container(
                alignment: Alignment.center,
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: th.accent, width: 2),
                        ),
                      )
                    : null,
                child: Text(
                  type.displayName,
                  style: TextStyle(
                    color: isSelected ? th.accent : th.textSub,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAudioControls(AppTheme th) {
    return Consumer<AudioProvider>(
      builder: (context, audio, _) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          color: th.playerBar,
          child: Column(
            children: [
              if (_repeatQueue.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildRepeatQueueBar(th),
                ),
              if (_sleepOptions[_sleepIndex] > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bedtime_rounded, color: th.accent, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'Sleep in ${_sleepOptions[_sleepIndex]} min',
                        style: TextStyle(color: th.accent, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'Cancel sleep timer',
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            _sleepTimer?.cancel();
                            setState(() => _sleepIndex = 0);
                          },
                          child: Icon(Icons.close, color: th.textSub, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: audio.duration.inSeconds > 0
                      ? (audio.position.inSeconds / audio.duration.inSeconds)
                          .clamp(0.0, 1.0)
                      : 0.0,
                  activeColor: th.accent,
                  inactiveColor: th.textSub.withValues(alpha: 0.3),
                  onChanged: (v) => audio.seekTo(
                    Duration(seconds: (v * audio.duration.inSeconds).toInt()),
                  ),
                  onChangeEnd: (_) {
                    setState(() {
                      _userHasScrolled = false;
                      _lastScrolledToIndex = -1;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _autoScrollTo(_audioProvider.currentSentenceIndex);
                      }
                    });
                  },
                ),
              ),
              // Time display
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _fmt(audio.position),
                      style: TextStyle(color: th.textSub, fontSize: 11),
                    ),
                    Text(
                      _fmt(audio.duration),
                      style: TextStyle(color: th.textSub, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Speed picker
                  Semantics(
                    label: 'Playback speed: ${_fmtSpeed(audio.speed)}',
                    button: true,
                    child: InkWell(
                      onTap: () => _showSpeedPicker(context, audio, th),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: th.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _fmtSpeed(audio.speed),
                          style: TextStyle(
                            color: th.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.replay_10, color: th.textSub, size: 28),
                    tooltip: 'Rewind 10 seconds',
                    onPressed: audio.skipBackward,
                  ),
                  Semantics(
                    label: audio.isPlaying ? 'Pause' : 'Play',
                    button: true,
                    child: GestureDetector(
                      onTap: audio.togglePlayPause,
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: th.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          audio.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.forward_10, color: th.textSub, size: 28),
                    tooltip: 'Skip forward 10 seconds',
                    onPressed: audio.skipForward,
                  ),
                  // Audio loop button
                  IconButton(
                    icon: Icon(
                      audio.loopMode == PlayerLoopMode.once
                          ? Icons.repeat_one
                          : Icons.repeat,
                      color: audio.loopMode == PlayerLoopMode.none
                          ? th.textSub
                          : th.accent,
                      size: 22,
                    ),
                    tooltip: 'Loop audio',
                    onPressed: audio.cycleLoopMode,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRepeatQueueBar(AppTheme th) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: th.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: th.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.repeat_one_rounded, color: th.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_repeatQueue.length} sentence${_repeatQueue.length == 1 ? '' : 's'} in repeat queue',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: th.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: _openQueuedRepeatMode,
            child: Text('Open', style: TextStyle(color: th.accent)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Clear repeat queue',
            icon: Icon(Icons.close_rounded, color: th.textSub, size: 18),
            onPressed: () => setState(_repeatQueue.clear),
          ),
        ],
      ),
    );
  }

  Future<void> _showRepeatActionSheet(
    BuildContext context,
    AppTheme th,
    _RepeatQueueItem item,
  ) async {
    final alreadyQueued = _repeatQueue.any((q) => q.index == item.index);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: th.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: th.textSub.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              ListTile(
                leading: Icon(Icons.repeat_one_rounded, color: th.accent),
                title: Text(
                  'Repeat this sentence',
                  style: TextStyle(color: th.textPrimary),
                ),
                onTap: () => Navigator.pop(context, 'repeat'),
              ),
              ListTile(
                leading: Icon(
                  alreadyQueued
                      ? Icons.playlist_add_check_rounded
                      : Icons.playlist_add_rounded,
                  color: alreadyQueued ? th.textSub : th.accent,
                ),
                title: Text(
                  alreadyQueued
                      ? 'Already in repeat queue'
                      : 'Add to repeat queue',
                  style: TextStyle(
                    color: alreadyQueued ? th.textSub : th.textPrimary,
                  ),
                ),
                subtitle: alreadyQueued
                    ? Text(
                        'Tap "Open" in the queue bar to start',
                        style: TextStyle(color: th.textSub, fontSize: 12),
                      )
                    : Text(
                        'Temporary for this lesson session',
                        style: TextStyle(color: th.textSub, fontSize: 12),
                      ),
                onTap: alreadyQueued
                    ? () => Navigator.pop(context, 'cancel')
                    : () => Navigator.pop(context, 'queue'),
              ),
              ListTile(
                leading: Icon(Icons.close_rounded, color: th.textSub),
                title: Text('Cancel', style: TextStyle(color: th.textSub)),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null || action == 'cancel') return;
    if (action == 'repeat') {
      await _openRepeatMode([item], keepQueueAfterClose: false);
    } else if (action == 'queue') {
      _addToRepeatQueue(item);
    }
  }

  void _addToRepeatQueue(_RepeatQueueItem item) {
    setState(() {
      final exists = _repeatQueue.any((queued) => queued.index == item.index);
      if (!exists) _repeatQueue.add(item);
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added sentence ${item.index + 1} to repeat queue',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        action: SnackBarAction(label: 'Open', onPressed: _openQueuedRepeatMode),
      ),
    );
  }

  Future<void> _openQueuedRepeatMode() async {
    if (_repeatQueue.isEmpty) return;
    await _openRepeatMode(
      List<_RepeatQueueItem>.from(_repeatQueue),
      keepQueueAfterClose: true,
    );
  }

  Future<void> _openRepeatMode(
    List<_RepeatQueueItem> queue, {
    required bool keepQueueAfterClose,
  }) async {
    if (queue.isEmpty || _audioProvider.content == null) return;
    final th = context.read<ThemeProvider>().current;
    if (_repeatModeOpen && mounted) {
      Navigator.of(context).maybePop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    _stopRepeatTimers();
    _repeatWasPlaying = _audioProvider.isPlaying;
    _repeatRestorePosition = _audioProvider.position;
    _repeatRestoreSpeed = _audioProvider.speed;
    _repeatKeepQueueAfterClose = keepQueueAfterClose;
    setState(() {
      _repeatQueue
        ..clear()
        ..addAll(queue);
      _repeatIndex = 0;
      _repeatCompletedForCurrent = 0;
      _repeatModeOpen = true;
    });
    await _audioProvider.pause(); // explicit — no stale isPlaying check
    await _audioProvider.setSpeed(_repeatSpeed);

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _repeatModeOpen) _playCurrentRepeatSegment();
    });

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (_) => StatefulBuilder(
        builder: (context, modalSetState) {
          _repeatOverlayRefresh = () {
            if (mounted) modalSetState(() {});
          };
          return _RepeatLearningOverlay(
            th: th,
            queue: _repeatQueue,
            currentIndex: _repeatIndex,
            completedForCurrent: _repeatCompletedForCurrent,
            repeatCount: _repeatCount,
            isPlaying: _repeatIsPlaying,
            onClose: () => Navigator.pop(context),
            onReplay: _restartCurrentRepeatSentence,
            onPlayPause: () async {
              if (_repeatIsPlaying) {
                _stopRepeatTimers(); // sets _repeatIsPlaying = false
                await _audioProvider.pause();
              } else {
                await _playCurrentRepeatSegment(); // sets _repeatIsPlaying = true
              }
              if (mounted) _repeatOverlayRefresh?.call();
            },
            onOpenSettings: () => _showRepeatSettingsSheet(context),
            onRepeatCountChanged: (value) {
              setState(() {
                _repeatCount = value;
                _repeatCompletedForCurrent = 0;
              });
              _repeatOverlayRefresh?.call();
              _playCurrentRepeatSegment();
            },
            onWordTap: (word, clickedForm) {
              final matches =
                  WordDefinitionService.matchArabicTerms(clickedForm);
              if (matches.isNotEmpty) {
                _showTemporaryArabicVocabulary(matches.first);
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Arabic word lookup coming soon.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          );
        },
      ),
    ).whenComplete(_restoreAfterRepeatMode);
  }

  Future<void> _restoreAfterRepeatMode() async {
    if (!_repeatModeOpen) return;
    _stopRepeatTimers();
    _repeatOverlayRefresh = null;
    final shouldResume = _repeatWasPlaying;
    final restorePosition = _repeatRestorePosition;
    final restoreSpeed = _repeatRestoreSpeed;
    setState(() {
      _repeatModeOpen = false;
      _repeatCompletedForCurrent = 0;
      if (!_repeatKeepQueueAfterClose) _repeatQueue.clear();
    });
    await _audioProvider.pause(); // explicit — no stale isPlaying check
    await _audioProvider.setSpeed(restoreSpeed);
    await _audioProvider.seekTo(restorePosition);
    if (shouldResume && mounted) {
      await _audioProvider.play();
    }
  }

  void _stopRepeatTimers() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatDelayTimer?.cancel();
    _repeatDelayTimer = null;
    _handlingBoundary = false;
    _repeatIsPlaying = false;
  }

  Future<void> _playCurrentRepeatSegment() async {
    if (!_repeatModeOpen || _repeatQueue.isEmpty) return;
    _stopRepeatTimers(); // also sets _repeatIsPlaying = false
    final item = _repeatQueue[_repeatIndex];
    final startTime = item.sentence.startTime;
    await _audioProvider.setSpeed(_repeatSpeed);
    // Explicit pause — does not depend on _isPlaying (eliminates stale-state race).
    await _audioProvider.pause();
    await _audioProvider.seekTo(
      Duration(milliseconds: (startTime * 1000).round()),
    );
    if (!mounted || !_repeatModeOpen) return;
    // Explicit play — deterministic regardless of _isPlaying stream state.
    await _audioProvider.play();
    if (!mounted || !_repeatModeOpen) return;
    setState(() => _repeatIsPlaying = true);
    _repeatOverlayRefresh?.call();
    _repeatTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!_repeatModeOpen || _repeatQueue.isEmpty) return;
      final current = _repeatQueue[_repeatIndex].sentence;
      final positionSeconds = _audioProvider.position.inMilliseconds / 1000.0;
      // Skip check while we are near the start of the segment — guards against
      // a stale position value firing a false boundary immediately after seekTo.
      if (positionSeconds < startTime + 0.15) return;
      if (positionSeconds >= current.endTime - 0.03) {
        _handleRepeatBoundary();
      }
    });
  }

  Future<void> _handleRepeatBoundary() async {
    if (!_repeatModeOpen || _repeatQueue.isEmpty) return;
    // Guard against timer firing again before the async pause/seek completes.
    if (_handlingBoundary) return;
    _handlingBoundary = true;
    _stopRepeatTimers(); // also resets _handlingBoundary and _repeatIsPlaying
    _handlingBoundary = true;
    // Explicit pause — no _isPlaying check to avoid stale-state race.
    await _audioProvider.pause();
    if (!mounted || !_repeatModeOpen) {
      _handlingBoundary = false;
      return;
    }
    setState(() => _repeatCompletedForCurrent++);
    _repeatOverlayRefresh?.call();

    final target = _repeatTargetCount(_repeatCount);
    final hasNext = _repeatIndex < _repeatQueue.length - 1;

    if (target != null) {
      // Finite: repeat current sentence N times, then advance to next.
      if (_repeatCompletedForCurrent < target) {
        _handlingBoundary = false;
        _scheduleRepeatPlayback();
        return;
      }
      if (hasNext) {
        setState(() {
          _repeatIndex++;
          _repeatCompletedForCurrent = 0;
        });
        _repeatOverlayRefresh?.call();
        _handlingBoundary = false;
        _scheduleRepeatPlayback();
        return;
      }
      // All sentences exhausted — stay on last, stop.
      _repeatOverlayRefresh?.call();
      _handlingBoundary = false;
    } else {
      // Infinite: play each sentence once per cycle, advancing through queue.
      // At end of queue, wrap back to start (cycles indefinitely).
      setState(() {
        _repeatIndex = hasNext ? _repeatIndex + 1 : 0;
        _repeatCompletedForCurrent = 0;
      });
      _repeatOverlayRefresh?.call();
      _handlingBoundary = false;
      _scheduleRepeatPlayback();
    }
  }

  void _scheduleRepeatPlayback() {
    final delay = Duration(seconds: _repeatDelaySeconds);
    if (delay == Duration.zero) {
      _playCurrentRepeatSegment();
    } else {
      _repeatDelayTimer = Timer(delay, _playCurrentRepeatSegment);
    }
  }

  void _restartCurrentRepeatSentence() {
    setState(() => _repeatCompletedForCurrent = 0);
    _repeatOverlayRefresh?.call();
    _playCurrentRepeatSegment();
  }

  int? _repeatTargetCount(_RepeatCount count) {
    switch (count) {
      case _RepeatCount.once:
        return 1;
      case _RepeatCount.three:
        return 3;
      case _RepeatCount.five:
        return 5;
      case _RepeatCount.infinite:
        return null;
    }
  }

  void _showSpeedPicker(
    BuildContext context,
    AudioProvider audio,
    AppTheme th,
  ) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];
    showModalBottomSheet(
      context: context,
      backgroundColor: th.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Playback Speed',
              style: TextStyle(
                color: th.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: speeds.map((s) {
                final isSelected = audio.speed == s;
                return Semantics(
                  label: '${s}x speed${isSelected ? ', selected' : ''}',
                  button: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        audio.setSpeed(s);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? th.accent
                              : th.textSub.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          '${s}x',
                          style: TextStyle(
                            color: isSelected ? Colors.white : th.textSub,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showRepeatSettingsSheet(BuildContext context) {
    final th = context.read<ThemeProvider>().current;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: th.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, sheetSetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Repeat Settings',
                  style: TextStyle(
                    color: th.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Speed',
                    style: TextStyle(
                      color: th.textSub,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ChipRow<double>(
                    th: th,
                    values: const [0.75, 1.0, 1.25],
                    selected: _repeatSpeed,
                    labelFor: (v) => v == 1.0 ? '1×' : '${v}×',
                    onChanged: (v) {
                      sheetSetState(() {});
                      setState(() => _repeatSpeed = v);
                      _audioProvider.setSpeed(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Gap',
                    style: TextStyle(
                      color: th.textSub,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _ChipRow<int>(
                    th: th,
                    values: const [0, 1, 2],
                    selected: _repeatDelaySeconds,
                    labelFor: (v) => v == 0 ? '0s' : '${v}s',
                    onChanged: (v) {
                      sheetSetState(() {});
                      setState(() => _repeatDelaySeconds = v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, AppTheme th) {
    showModalBottomSheet(
      context: context,
      backgroundColor: th.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SettingsProvider>(),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            child: _SettingsSheet(th: th),
          ),
        ),
      ),
    );
  }
}

// ── Repeat Learning Overlay ───────────────────────────────────────────────────
// Mini-lesson list view for repeat / shadowing mode.
// All sentences visible; active sentence highlighted and auto-scrolled into view.

class _RepeatLearningOverlay extends StatefulWidget {
  final AppTheme th;
  final List<_RepeatQueueItem> queue;
  final int currentIndex;
  final int completedForCurrent;
  final _RepeatCount repeatCount;
  final bool isPlaying;
  final VoidCallback onClose;
  final VoidCallback onReplay;
  final Future<void> Function() onPlayPause;
  final VoidCallback onOpenSettings;
  final ValueChanged<_RepeatCount> onRepeatCountChanged;
  final void Function(String word, String clickedForm) onWordTap;

  const _RepeatLearningOverlay({
    required this.th,
    required this.queue,
    required this.currentIndex,
    required this.completedForCurrent,
    required this.repeatCount,
    required this.isPlaying,
    required this.onClose,
    required this.onReplay,
    required this.onPlayPause,
    required this.onOpenSettings,
    required this.onRepeatCountChanged,
    required this.onWordTap,
  });

  @override
  State<_RepeatLearningOverlay> createState() => _RepeatLearningOverlayState();
}

class _RepeatLearningOverlayState extends State<_RepeatLearningOverlay> {
  final ScrollController _scrollCtrl = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.queue.length; i++) {
      _itemKeys[i] = GlobalKey();
    }
  }

  @override
  void didUpdateWidget(covariant _RepeatLearningOverlay old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToActive() {
    final key = _itemKeys[widget.currentIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = widget.th;
    final queue = widget.queue;
    final target = _targetCount(widget.repeatCount);

    return Container(
      decoration: BoxDecoration(
        color: th.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: th.textSub.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 10, 0),
              child: Row(
                children: [
                  Icon(Icons.repeat_rounded, color: th.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Repeat Practice',
                    style: TextStyle(
                      color: th.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'Repeat settings',
                    button: true,
                    child: GestureDetector(
                      onTap: widget.onOpenSettings,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.tune_rounded,
                          color: th.textSub,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Close repeat mode',
                    button: true,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: th.textSub.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: th.textSub,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Sentence list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: queue.length,
                itemBuilder: (context, i) {
                  return _SentenceRow(
                    key: _itemKeys[i],
                    th: th,
                    item: queue[i],
                    index: i,
                    isActive: i == widget.currentIndex,
                    onWordTap: widget.onWordTap,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Bottom bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  _ChipRow<_RepeatCount>(
                    th: th,
                    values: _RepeatCount.values,
                    selected: widget.repeatCount,
                    labelFor: _repeatLabel,
                    onChanged: widget.onRepeatCountChanged,
                  ),
                  const Spacer(),
                  _buildProgress(th, target),
                  const SizedBox(width: 12),
                  Semantics(
                    label: 'Replay current sentence',
                    button: true,
                    child: GestureDetector(
                      onTap: widget.onReplay,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: th.accent.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.replay_rounded,
                          color: th.accent,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: widget.isPlaying ? 'Pause' : 'Play',
                    button: true,
                    child: GestureDetector(
                      onTap: () => widget.onPlayPause(),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: th.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(AppTheme th, int? target) {
    final completed = widget.completedForCurrent;
    if (target == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.all_inclusive_rounded, color: th.accent, size: 16),
          const SizedBox(width: 4),
          Text(
            '× ${completed + 1}',
            style: TextStyle(
              color: th.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    final display = (completed + 1).clamp(1, target);
    return Text(
      '$display / $target',
      style: TextStyle(
        color: th.accent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static int? _targetCount(_RepeatCount count) {
    switch (count) {
      case _RepeatCount.once:
        return 1;
      case _RepeatCount.three:
        return 3;
      case _RepeatCount.five:
        return 5;
      case _RepeatCount.infinite:
        return null;
    }
  }

  static String _repeatLabel(_RepeatCount count) {
    switch (count) {
      case _RepeatCount.once:
        return '1×';
      case _RepeatCount.three:
        return '3×';
      case _RepeatCount.five:
        return '5×';
      case _RepeatCount.infinite:
        return '∞';
    }
  }
}

class _SentenceRow extends StatelessWidget {
  final AppTheme th;
  final _RepeatQueueItem item;
  final int index;
  final bool isActive;
  final void Function(String word, String clickedForm) onWordTap;

  const _SentenceRow({
    super.key,
    required this.th,
    required this.item,
    required this.index,
    required this.isActive,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isActive ? th.accent.withValues(alpha: 0.10) : th.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? th.accent.withValues(alpha: 0.40)
              : th.textSub.withValues(alpha: 0.10),
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color:
                    isActive ? th.accent : th.textSub.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => onWordTap(
                      item.sentence.arabic.isNotEmpty
                          ? item.sentence.arabic
                          : item.sentence.english,
                      item.sentence.arabic.isNotEmpty
                          ? item.sentence.arabic
                          : item.sentence.english,
                    ),
                    child: Text(
                      item.sentence.arabic.isNotEmpty
                          ? item.sentence.arabic
                          : item.sentence.english,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: th.textPrimary,
                        fontSize: 16,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        height: 1.55,
                      ),
                    ),
                  ),
                ),
                if (item.sentence.english.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.sentence.english,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: isActive
                          ? th.textSub
                          : th.textSub.withValues(alpha: 0.65),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  final AppTheme th;
  final List<T> values;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;

  const _ChipRow({
    required this.th,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: values.map((v) {
        final isSelected = v == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isSelected ? th.accent : th.textSub.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? th.accent
                      : th.textSub.withValues(alpha: 0.14),
                ),
              ),
              child: Text(
                labelFor(v),
                style: TextStyle(
                  color: isSelected ? Colors.white : th.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final AppTheme th;
  const _SettingsSheet({required this.th});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Display Settings',
                style: TextStyle(
                  color: th.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Consumer<SettingsProvider>(
                builder: (_, s, __) => TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    s.setEnglishFontSize(16.0);
                    s.setArabicFontSize(13.0);
                    s.setPronunciationSpeed(1.0);
                  },
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 14,
                    color: th.textSub,
                  ),
                  label: Text(
                    'Reset',
                    style: TextStyle(color: th.textSub, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'English translation: ${settings.englishFontSize.toInt()}pt',
            style: TextStyle(color: th.textSub, fontSize: 13),
          ),
          Slider(
            value: settings.englishFontSize,
            min: 12,
            max: 24,
            divisions: 12,
            activeColor: th.accent,
            inactiveColor: th.textSub.withValues(alpha: 0.25),
            onChanged: settings.setEnglishFontSize,
          ),
          const SizedBox(height: 8),
          Text(
            'Arabic transcript: ${settings.arabicFontSize.toInt()}pt',
            style: TextStyle(color: th.textSub, fontSize: 13),
          ),
          Slider(
            value: settings.arabicFontSize,
            min: 10,
            max: 20,
            divisions: 10,
            activeColor: th.accent,
            inactiveColor: th.textSub.withValues(alpha: 0.25),
            onChanged: settings.setArabicFontSize,
          ),
          Divider(color: th.textSub.withValues(alpha: 0.15), height: 24),
          _SettingRow(
            th: th,
            label: 'Auto-play when opening lesson',
            sub: 'Starts audio automatically',
            value: settings.autoPlay,
            onChanged: settings.setAutoPlay,
          ),
          const SizedBox(height: 8),
          _SettingRow(
            th: th,
            label: 'Pause on word tap',
            sub: 'Resumes from same sentence after closing',
            value: settings.pauseOnWordTap,
            onChanged: settings.setPauseOnWordTap,
          ),
          Divider(color: th.textSub.withValues(alpha: 0.15), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pronunciation speed',
                style: TextStyle(color: th.textSub, fontSize: 13),
              ),
              Text(
                '${(settings.pronunciationSpeed * 100).round()}%',
                style: TextStyle(
                  color: th.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: settings.pronunciationSpeed,
            min: 0.5,
            max: 1.0,
            divisions: 10,
            activeColor: th.accent,
            inactiveColor: th.textSub.withValues(alpha: 0.25),
            onChanged: settings.setPronunciationSpeed,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0.5×', style: TextStyle(color: th.textSub, fontSize: 11)),
              Text('1.0×', style: TextStyle(color: th.textSub, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final AppTheme th;
  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingRow({
    required this.th,
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: th.textSub, fontSize: 13)),
              Text(
                sub,
                style: TextStyle(
                  color: th.textSub.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, activeThumbColor: th.accent, onChanged: onChanged),
      ],
    );
  }
}
