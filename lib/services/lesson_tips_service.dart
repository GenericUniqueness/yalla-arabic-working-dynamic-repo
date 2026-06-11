import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_progress_service.dart';

/// Tracks whether the in-player lesson tips overlay has been shown and
/// dismissed for a given Firebase UID.
///
/// Source of truth: Firestore `users/{uid}/data/profile.lessonTipsComplete`.
/// SharedPreferences provides a per-UID fast-path cache for offline/instant reads.
///
/// Behaviour mirrors OnboardingService:
/// - First lesson opened on any device → tips show (Firestore has no record).
/// - Same account on any device after dismissal → tips never show again.
/// - Different account on same device → uses that account's flag independently.
class LessonTipsService {
  static String _localKey(String uid) => 'lesson_tips_complete_$uid';

  static Future<bool> isCompleteForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_localKey(uid)) == true) return true;
    final done = await FirestoreProgressService.getLessonTipsComplete(uid);
    if (done) await prefs.setBool(_localKey(uid), true);
    return done;
  }

  static Future<void> markCompleteForUser(String uid) async {
    FirestoreProgressService.setLessonTipsComplete(uid); // fire-and-forget
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localKey(uid), true);
  }
}
