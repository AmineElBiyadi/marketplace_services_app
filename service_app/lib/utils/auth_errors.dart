import 'package:firebase_auth/firebase_auth.dart';

/// Converts any Firebase or generic exception into a user-friendly French message.
String friendlyAuthError(dynamic error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      // ── Email ──
      case 'email-already-in-use':
        return 'Cet email est déjà associé à un compte.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'user-not-found':
        return 'Aucun compte trouvé avec cet identifiant.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Identifiant ou mot de passe incorrect.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      case 'operation-not-allowed':
        return "Cette méthode de connexion n'est pas activée.";
      case 'weak-password':
        return 'Mot de passe trop faible (minimum 6 caractères).';
      case 'requires-recent-login':
        return 'Veuillez vous reconnecter avant de continuer.';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion internet.';

      // ── Phone / OTP ──
      case 'invalid-verification-code':
        return 'Code de vérification incorrect.';
      case 'invalid-verification-id':
        return 'Session expirée. Veuillez renvoyer le code.';
      case 'session-expired':
        return 'Le code a expiré. Veuillez en demander un nouveau.';
      case 'invalid-phone-number':
        return 'Numéro de téléphone invalide.';
      case 'missing-phone-number':
        return 'Veuillez entrer un numéro de téléphone.';
      case 'quota-exceeded':
        return 'Limite de SMS atteinte. Réessayez plus tard.';
      case 'code-expired':
        return 'Le code OTP a expiré. Veuillez en redemander un.';

      // ── Google / providers ──
      case 'account-exists-with-different-credential':
        return 'Un compte existe déjà avec cet email mais une autre méthode de connexion.';
      case 'credential-already-in-use':
        return 'Ces identifiants sont déjà associés à un compte existant.';

      default:
        return 'Une erreur est survenue. Veuillez réessayer.';
    }
  }

  // Generic fallback — hide technical details
  final msg = error.toString().toLowerCase();
  if (msg.contains('network') || msg.contains('socket')) {
    return 'Erreur réseau. Vérifiez votre connexion internet.';
  }
  if (msg.contains('timeout')) {
    return 'La requête a expiré. Réessayez.';
  }
  if (msg.contains('permission') || msg.contains('denied')) {
    return 'Permission refusée. Contactez le support.';
  }
  return 'Une erreur inattendue est survenue. Réessayez.';
}
