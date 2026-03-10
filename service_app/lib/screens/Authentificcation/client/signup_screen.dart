import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';


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
  bool _agreed = false;
  bool _isLoading = false;

  bool get _isValid {
    final hasContact = _phoneController.text.isNotEmpty || _emailController.text.isNotEmpty;
    return _nameController.text.isNotEmpty &&
        hasContact &&
        _passwordController.text.isNotEmpty &&
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

      // --- Pre-validation Check ---
      String phoneToCheck = _phoneController.text.trim();
      if (hasPhone) {
        if (!phoneToCheck.startsWith('+')) {
          if (phoneToCheck.startsWith('0')) {
            phoneToCheck = '+212${phoneToCheck.substring(1)}';
          } else {
            phoneToCheck = '+$phoneToCheck';
          }
        }
      }

      final duplicateField = await _firestoreService.checkUserExists(
        phone: phoneToCheck,
        email: _emailController.text.trim(),
      );

      if (duplicateField != null) {
        setState(() => _isLoading = false);
        if (mounted) {
          final msg = duplicateField == 'phone'
              ? 'Ce numéro de téléphone est déjà utilisé.'
              : 'Cet email est déjà utilisé.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.destructive,
            ),
          );
        }
        return;
      }
      // ----------------------------

      // "if he enter both thene verify whith number"
      final usePhone = hasPhone;

      if (usePhone) {

        await _authService.verifyPhoneNumber(
          phoneNumber: phoneToCheck,
          onVerificationCompleted: (credential) {
            setState(() => _isLoading = false);
          },
          onVerificationFailed: (Exception e) {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: ${e.toString()}')),
              );
            }
          },
          onCodeSent: (String verificationId, int? resendToken) {
            setState(() => _isLoading = false);
            if (mounted) {
              context.push('/otp', extra: {
                'method': 'phone',
                'verificationId': verificationId,
                'name': _nameController.text.trim(),
                'phone': _phoneController.text.trim(),
                'email': _emailController.text.trim(),
                'password': _passwordController.text,
                'role': 'client',
              });
            }
          },
          onCodeAutoRetrievalTimeout: (String verificationId) {
            setState(() => _isLoading = false);
          },
        );
      } else if (hasEmail) {
        // Verify via Email
        await _authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text, // Safe to use the intended password here temporarily
        );
        setState(() => _isLoading = false);
        if (mounted) {
          context.push('/otp', extra: {
            'method': 'email',
            'name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'role': 'client',
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur inattendue: ${e.toString()}')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            IconButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.pushReplacement('/login');
                }
              },
              icon: const Icon(Icons.arrow_back, color: AppColors.foreground),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.construction,
                  size: 56,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Create your account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Join thousands of happy customers',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              hintText: 'Full name',
              controller: _nameController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              hintText: 'Phone number',
              keyboardType: TextInputType.phone,
              controller: _phoneController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              hintText: 'Email',
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              hintText: 'Password',
              obscureText: !_showPassword,
              controller: _passwordController,
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.mutedForeground,
                ),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            const SizedBox(height: 12),
            CustomTextField(
              hintText: 'Confirm password',
              obscureText: true,
              controller: _confirmController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: _isLoading ? 'Envoi du code...' : 'Sign up',
              height: 48,
              onPressed: _isValid && !_isLoading ? _handleSignup : null,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account? ',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: const Text(
                    'Log in',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
