import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // await _authService.sendPasswordResetEmail(_emailCtrl.text); // Old logic disabled
      setState(() => _emailSent = true);
    } on FirebaseAuthException catch (e) {
      _showSnack(_authService.getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: _emailSent ? _buildSuccessState() : _buildFormState(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: Color(0xFF818CF8),
            size: 28,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Reset password',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter your email and we'll send you a link to reset your password.",
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 36),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                  hintStyle: const TextStyle(color: Color(0xFF475569)),
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFFEF4444), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF4B4F8F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Send Reset Link',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF064E3B),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: Color(0xFF10B981), size: 40),
        ),
        const SizedBox(height: 28),
        const Text(
          'Check your inbox',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a reset link to\n${_emailCtrl.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Back to Sign In',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _sendReset,
          child: const Text(
            "Didn't receive it? Resend",
            style: TextStyle(color: Color(0xFF818CF8)),
          ),
        ),
      ],
    );
  }
}