import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> signUp(
    String email,
    String password, {
    String firstName = '',
    String lastName = '',
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final displayName = [firstName, lastName]
        .where((s) => s.trim().isNotEmpty)
        .join(' ');
    if (displayName.isNotEmpty) {
      await credential.user!.updateDisplayName(displayName);
    }
    try {
      if (!credential.user!.emailVerified) {
        await credential.user!.sendEmailVerification();
      }
    } catch (e) {
      // Swallow – the verification screen handles resending.
    }
    return credential;
  }

  static Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    return await _auth.signOut();
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  static Future<void> sendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  static Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }
}
