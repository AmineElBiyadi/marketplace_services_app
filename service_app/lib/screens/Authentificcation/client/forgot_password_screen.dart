import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  int _step = 0;
  bool _isLoading = false;
  String _sentTo = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final input = _emailCtrl.text.trim();
    if (input.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final info = await _firestoreService.getUserContactInfo(input);

      if (info == null || info.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No account found with this identifier.'),
            backgroundColor: Color(0xFFEF4444),
          ));
        }
        return;
      }

      final hasEmail = info.containsKey('email');
      final hasPhone = info.containsKey('phone');

      if (hasEmail && hasPhone) {
        if (mounted) {
          _showRecoveryOptionsModal(info['email']!, info['phone']!);
        }
      } else if (hasEmail) {
        await _triggerEmailRecovery(info['email']!);
      } else if (hasPhone) {
        await _triggerPhoneRecovery(info['phone']!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRecoveryOptionsModal(String email, String phone) {
    // Obscure email (e.g. amine@gmail.com -> a***e@gmail.com)
    final emailParts = email.split('@');
    final obscuredEmail = emailParts[0].length > 2 
      ? '${emailParts[0].substring(0, 1)}***${emailParts[0].substring(emailParts[0].length - 1)}@${emailParts[1]}'
      : '***@${emailParts[1]}';
      
    // Obscure phone (e.g. +212612345678 -> +212 ***-**5678)
    final obscuredPhone = phone.length > 5 
      ? '${phone.substring(0, 4)} ***-**${phone.substring(phone.length - 4)}'
      : '***';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose recovery method',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Where should we send the reset instructions?',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.email_outlined, color: Color(0xFF3F64B5)),
                ),
                title: const Text('Send Email', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
                subtitle: Text(obscuredEmail, style: const TextStyle(color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(context);
                  _triggerEmailRecovery(email);
                },
              ),
              const Divider(height: 32),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.phone_iphone_outlined, color: Color(0xFF3F64B5)),
                ),
                title: const Text('Send SMS Code', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A237E))),
                subtitle: Text(obscuredPhone, style: const TextStyle(color: Color(0xFF64748B))),
                onTap: () {
                  Navigator.pop(context);
                  _triggerPhoneRecovery(phone);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _triggerEmailRecovery(String email) async {
    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        setState(() {
          _sentTo = email;
          _step = 1;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_authService.getErrorMessage(e)),
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _triggerPhoneRecovery(String phone) async {
    setState(() => _isLoading = true);
    await _authService.verifyPhoneNumber(
      phoneNumber: phone,
      onVerificationCompleted: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
      onVerificationFailed: (e) {
        if (mounted) setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_authService.getErrorMessage(e)),
            backgroundColor: const Color(0xFFEF4444),
          ));
        }
      },
      onCodeSent: (verificationId, _) {
        if (mounted) setState(() => _isLoading = false);
        if (mounted) {
          context.push('/otp', extra: {
            'method': 'reset_password',
            'verificationId': verificationId,
            'phone': phone,
          });
        }
      },
      onCodeAutoRetrievalTimeout: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // ── Back arrow ──
              IconButton(
                onPressed: () {
                  if (_step > 0) {
                    setState(() {
                      _step = 0;
                      _sentTo = '';
                    });
                  } else {
                    context.canPop() ? context.pop() : context.go('/login');
                  }
                },
                icon: const Icon(Icons.arrow_back,
                    color: Color(0xFF1A237E), size: 24),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _step == 0 ? _buildInputStep() : _buildConfirmationStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 0: Enter email or phone ──────────────────────────

  Widget _buildInputStep() {
    return Column(
      key: const ValueKey('input'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reset Password',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter your email or phone number',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
          decoration: InputDecoration(
            hintText: 'Email or phone number',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFADB5C7)),
            prefixIcon: const Icon(Icons.person_outline,
                color: Color(0xFFADB5C7), size: 20),
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
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _emailCtrl.text.isNotEmpty && !_isLoading
                ? _sendReset
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _emailCtrl.text.isNotEmpty
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
                    'Send Link',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Step 1: Confirmation ──────────────────────────────────

  Widget _buildConfirmationStep() {
    final isEmail = _sentTo.contains('@');
    return Column(
      key: const ValueKey('confirm'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(45),
          ),
          child: Icon(
            isEmail
                ? Icons.mark_email_read_outlined
                : Icons.phone_android_outlined,
            size: 44,
            color: const Color(0xFF3F64B5),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          isEmail ? 'Check your email' : 'Check your phone',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isEmail
              ? 'A reset link has been sent to\n$_sentTo\n\nClick the link in the email to create a new password.'
              : 'Your account has been verified.\nContact support to reset your password by phone.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F64B5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: const Text(
              'Back to Login',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ),
        if (isEmail) ...[
          const SizedBox(height: 12),
          TextButton(
            onPressed: _sendReset,
            child: const Text(
              "Resend email",
              style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF3F64B5),
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}
