import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreProgressService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference _doc(String uid) =>
      _db.collection('users').doc(uid).collection('data').doc('progress');

  static DocumentReference _profileDoc(String uid) =>
      _db.collection('users').doc(uid).collection('data').doc('profile');

  static Future<String?> getFirstName(String uid) async {
    try {
      final snap = await _profileDoc(uid).get();
      if (!snap.exists) return null;
      return (snap.data() as Map<String, dynamic>?)?['firstName'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveFirstName(String uid, String name) async {
    try {
      await _profileDoc(uid).set({'firstName': name}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Returns true if onboarding has been completed for this UID.
  /// Also returns true for users who completed the old disclaimerShown flow
  /// so they are not shown onboarding again after upgrading.
  static Future<bool> getOnboardingComplete(String uid) async {
    try {
      final snap = await _profileDoc(uid).get();
      final data = snap.data() as Map<String, dynamic>?;
      return data?['onboardingComplete'] == true ||
          data?['disclaimerShown'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setOnboardingComplete(String uid) async {
    try {
      await _profileDoc(uid)
          .set({'onboardingComplete': true}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<bool> getLessonTipsComplete(String uid) async {
    try {
      final snap = await _profileDoc(uid).get();
      final data = snap.data() as Map<String, dynamic>?;
      return data?['lessonTipsComplete'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setLessonTipsComplete(String uid) async {
    try {
      await _profileDoc(uid)
          .set({'lessonTipsComplete': true}, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Returns null if the document doesn't exist, throws on network error.
  static Future<Map<String, dynamic>?> load(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    return snap.data() as Map<String, dynamic>?;
  }

  /// Like load() but returns null on any error instead of throwing.
  static Future<Map<String, dynamic>?> loadSafe(String uid) async {
    try {
      return await load(uid);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> save(String uid, Map<String, dynamic> data) async {
    try {
      await _doc(uid).set(
        {...data, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirestoreProgressService] save() failed: $e');
      }
      return false;
    }
  }

  static Future<bool> saveUsageDay(
    String uid,
    String date,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('data')
          .doc('usage_$date')
          .set(
        {...data, 'syncedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FirestoreProgressService] usage-day save failed: $e');
      }
      return false;
    }
  }

  static Future<void> deleteCurrentUserData(String uid) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Current user does not match requested deletion UID.');
    }

    final userRef = _db.collection('users').doc(uid);
    final dataRef = userRef.collection('data');

    while (true) {
      final snapshot = await dataRef.limit(400).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < 400) break;
    }

    await userRef.delete();
  }
}
