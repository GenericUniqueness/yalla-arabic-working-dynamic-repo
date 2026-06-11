import 'package:flutter/foundation.dart';

class DevUser {
  final String uid;
  final String? email;
  final bool emailVerified;

  const DevUser({required this.uid, this.email, this.emailVerified = true});
}

class AuthProvider extends ChangeNotifier {
  static const DevUser _localUser = DevUser(
    uid: 'yalla_arabic_local_guest',
    email: 'local-dev@yallaarabic.test',
  );

  DevUser? get user => _localUser;
  bool get isLoggedIn => true;
  bool get isLoading => false;
  bool get isEmailPasswordUser => false;
  bool get isGoogleUser => false;
  bool get requiresPasswordForAccountDeletion => false;
  bool get needsEmailVerification => false;

  Future<String?> signInWithEmail(String email, String password) async => null;
  Future<String?> registerWithEmail(String email, String password) async =>
      null;
  Future<String?> sendEmailVerification() async => null;
  Future<String?> reloadUser() async => null;
  Future<String?> sendPasswordReset(String email) async => null;
  Future<String?> signInWithGoogle() async => null;
  Future<String?> reauthenticateForAccountDeletion({String? password}) async =>
      null;
  Future<String?> deleteCurrentAccount() async => null;
  Future<void> signOut() async {}
}
