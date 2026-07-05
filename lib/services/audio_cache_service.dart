import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/sentence.dart';
import 'content_source_config.dart';

/// Full HTTPS URL for a remote path.
///
/// Defaults to production R2. For isolated local transcript testing, pass:
/// --dart-define=YALLA_CONTENT_BASE_URL=http://127.0.0.1:8000
String remoteUrl(String remotePath) =>
    ContentSourceConfig.remoteUrl(remotePath);

/// Manages local caching of audio files downloaded from Cloudflare R2.
/// Remote path convention: assets/courses/course_02/lesson_01/main_story/audio.mp3
class AudioCacheService {
  static AudioCacheService? _instance;
  static AudioCacheService get instance => _instance ??= AudioCacheService._();
  AudioCacheService._();

  Directory? _cacheDir;

  Future<Directory> get cacheDir async {
    _cacheDir ??= Directory(
      '${(await getApplicationDocumentsDirectory()).path}/'
      'audio_cache_${ContentSourceConfig.cacheNamespace}',
    );
    if (!await _cacheDir!.exists()) await _cacheDir!.create(recursive: true);
    return _cacheDir!;
  }

  Future<File> _localFile(String remotePath) async {
    final safe = remotePath.replaceAll('/', '_');
    return File('${(await cacheDir).path}/$safe');
  }

  Future<bool> isCached(String remotePath) async {
    return (await _localFile(remotePath)).exists();
  }

  Future<File?> cachedFile(String remotePath) async {
    final f = await _localFile(remotePath);
    return (await f.exists()) ? f : null;
  }

  /// Downloads the file if not already cached. Returns the local [File].
  Future<File> ensureCached(
    String remotePath, {
    void Function(int received, int total)? onProgress,
  }) async {
    final local = await _localFile(remotePath);
    if (await local.exists()) return local;

    final url = remoteUrl(remotePath);
    final tmp = File('${local.path}.tmp');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response =
          await client.send(request).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('R2 download failed (${response.statusCode}): $url');
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = tmp.openWrite();
      try {
        await response.stream.timeout(const Duration(seconds: 60)).forEach(
          (chunk) {
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(received, total);
          },
        );
      } finally {
        await sink.close();
      }
      await tmp.rename(local.path);
      return local;
    } catch (_) {
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<int> remoteSize(String remotePath) async {
    try {
      final res = await http.head(Uri.parse(remoteUrl(remotePath)));
      final cl = res.headers['content-length'];
      return cl != null ? int.tryParse(cl) ?? 0 : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> evict(String remotePath) async {
    final f = await _localFile(remotePath);
    if (await f.exists()) await f.delete();
  }

  /// Evicts the JSON content cache file for the given audio remote path.
  /// The JSON is stored in json_cache_<namespace>/ using the same naming
  /// convention as [ensureJsonCached].
  Future<void> evictJson(String audioRemotePath) async {
    final jsonRemote = audioRemotePath.replaceAll('audio.mp3', 'content.json');
    final appDir = await getApplicationDocumentsDirectory();
    final cacheFile = File(
      '${appDir.path}/json_cache_${ContentSourceConfig.cacheNamespace}/'
      '${jsonRemote.replaceAll('/', '_')}',
    );
    if (await cacheFile.exists()) await cacheFile.delete();
  }

  Future<int> totalCacheBytes() async {
    final dir = await cacheDir;
    int total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clearAll() async {
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(
      '${appDir.path}/audio_cache_${ContentSourceConfig.cacheNamespace}',
    );
    final jsonDir = Directory(
      '${appDir.path}/json_cache_${ContentSourceConfig.cacheNamespace}',
    );
    if (await audioDir.exists()) await audioDir.delete(recursive: true);
    if (await jsonDir.exists()) await jsonDir.delete(recursive: true);
    _cacheDir = null;
  }

  /// Pre-caches the content.json for a given audio remote path.
  /// Called during lesson download so text is available offline.
  Future<void> ensureJsonCached(String audioRemotePath) async {
    final jsonRemote = audioRemotePath.replaceAll('audio.mp3', 'content.json');
    final appDir = await getApplicationDocumentsDirectory();
    final cacheFile = File(
      '${appDir.path}/json_cache_${ContentSourceConfig.cacheNamespace}/'
      '${jsonRemote.replaceAll('/', '_')}',
    );
    if (await cacheFile.exists()) return;
    try {
      final res = await http
          .get(Uri.parse(remoteUrl(jsonRemote)))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && _isValidLessonContentJson(res.body)) {
        await _writeJsonCacheAtomically(cacheFile, res.body);
      }
    } catch (_) {}
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
}
