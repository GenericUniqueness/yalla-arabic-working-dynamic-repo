import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/sentence.dart';
import '../services/audio_handler.dart';
import '../services/audio_cache_service.dart';
import '../services/content_source_config.dart';

export '../services/audio_handler.dart' show AudioQueueItem;

enum PlayerLoopMode { none, once, infinite }

class AudioProvider extends ChangeNotifier {
  final YallaAudioHandler _handler;
  final List<StreamSubscription> _subs = [];

  LessonContent? _content;
  int _currentSentenceIndex = 0;
  bool _isPlaying = false;
  ProcessingState _processingState = ProcessingState.idle;
  double _speed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  PlayerLoopMode _loopMode = PlayerLoopMode.none;
  String? _loadError;
  double _debugHighlightOffsetSeconds = 0.0;

  // Throttle position-only notifyListeners calls: only notify when sentence
  // index changes OR when position has moved more than 0.5 s since last notify.
  // This reduces full-tree rebuilds from ~10/s to a fraction of that during
  // steady playback while keeping sentence highlighting accurate.
  double _lastNotifiedPositionSeconds = -999.0;

  LessonContent? get content => _content;
  int get currentSentenceIndex => _currentSentenceIndex;
  bool get isPlaying => _isPlaying;
  bool get isPlaybackActive =>
      _isPlaying && _processingState == ProcessingState.ready;
  bool get isPlaybackTerminal =>
      _processingState == ProcessingState.idle ||
      _processingState == ProcessingState.completed;
  double get speed => _speed;
  Duration get position => _position;
  Duration get duration => _duration;
  PlayerLoopMode get loopMode => _loopMode;
  String? get loadError => _loadError;
  double get debugHighlightOffsetSeconds => _debugHighlightOffsetSeconds;
  double get effectiveHighlightSeconds =>
      (_position.inMilliseconds / 1000.0) + _debugHighlightOffsetSeconds;
  int get queueIndex => _handler.queueIndex;
  String get transcriptSource => _handler.transcriptSource;
  String get audioSource => _handler.audioSource;
  AudioQueueItem? get currentQueueItem => _handler.audioQueue.isEmpty
      ? null
      : _handler.audioQueue[_handler.queueIndex];

  AudioProvider(this._handler) {
    _subs.add(_handler.positionStream.listen((pos) {
      _position = pos;
      final prevSentence = _currentSentenceIndex;
      _updateCurrentSentence(effectiveHighlightSeconds);
      final currentSeconds = pos.inMilliseconds / 1000.0;
      // Always notify when sentence index changes; otherwise throttle to
      // every 0.5 s of playback to reduce rebuild frequency.
      if (_currentSentenceIndex != prevSentence ||
          (currentSeconds - _lastNotifiedPositionSeconds).abs() >= 0.5) {
        _lastNotifiedPositionSeconds = currentSeconds;
        notifyListeners();
      }
    }));
    _subs.add(_handler.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    }));
    _subs.add(_handler.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    }));
    _subs.add(_handler.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      _processingState = state.processingState;
      if (state.processingState == ProcessingState.completed) {
        if (_loopMode == PlayerLoopMode.infinite) {
          _handler.seek(Duration.zero).then((_) => _handler.play());
        } else if (_loopMode == PlayerLoopMode.once) {
          _loopMode = PlayerLoopMode.none;
          _handler.seek(Duration.zero).then((_) => _handler.play());
          notifyListeners();
        }
      }
      notifyListeners();
    }));
    // Queue advanced externally (e.g. notification Next/Prev button)
    _subs.add(_handler.queueIndexStream.listen((_) {
      _content = _handler.content;
      _currentSentenceIndex = 0;
      _position = Duration.zero;
      _seekToFirstSentence();
      notifyListeners();
    }));
  }

  void cycleLoopMode() {
    const modes = PlayerLoopMode.values;
    _loopMode = modes[(_loopMode.index + 1) % modes.length];
    notifyListeners();
  }

  Future<void> loadQueue(List<AudioQueueItem> items, int startIndex) async {
    _content = null;
    _loadError = null;
    _lastNotifiedPositionSeconds = -999.0;
    notifyListeners();
    try {
      final resolved = await _resolveCachedFiles(items);
      await _handler.loadQueue(resolved, startIndex);
      _content = _handler.content;
      _currentSentenceIndex = 0;
      await _seekToFirstSentence();
      notifyListeners();
    } catch (e) {
      _loadError = e.toString();
      debugPrint('Error loading queue: $_loadError');
      notifyListeners();
    }
  }

  Future<void> _seekToFirstSentence() async {
    if (_content == null || _content!.sentences.isEmpty) return;
    final firstStart = _content!.sentences.first.startTime;
    if (firstStart > 0.3) {
      await _handler.seek(Duration(milliseconds: (firstStart * 1000).toInt()));
    }
  }

  Future<List<AudioQueueItem>> _resolveCachedFiles(
      List<AudioQueueItem> items) async {
    return Future.wait(items.map((item) async {
      if (item.remotePath.isEmpty) return item;
      if (ContentSourceConfig.isLocalOverride) return item;
      final cached =
          await AudioCacheService.instance.cachedFile(item.remotePath);
      if (cached != null) return item.withLocalFile(cached.path);
      return item;
    }));
  }

  /// Download the audio for a single queue item and return updated item.
  Future<AudioQueueItem> downloadItem(
    AudioQueueItem item, {
    void Function(int received, int total)? onProgress,
  }) async {
    if (item.remotePath.isEmpty) return item;
    final file = await AudioCacheService.instance.ensureCached(
      item.remotePath,
      onProgress: onProgress,
    );
    return item.withLocalFile(file.path);
  }

  bool isItemCached(AudioQueueItem item) {
    if (item.localFilePath != null) return true;
    // Sync check not available — use isCachedAsync for UI
    return false;
  }

  void _updateCurrentSentence(double currentSeconds) {
    if (_content == null) return;
    for (int i = 0; i < _content!.sentences.length; i++) {
      final s = _content!.sentences[i];
      if (currentSeconds >= s.startTime && currentSeconds <= s.endTime) {
        if (_currentSentenceIndex != i) {
          _currentSentenceIndex = i;
          notifyListeners();
        }
        return;
      }
    }
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  /// Explicit pause — does not check _isPlaying (avoids stale-state race).
  Future<void> pause() async {
    await _handler.pause();
  }

  /// Explicit play — does not check _isPlaying (avoids stale-state race).
  Future<void> play() async {
    await _handler.play();
  }

  Future<void> seekToSentence(int index) async {
    if (_content == null || index >= _content!.sentences.length) return;
    final seconds = _content!.sentences[index].startTime;
    _currentSentenceIndex = index;
    await _handler.seek(Duration(milliseconds: (seconds * 1000).toInt()));
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    // Update _position immediately so consumers (e.g. repeat boundary timer)
    // don't read stale endTime from the previous segment while the
    // positionStream catches up after the seek.
    _position = position;
    await _handler.seek(position);
    _updateCurrentSentence(
      (position.inMilliseconds / 1000.0) + _debugHighlightOffsetSeconds,
    );
    notifyListeners();
  }

  void setDebugHighlightOffset(double seconds) {
    if (!ContentSourceConfig.transcriptDebugEnabled) return;
    _debugHighlightOffsetSeconds = seconds.clamp(-5.0, 5.0);
    _updateCurrentSentence(effectiveHighlightSeconds);
    notifyListeners();
  }

  void adjustDebugHighlightOffset(double deltaSeconds) {
    setDebugHighlightOffset(_debugHighlightOffsetSeconds + deltaSeconds);
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _handler.setSpeed(speed);
    notifyListeners();
  }

  Future<void> skipForward() async {
    final newPos = _position + const Duration(seconds: 10);
    if (newPos < _duration) await _handler.seek(newPos);
  }

  Future<void> skipBackward() async {
    final newPos = _position - const Duration(seconds: 10);
    await _handler.seek(newPos > Duration.zero ? newPos : Duration.zero);
  }

  void clearLesson() {
    _content = null;
    _loadError = null;
    _handler.clearAudio();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}
