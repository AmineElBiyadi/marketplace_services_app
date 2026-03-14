import 'package:firebase_auth/firebase_auth.dart';
// import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── Stream ────────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  // ─── Google Sign-In ────────────────────────────────────────
  // Future<UserCredential?> signInWithGoogle() async {
  //   final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
  //   if (googleUser == null) return null;

  //   final GoogleSignInAuthentication googleAuth =
  //       await googleUser.authentication;

  //   final credential = GoogleAuthProvider.credential(
  //     accessToken: googleAuth.accessToken,
  //     idToken: googleAuth.idToken,
  //   );

  //   return await _auth.signInWithCredential(credential);
  // }

  // ─── Phone Number ──────────────────────────────────────────
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onVerificationCompleted,
    required void Function(FirebaseAuthException) onVerificationFailed,
    required void Function(String, int?) onCodeSent,
    required void Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> linkPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.currentUser!.linkWithCredential(credential);
  }

  // ─── Email / Password ──────────────────────────────────────

  /// Creates a new Firebase Auth account with email + password and sends
  /// a verification email. Used during client/provider email-based signup.
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.sendEmailVerification();
    return cred.user;
  }

  /// Creates a proxy Firebase Auth account for phone-only users.
  /// The proxy email is derived from the phone number and is never shown to the user.
  /// This allows phone users to also set a password (needed for login + password reset).
  Future<User?> signUpWithPhoneProxy({
    required String phone,
    required String password,
  }) async {
    final normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
    final proxyEmail = '$normalized@proxy.marketplace.app';
    final cred = await _auth.createUserWithEmailAndPassword(
      email: proxyEmail,
      password: password,
    );
    return cred.user;
  }

  /// Signs in with email + password (for email-based users).
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs in using the proxy email derived from the phone number.
  Future<UserCredential> signInWithPhoneProxy({
    required String phone,
    required String password,
  }) async {
    final normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
    final proxyEmail = '$normalized@proxy.marketplace.app';
    return await _auth.signInWithEmailAndPassword(
      email: proxyEmail,
      password: password,
    );
  }

  Future<bool> checkEmailVerified() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return user.emailVerified;
    }
    return false;
  }

  /// Sends a real Firebase password-reset email.
  /// For phone-only users (proxy email), this is a no-op and returns false.
  Future<bool> sendPasswordResetEmail(String email) async {
    if (email.contains('@proxy.marketplace.app')) return false;
    await _auth.sendPasswordResetEmail(email: email);
    return true;
  }

  // ─── Sign Out ──────────────────────────────────────────────
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      // _googleSignIn.signOut(),
    ]);
  }

  // ─── Error Helper ──────────────────────────────────────────
  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet identifiant.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mot de passe incorrect. Veuillez réessayer.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet email.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'weak-password':
        return 'Le mot de passe doit comporter au moins 6 caractères.';
      case 'too-many-requests':
        return 'Trop de tentatives. Veuillez réessayer plus tard.';
      case 'invalid-verification-code':
        return 'Code OTP invalide. Veuillez réessayer.';
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide.';
      default:
        return e.message ?? 'Une erreur inattendue s\'est produite.';
    }
  }
}