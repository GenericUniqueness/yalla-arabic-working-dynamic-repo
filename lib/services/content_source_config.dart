import 'package:flutter/foundation.dart';

const _productionContentBaseUrl =
    'https://pub-9071b083f7474a3083519acf9f8e8dbe.r2.dev';

class ContentSourceConfig {
  static const Map<String, String> _localNormalizedAudioOverrides = {
    'assets/courses/course_05/lesson_20/vocabulary/audio.opus':
        'local_fixtures/alignment_batch/audio_normalized/course_05/lesson_20/vocabulary/audio.opus',
    'assets/courses/course_05/lesson_22/vocabulary/audio.opus':
        'local_fixtures/alignment_batch/audio_normalized/course_05/lesson_22/vocabulary/audio.opus',
    'assets/courses/course_05/lesson_25/conversation/audio.opus':
        'local_fixtures/alignment_batch/audio_normalized/course_05/lesson_25/conversation/audio.opus',
    'assets/courses/course_05/lesson_26/mini_story/audio.opus':
        'local_fixtures/alignment_batch/audio_normalized/course_05/lesson_26/mini_story/audio.opus',
    'assets/courses/course_05/lesson_27/vocabulary/audio.opus':
        'local_fixtures/alignment_batch/audio_normalized/course_05/lesson_27/vocabulary/audio.opus',
    'assets/courses/course_05/lesson_28/vocabulary/audio.opus':
        'local_fixtures/alignment_batch/audio_normalized/course_05/lesson_28/vocabulary/audio.opus',
  };

  static const _overrideBaseUrl =
      String.fromEnvironment('YALLA_CONTENT_BASE_URL');
  static const _dpAlignmentBaseUrl =
      String.fromEnvironment('YALLA_DP_ALIGNMENT_BASE_URL');
  static const _debugTranscript =
      bool.fromEnvironment('YALLA_TRANSCRIPT_DEBUG');
  static const _qaLessonKey = String.fromEnvironment('YALLA_QA_LESSON_KEY');

  static bool get isLocalOverride => _overrideBaseUrl.trim().isNotEmpty;

  static bool get isLocalDpAlignmentEnabled =>
      kDebugMode && _dpAlignmentBaseUrl.trim().isNotEmpty;

  static bool get transcriptDebugEnabled =>
      kDebugMode &&
      (isLocalOverride || isLocalDpAlignmentEnabled || _debugTranscript);

  static bool get qaLessonLaunchEnabled =>
      kDebugMode && _debugTranscript && _qaLessonKey.trim().isNotEmpty;

  static String get qaLessonKey =>
      qaLessonLaunchEnabled ? _qaLessonKey.trim() : '';

  static String get baseUrl {
    final override = _overrideBaseUrl.trim();
    if (override.isNotEmpty) return _stripTrailingSlash(override);
    return _productionContentBaseUrl;
  }

  static String get dpAlignmentBaseUrl =>
      _stripTrailingSlash(_dpAlignmentBaseUrl.trim());

  static String get cacheNamespace => isLocalDpAlignmentEnabled
      ? 'local_dp_alignment'
      : isLocalOverride
          ? 'local_fixture'
          : 'production_r2';

  static bool get allowBackgroundJsonRefresh => !isLocalOverride;

  static String remoteUrl(String remotePath) =>
      '$baseUrl/${resolveAudioRemotePath(remotePath)}';

  static String resolveAudioRemotePath(String remotePath) {
    if (!kDebugMode || !isLocalOverride) return remotePath;
    return _localNormalizedAudioOverrides[remotePath] ?? remotePath;
  }

  static String? localNormalizedAudioLessonKey(String remotePath) {
    if (!kDebugMode || !isLocalOverride) return null;
    if (!_localNormalizedAudioOverrides.containsKey(remotePath)) return null;
    var out = remotePath;
    const prefix = 'assets/courses/';
    if (out.startsWith(prefix)) out = out.substring(prefix.length);
    if (out.endsWith('/audio.opus')) {
      out = out.substring(0, out.length - '/audio.opus'.length);
    }
    return out;
  }

  static String dpAlignmentUrl(String candidatePath) =>
      '$dpAlignmentBaseUrl/$candidatePath';

  static String _stripTrailingSlash(String value) {
    var out = value;
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }
}
