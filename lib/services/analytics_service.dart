import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  const AnalyticsService._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;
  static bool _collectionEnabled = true;

  static Future<void> setCollectionEnabled(bool enabled) async {
    _collectionEnabled = enabled;
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (_) {}
  }

  static int roundedMinutes(int seconds) {
    if (seconds <= 0) return 0;
    return (seconds / 60).round().clamp(1, 1000000).toInt();
  }

  static String scoreBucket(int correct, int total) {
    if (total <= 0) return 'no_score';
    final percent = (correct / total * 100).round();
    if (percent < 40) return '0_39';
    if (percent < 60) return '40_59';
    if (percent < 80) return '60_79';
    return '80_100';
  }

  static Future<bool> _log(
    String name,
    Map<String, Object> parameters,
  ) async {
    if (!_collectionEnabled) return false;
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> logDailySummary({
    required int appSeconds,
    required int listeningSeconds,
    required int lessonOpenCount,
    required int lessonCompleteCount,
    required int reviewQuizStartedCount,
    required int reviewQuizCompletedCount,
    required int grammarOpenedCount,
    required int grammarCompletedCount,
    required int savedWordAddCount,
    required int favoriteLessonAddCount,
  }) {
    return _log('app_daily_summary', {
      'app_minutes': roundedMinutes(appSeconds),
      'listening_minutes': roundedMinutes(listeningSeconds),
      'lesson_open_count': lessonOpenCount,
      'lesson_complete_count': lessonCompleteCount,
      'review_start_count': reviewQuizStartedCount,
      'review_complete_count': reviewQuizCompletedCount,
      'grammar_open_count': grammarOpenedCount,
      'grammar_complete_count': grammarCompletedCount,
      'saved_word_add_count': savedWordAddCount,
      'favorite_add_count': favoriteLessonAddCount,
    });
  }

  static Future<bool> logLessonOpened({
    required int courseId,
    required int lessonId,
    required String lessonType,
  }) {
    return _log('lesson_opened', {
      'course_id': courseId,
      'lesson_id': lessonId,
      'lesson_type': lessonType,
    });
  }

  static Future<bool> logLessonCompleted({
    required int courseId,
    required int lessonId,
  }) {
    return _log('lesson_completed', {
      'course_id': courseId,
      'lesson_id': lessonId,
      'completion_bucket': '80_100',
    });
  }

  static Future<bool> logListeningSession({
    required int courseId,
    required int lessonId,
    required int durationSeconds,
  }) {
    return _log('listening_session', {
      'course_id': courseId,
      'lesson_id': lessonId,
      'duration_minutes': roundedMinutes(durationSeconds),
    });
  }

  static Future<bool> logReviewQuizStarted({
    required String quizSource,
    required String quizMode,
    required int questionCount,
  }) {
    return _log('review_quiz_started', {
      'quiz_source': quizSource,
      'quiz_mode': quizMode,
      'question_count': questionCount,
    });
  }

  static Future<bool> logReviewQuizCompleted({
    required String quizSource,
    required String quizMode,
    required int correctCount,
    required int questionCount,
  }) {
    return _log('review_quiz_completed', {
      'quiz_source': quizSource,
      'quiz_mode': quizMode,
      'question_count': questionCount,
      'score_bucket': scoreBucket(correctCount, questionCount),
    });
  }

  static Future<bool> logGrammarTopicOpened({
    required String topicId,
    required String categoryId,
    required String level,
  }) {
    return _log('grammar_topic_opened', {
      'topic_id': topicId,
      'category_id': categoryId,
      'level': level,
    });
  }

  static Future<bool> logGrammarTopicCompleted({
    required String topicId,
    required int correctCount,
    required int questionCount,
  }) {
    return _log('grammar_topic_completed', {
      'topic_id': topicId,
      'question_count': questionCount,
      'score_bucket': scoreBucket(correctCount, questionCount),
    });
  }

  static Future<bool> logListeningMilestone(String milestoneBucket) {
    return _log('listening_milestone_reached', {
      'milestone_bucket': milestoneBucket,
    });
  }
}
