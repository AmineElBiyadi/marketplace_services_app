import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../utils/auth_errors.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _agreed = false;
  bool _isLoading = false;

  bool get _isValid {
    final hasContact = _phoneController.text.isNotEmpty ||
        _emailController.text.isNotEmpty;
    return _nameController.text.isNotEmpty &&
        hasContact &&
        _passwordController.text.length >= 6 &&
        _passwordController.text == _confirmController.text &&
        _agreed;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    if (!_isValid) return;
    setState(() => _isLoading = true);

    try {
      final hasPhone = _phoneController.text.trim().isNotEmpty;
      final hasEmail = _emailController.text.trim().isNotEmpty;

      // ── Normalize phone ──
      String phoneToCheck = _phoneController.text.trim();
      if (hasPhone && !phoneToCheck.startsWith('+')) {
        if (phoneToCheck.startsWith('0')) {
          phoneToCheck = '+212${phoneToCheck.substring(1)}';
        } else {
          phoneToCheck = '+$phoneToCheck';
        }
      }

      // ── Duplicate check ──
      final duplicateField = await _firestoreService.checkUserExists(
        phone: phoneToCheck,
        email: _emailController.text.trim(),
      );
      if (duplicateField != null) {
        setState(() => _isLoading = false);
        if (mounted) {
          _showError(duplicateField == 'phone'
              ? 'Ce numéro de téléphone est déjà utilisé.'
              : 'Cet email est déjà utilisé.');
        }
        return;
      }

      // extraData passed to OTP screen — no password (Firebase Auth handles it)
      final extraData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'role': 'client',
      };

      // ── If phone provided → create proxy Firebase Auth account then SMS OTP ──
      if (hasPhone) {
        await _authService.signUpWithPhoneProxy(
          phone: phoneToCheck,
          password: _passwordController.text,
        );
        await _authService.verifyPhoneNumber(
          phoneNumber: phoneToCheck,
          onVerificationCompleted: (_) => setState(() => _isLoading = false),
          onVerificationFailed: (e) {
            setState(() => _isLoading = false);
            if (mounted) _showError(friendlyAuthError(e));
          },
          onCodeSent: (verificationId, _) {
            setState(() => _isLoading = false);
            if (mounted) {
              context.push('/otp', extra: {
                ...extraData,
                'method': 'phone',
                'verificationId': verificationId,
              });
            }
          },
          onCodeAutoRetrievalTimeout: (_) =>
              setState(() => _isLoading = false),
        );
      }
      // ── If only email → Firebase email+password + verification email ──
      else if (hasEmail) {
        await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        setState(() => _isLoading = false);
        if (mounted) {
          context.push('/otp', extra: {...extraData, 'method': 'email'});
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showError(friendlyAuthError(e));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.destructive,
    ));
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
              // ── Back arrow ──
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/welcome'),
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
              const Text(
                'Créez votre compte',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rejoignez des milliers de clients satisfaits',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              // ── Fields ──
              _field(_nameController, 'Nom complet',
                  icon: Icons.person_outline),
              const SizedBox(height: 14),
              _field(_phoneController, 'Numéro de téléphone',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _field(_emailController, 'Email (optionnel)',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _field(_passwordController, 'Mot de passe',
                  icon: Icons.lock_outline,
                  obscure: !_showPassword,
                  suffix: IconButton(
                    icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  )),
              const SizedBox(height: 14),
              _field(_confirmController, 'Confirmer le mot de passe',
                  icon: Icons.lock_outline,
                  obscure: !_showConfirm,
                  suffix: IconButton(
                    icon: Icon(
                        _showConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  )),
              const SizedBox(height: 16),
              // ── Terms checkbox ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      activeColor: AppColors.primary,
                      side: const BorderSide(
                          color: Color(0xFFCBD5E1), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                            fontSize: 12.5, color: Color(0xFF64748B)),
                        children: [
                          TextSpan(text: "J'accepte les "),
                          TextSpan(
                            text: 'Conditions générales',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' et la '),
                          TextSpan(
                            text: 'Politique de confidentialité',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Sign up button ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isValid && !_isLoading ? _handleSignup : null,
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
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          "S'inscrire",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // ── Login link ──
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Déjà un compte ? ',
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFF64748B))),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'Se connecter',
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
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFADB5C7)),
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
