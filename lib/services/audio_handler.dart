import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/sentence.dart';
import 'audio_cache_service.dart';
import 'content_source_config.dart';
import 'transcript_diagnostics.dart';

class AudioQueueItem {
  final String audioPath; // bundled asset path — used as fallback + for JSON
  final String
      remotePath; // Firebase Storage path (audio.mp3); empty = asset-only
  final String?
      localFilePath; // set by AudioProvider once the opus file is cached
  final String jsonPath;
  final String title;
  final int courseId;
  final int lessonId;
  final String typeFolder;

  const AudioQueueItem({
    required this.audioPath,
    required this.jsonPath,
    required this.title,
    required this.courseId,
    required this.lessonId,
    required this.typeFolder,
    this.remotePath = '',
    this.localFilePath,
  });

  AudioQueueItem withLocalFile(String path) => AudioQueueItem(
        audioPath: audioPath,
        jsonPath: jsonPath,
        title: title,
        courseId: courseId,
        lessonId: lessonId,
        typeFolder: typeFolder,
        remotePath: remotePath,
        localFilePath: path,
      );
}

class YallaAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  LessonContent? _content;
  List<AudioQueueItem> _queue = [];
  int _queueIndex = 0;
  String _transcriptSource = 'Not loaded';
  String _audioSource = 'Not loaded';
  final _queueIndexController = StreamController<int>.broadcast();

  LessonContent? get content => _content;
  int get queueIndex => _queueIndex;
  String get transcriptSource => _transcriptSource;
  String get audioSource => _audioSource;
  List<AudioQueueItem> get audioQueue => List.unmodifiable(_queue);
  Stream<int> get queueIndexStream => _queueIndexController.stream;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  YallaAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState, onError: (_, __) {});
    _player.durationStream.listen((dur) {
      if (dur != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: dur));
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  Future<void> loadQueue(List<AudioQueueItem> items, int startIndex) async {
    _queue = List.of(items);
    await _loadQueueItem(startIndex, autoPlay: false);
  }

  Future<void> _loadQueueItem(int index, {bool autoPlay = false}) async {
    if (index < 0 || index >= _queue.length) return;
    _queueIndex = index;
    final item = _queue[index];

    // Load JSON: R2 (cached) → asset bundle fallback
    final loadedJson = await _loadJson(item);
    _transcriptSource = loadedJson.source;
    try {
      _content = LessonContent.fromJson(jsonDecode(loadedJson.body));
    } catch (e) {
      throw AudioLoadException(
        'content.json parsed incorrectly from ${loadedJson.url}: $e',
      );
    }

    // Set notification title BEFORE loading audio so all state broadcasts
    // during loading already show the correct track name.
    mediaItem.add(MediaItem(
      id: item.audioPath,
      title: item.title,
      artist: 'Yalla Arabic',
      artUri: Uri.parse(
          'https://pub-9071b083f7474a3083519acf9f8e8dbe.r2.dev/icon.png'),
    ));

    // Prefer local cached file → stream from R2 if not cached.
    try {
      if (item.localFilePath != null) {
        _audioSource = 'Production cache';
        _logRequest('audio file', item.localFilePath!);
        await _player.setFilePath(item.localFilePath!);
      } else if (item.remotePath.isNotEmpty) {
        _audioSource = ContentSourceConfig.isLocalOverride
            ? 'Local fixture HTTP'
            : 'Production R2 stream';
        final normalizedLessonKey =
            ContentSourceConfig.localNormalizedAudioLessonKey(item.remotePath);
        if (normalizedLessonKey != null) {
          debugPrint('USING LOCAL NORMALIZED AUDIO: $normalizedLessonKey');
        }
        final url = remoteUrl(item.remotePath);
        _logRequest('audio.mp3', url);
        await _player.setUrl(url);
      } else {
        _audioSource = 'Bundled asset';
        _logRequest('audio asset', item.audioPath);
        await _player.setAsset(item.audioPath);
      }
    } catch (e) {
      throw AudioLoadException(
        'audio failed to load from ${_audioDebugUrl(item)}: $e',
      );
    }

    if (_player.duration != null) {
      mediaItem.add(mediaItem.value!.copyWith(duration: _player.duration));
    }

    TranscriptDiagnostics.logLesson(
      content: _content,
      sourcePath: item.jsonPath,
      audioDuration: _player.duration,
    );

    _queueIndexController.add(_queueIndex);
    if (autoPlay) await _player.play();
  }

  static Future<_LoadedJson> _loadJson(AudioQueueItem item) async {
    if (item.remotePath.isNotEmpty) {
      final jsonRemote =
          item.remotePath.replaceAll('audio.mp3', 'content.json');
      final dpAlignedJson = await _loadLocalDpAlignedJson(jsonRemote);
      if (dpAlignedJson != null) return dpAlignedJson;

      final jsonUrl = remoteUrl(jsonRemote);
      final dir = await getApplicationDocumentsDirectory();
      final cacheFile = File(
        '${dir.path}/json_cache_${ContentSourceConfig.cacheNamespace}/'
        '${jsonRemote.replaceAll('/', '_')}',
      );

      // Cache-first: return instantly if cached. Production may refresh in the
      // background; local fixture mode never refreshes from R2.
      if (await cacheFile.exists()) {
        final cachedBody = await cacheFile.readAsString();
        if (!_isValidLessonContentJson(cachedBody)) {
          await cacheFile.delete();
        } else {
          if (ContentSourceConfig.allowBackgroundJsonRefresh) {
            _refreshJsonInBackground(jsonRemote, cacheFile);
          }
          return _LoadedJson(
            body: cachedBody,
            source: ContentSourceConfig.isLocalOverride
                ? 'Local fixture cache'
                : 'Production R2 cache',
            url: cacheFile.path,
          );
        }
      }

      // Not cached yet: fetch from R2 and cache
      try {
        _logRequest('content.json', jsonUrl);
        final res = await http
            .get(Uri.parse(jsonUrl))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          if (!_isValidLessonContentJson(res.body)) {
            throw AudioLoadException(
              'content.json parsed incorrectly from $jsonUrl',
            );
          }
          await _writeJsonCacheAtomically(cacheFile, res.body);
          return _LoadedJson(
            body: res.body,
            source: ContentSourceConfig.isLocalOverride
                ? 'Local fixture HTTP'
                : 'Production R2 HTTP',
            url: jsonUrl,
          );
        }
        throw AudioLoadException(
          'content.json request failed (${res.statusCode}) from $jsonUrl',
        );
      } on AudioLoadException {
        rethrow;
      } catch (e) {
        throw AudioLoadException(
          'content.json request failed from $jsonUrl: $e',
        );
      }
    }
    // Asset bundle fallback
    try {
      _logRequest('content asset', item.jsonPath);
      return _LoadedJson(
        body: await rootBundle.loadString(item.jsonPath),
        source: 'Bundled asset fallback',
        url: item.jsonPath,
      );
    } catch (e) {
      throw AudioLoadException(
        'content.json asset fallback failed from ${item.jsonPath}: $e',
      );
    }
  }

  static Future<_LoadedJson?> _loadLocalDpAlignedJson(String jsonRemote) async {
    if (!ContentSourceConfig.isLocalDpAlignmentEnabled) return null;

    final lessonKey = _dpLessonKey(jsonRemote);
    final manifest = await _localDpAlignmentManifest();
    if (!manifest.containsKey(lessonKey)) return null;

    final candidatePath =
        manifest[lessonKey] ?? '$lessonKey/content.dp_aligned.json';
    final candidateUrl = ContentSourceConfig.dpAlignmentUrl(candidatePath);
    try {
      _logRequest('content.dp_aligned.json', candidateUrl);
      final res = await http
          .get(Uri.parse(candidateUrl))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) {
        debugPrint(
          '[ContentRequest] Local DP manifest listed $lessonKey but '
          '$candidateUrl returned ${res.statusCode}; falling back',
        );
        return null;
      }
      if (!_isValidLessonContentJson(res.body)) {
        debugPrint(
          '[ContentRequest] Local DP alignment invalid for $lessonKey; '
          'falling back',
        );
        return null;
      }
      debugPrint('USING LOCAL DP ALIGNMENT: $lessonKey -> $candidatePath');
      return _LoadedJson(
        body: res.body,
        source: 'Local DP alignment HTTP',
        url: candidateUrl,
      );
    } catch (e) {
      debugPrint(
        '[ContentRequest] Local DP alignment failed for $lessonKey: $e; '
        'falling back',
      );
      return null;
    }
  }

  static Future<Map<String, String?>> _localDpAlignmentManifest() async {
    final manifestUrl =
        ContentSourceConfig.dpAlignmentUrl('dp_alignment_manifest.json');
    try {
      _logRequest('DP alignment manifest', manifestUrl);
      final res = await http
          .get(Uri.parse(manifestUrl))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return const <String, String?>{};
      final decoded = jsonDecode(res.body);
      final lessons = decoded is Map<String, dynamic>
          ? decoded['lessons']
          : decoded is List<dynamic>
              ? decoded
              : const [];
      if (lessons is! List) return const <String, String?>{};
      final manifest = <String, String?>{};
      for (final entry in lessons) {
        if (entry is String) {
          manifest[entry] = null;
          continue;
        }
        if (entry is Map<String, dynamic>) {
          final lessonKey = entry['lesson_key'];
          final candidatePath = entry['candidate_path'];
          if (lessonKey is String && lessonKey.isNotEmpty) {
            manifest[lessonKey] =
                candidatePath is String && candidatePath.isNotEmpty
                    ? candidatePath
                    : null;
          }
        }
      }
      return manifest;
    } catch (e) {
      debugPrint(
        '[ContentRequest] Local DP alignment manifest unavailable: $e',
      );
      return const <String, String?>{};
    }
  }

  static String _dpLessonKey(String jsonRemote) {
    var out = jsonRemote;
    const prefix = 'assets/courses/';
    if (out.startsWith(prefix)) out = out.substring(prefix.length);
    if (out.endsWith('/content.json')) {
      out = out.substring(0, out.length - '/content.json'.length);
    }
    return out;
  }

  static void _refreshJsonInBackground(String jsonRemote, File cacheFile) {
    http
        .get(Uri.parse(remoteUrl(jsonRemote)))
        .timeout(const Duration(seconds: 10))
        .then((res) {
      if (res.statusCode == 200) {
        if (!_isValidLessonContentJson(res.body)) return;
        _writeJsonCacheAtomically(cacheFile, res.body);
      }
    }).catchError((_) {});
  }

  static bool _isValidLessonContentJson(String body) {
    try {
      LessonContent.fromJson(jsonDecode(body));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _writeJsonCacheAtomically(
    File cacheFile,
    String body,
  ) async {
    await cacheFile.parent.create(recursive: true);
    final tmp = File('${cacheFile.path}.tmp');
    await tmp.writeAsString(body, flush: true);
    await tmp.rename(cacheFile.path);
  }

  static void _logRequest(String label, String url) {
    if (!ContentSourceConfig.transcriptDebugEnabled) return;
    debugPrint('[ContentRequest] $label -> $url');
  }

  static String _audioDebugUrl(AudioQueueItem item) {
    if (item.localFilePath != null) return item.localFilePath!;
    if (item.remotePath.isNotEmpty) return remoteUrl(item.remotePath);
    return item.audioPath;
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_queueIndex < _queue.length - 1) {
      await _loadQueueItem(_queueIndex + 1, autoPlay: true);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else if (_queueIndex > 0) {
      await _loadQueueItem(_queueIndex - 1, autoPlay: true);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    playbackState.add(playbackState.value.copyWith(speed: speed));
  }

  void clearAudio() {
    _content = null;
    _queue = [];
    _queueIndex = 0;
    _transcriptSource = 'Not loaded';
    _audioSource = 'Not loaded';
    _player.stop();
    mediaItem.add(null);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async => stop();
}

class _LoadedJson {
  final String body;
  final String source;
  final String url;

  const _LoadedJson({
    required this.body,
    required this.source,
    required this.url,
  });
}

class AudioLoadException implements Exception {
  final String message;

  const AudioLoadException(this.message);

  @override
  String toString() => message;
}
