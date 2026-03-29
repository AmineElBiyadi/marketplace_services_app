import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../utils/auth_errors.dart';
import '../../../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProviderLoginScreen extends StatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  State<ProviderLoginScreen> createState() => _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends State<ProviderLoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _showPassword = false;
  bool _isLoading = false;

  bool get _isValid =>
      _identifierController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_isValid) return;
    setState(() => _isLoading = true);
    try {
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text;
      final isEmail = identifier.contains('@');

      if (isEmail) {
        await _authService.signInWithEmail(email: identifier, password: password);
      } else {
        String normalized = identifier;
        if (!normalized.startsWith('+')) {
          if (normalized.startsWith('0')) {
            normalized = '+212${normalized.substring(1)}';
          } else {
            normalized = '+$normalized';
          }
        }
        await _authService.signInWithPhoneProxy(phone: normalized, password: password);
      }

      final uid = _authService.currentUser!.uid;

      // Sync FCM Token for Notifications
      await NotificationService.updateUserToken(uid);

      final user = await _firestoreService.getProviderByUid(uid);

      if (user != null) {
        final expertId = user['expertId'] ?? '';
        final activeCgu = await _firestoreService.fetchActiveCGU('EXPERT');
        final acceptedVersion = user['acceptedCguVersion'] ?? 'none';
        final activeVersion = activeCgu?['version'] ?? '1.0';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_expert_id', expertId);
        if (mounted) {
          if (acceptedVersion != activeVersion) {
            context.go('/cgu_update', extra: {'role': 'EXPERT', 'uid': uid, 'cgu': activeCgu});
            return;
          }

          final etatCompte = user['etatCompte'] ?? 'PENDING';
          if (etatCompte == 'ACTIVE') {
            context.go('/provider/$expertId/dashboard');
          } else if (etatCompte == 'DESACTIVE' || etatCompte == 'SUSPENDUE') {
            context.go('/provider/deactivated');
          } else {
            context.go('/provider/pending');
          }
        }
      } else {
        // Signed in but not a provider — sign out and show error
        await _authService.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Identifiant ou mot de passe incorrect.'),
            backgroundColor: Color(0xFFEF4444),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyAuthError(e)),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // ── Back ──
              IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/welcome'),
                icon: const Icon(Icons.arrow_back,
                    color: Color(0xFF1A237E), size: 24),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),

              // ── Illustration ──
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 80,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(height: 80),
                ),
              ),
              const SizedBox(height: 20),

              // ── Heading ──
              Row(
                children: const [
                  Text(
                    'Espace Prestataire ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  Text('🔧', style: TextStyle(fontSize: 20)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Connectez-vous à votre compte pro',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 28),

              // ── Identifier field ──
              _field(
                _identifierController,
                'Email ou numéro de téléphone',
                icon: Icons.person_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              // ── Password field ──
              _field(
                _passwordController,
                'Mot de passe',
                icon: Icons.lock_outline,
                obscure: !_showPassword,
                suffix: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              const SizedBox(height: 10),

              // ── Forgot password ──
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => context.go('/forgot-password'),
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3F64B5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Login button ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isValid && !_isLoading ? _handleLogin : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid
                        ? const Color(0xFF3F64B5)
                        : const Color(0xFF94A3B8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Se connecter',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Signup link ──
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Pas encore de compte ? ",
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFF64748B))),
                    GestureDetector(
                      onTap: () => context.go('/provider/signup'),
                      child: const Text(
                        "S'inscrire",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3F64B5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 14, color: Color(0xFFADB5C7)),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFFADB5C7), size: 20)
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide:
              const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide:
              const BorderSide(color: Color(0xFF3F64B5), width: 1.6),
        ),
      ),
    );
  }
}
