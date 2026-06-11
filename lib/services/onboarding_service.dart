import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_progress_service.dart';

/// Tracks onboarding completion per Firebase UID.
///
/// Source of truth: Firestore `users/{uid}/data/profile.onboardingComplete`.
/// Local SharedPreferences cache keyed by UID for offline fast-path.
///
/// Behavior:
/// - New account on any device → onboarding shows (Firestore has no record).
/// - Returning account on new/reinstalled device → skips (Firestore says done).
/// - Different account on same device → onboarding shows (local key is per-UID).
/// - Old users with only `disclaimerShown` in Firestore → skips (backward compat).
class OnboardingService {
  static String _localKey(String uid) => 'onboarding_complete_$uid';

  /// Returns true if this user has already completed the onboarding tour.
  /// Checks local cache first; falls back to Firestore on cache miss.
  static Future<bool> isCompleteForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_localKey(uid)) == true) return true;
    final done = await FirestoreProgressService.getOnboardingComplete(uid);
    if (done) await prefs.setBool(_localKey(uid), true);
    return done;
  }

  /// Marks onboarding complete for this UID in both Firestore and local cache.
  static Future<void> markCompleteForUser(String uid) async {
    FirestoreProgressService.setOnboardingComplete(uid); // fire and forget
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_localKey(uid), true);
  }

  /// Resets the completion flag for this UID (for testing / debug reset).
  static Future<void> resetForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localKey(uid));
  }
}
