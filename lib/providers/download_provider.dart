import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/audio_cache_service.dart';

class DownloadProvider extends ChangeNotifier {
  final Set<String> _cached = {};
  final Map<String, double> _downloading = {};
  List<Course> _courses = [];

  DownloadProvider();

  void setCourses(List<Course> courses) {
    _courses = courses;
    _initCacheState();
  }

  Future<void> _initCacheState() async {
    // Parallelise all File.exists() checks instead of awaiting each one
    // sequentially — reduces startup time from O(n) round-trips to O(1).
    final futures = <Future<void>>[];
    for (final course in _courses) {
      for (final lesson in course.lessons) {
        for (final type in lesson.availableTypes) {
          final path = audioPath(lesson.courseId, lesson.id, type.assetFolder);
          futures.add(
            AudioCacheService.instance.isCached(path).then((cached) {
              if (cached) _cached.add(path);
            }),
          );
        }
      }
    }
    await Future.wait(futures);
    notifyListeners();
  }

  static String audioPath(int courseId, int lessonId, String typeFolder) {
    final c = courseId.toString().padLeft(2, '0');
    final l = lessonId.toString().padLeft(2, '0');
    return 'assets/courses/course_$c/lesson_$l/$typeFolder/audio.mp3';
  }

  bool isPathCached(String path) => _cached.contains(path);
  bool isPathDownloading(String path) => _downloading.containsKey(path);
  double pathProgress(String path) => _downloading[path] ?? 0;

  bool isLessonDownloaded(Lesson lesson) => lesson.availableTypes.every(
        (t) => isPathCached(audioPath(lesson.courseId, lesson.id, t.assetFolder)),
      );

  /// Returns true if at least one (but not all) content types are cached locally.
  /// Useful for showing a partial-download indicator in the UI without changing
  /// the existing [isLessonDownloaded] behaviour.
  bool isLessonPartiallyDownloaded(Lesson lesson) =>
      !isLessonDownloaded(lesson) &&
      lesson.availableTypes.any(
        (t) => isPathCached(audioPath(lesson.courseId, lesson.id, t.assetFolder)),
      );

  bool isLessonDownloading(Lesson lesson) => lesson.availableTypes.any(
        (t) => isPathDownloading(audioPath(lesson.courseId, lesson.id, t.assetFolder)),
      );

  double lessonProgress(Lesson lesson) {
    final paths = lesson.availableTypes
        .map((t) => audioPath(lesson.courseId, lesson.id, t.assetFolder))
        .toList();
    final cachedCount = paths.where((p) => _cached.contains(p)).length;
    final downloadingSum = paths
        .where((p) => _downloading.containsKey(p))
        .fold(0.0, (sum, p) => sum + (_downloading[p] ?? 0));
    return (cachedCount + downloadingSum) / paths.length;
  }

  Future<void> downloadLesson(Lesson lesson) async {
    final paths = lesson.availableTypes
        .map((t) => audioPath(lesson.courseId, lesson.id, t.assetFolder))
        .where((p) => !_cached.contains(p) && !_downloading.containsKey(p))
        .toList();
    for (final path in paths) {
      _downloadSingle(path);
    }
  }

  Future<void> _downloadSingle(String path) async {
    _downloading[path] = 0;
    notifyListeners();
    try {
      await AudioCacheService.instance.ensureCached(
        path,
        onProgress: (received, total) {
          if (total > 0) {
            _downloading[path] = received / total;
            notifyListeners();
          }
        },
      );
      _cached.add(path);
      // Also cache the JSON so text works offline
      AudioCacheService.instance.ensureJsonCached(path);
    } catch (_) {
      // silently fail — will stream from R2 next time
    } finally {
      _downloading.remove(path);
      notifyListeners();
    }
  }

  Future<void> deleteLesson(Lesson lesson) async {
    for (final type in lesson.availableTypes) {
      final path = audioPath(lesson.courseId, lesson.id, type.assetFolder);
      await AudioCacheService.instance.evict(path);
      // Also evict the JSON content cache so totalCacheBytes() is accurate
      // and stale transcripts don't persist after a lesson is "deleted".
      await AudioCacheService.instance.evictJson(path);
      _cached.remove(path);
    }
    notifyListeners();
  }

  Future<void> deleteAll() async {
    await AudioCacheService.instance.clearAll();
    _cached.clear();
    notifyListeners();
  }

  Future<int> totalCacheBytes() => AudioCacheService.instance.totalCacheBytes();

  List<({Course course, Lesson lesson})> get downloadedLessons {
    final result = <({Course course, Lesson lesson})>[];
    for (final course in _courses) {
      for (final lesson in course.lessons) {
        final hasCached = lesson.availableTypes.any(
          (t) => isPathCached(audioPath(lesson.courseId, lesson.id, t.assetFolder)),
        );
        if (hasCached) result.add((course: course, lesson: lesson));
      }
    }
    return result;
  }
}
