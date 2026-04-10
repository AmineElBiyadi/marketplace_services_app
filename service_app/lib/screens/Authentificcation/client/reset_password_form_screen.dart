import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_colors.dart';

class ResetPasswordFormScreen extends StatefulWidget {
  const ResetPasswordFormScreen({super.key});

  @override
  State<ResetPasswordFormScreen> createState() => _ResetPasswordFormScreenState();
}

class _ResetPasswordFormScreenState extends State<ResetPasswordFormScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  void _submit() async {
    final newPass = _passwordCtrl.text;
    if (newPass.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (newPass != _confirmCtrl.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated. Please verify OTP again.');
      
      await user.updatePassword(newPass);
      
      // Successfully updated password
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password updated successfully! Please login with your new password.'),
          backgroundColor: Colors.green,
        ));
        
        // Log them out so they can log in fully (setting shared preferences etc.)
        await FirebaseAuth.instance.signOut();
        if (mounted) context.go('/login');
      }
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'An error occurred.');
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final isValid = _passwordCtrl.text.isNotEmpty && _confirmCtrl.text.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A237E)),
          onPressed: () {
            // If they cancel, log them out
            FirebaseAuth.instance.signOut();
            context.go('/login');
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter New Password',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please enter a new password for your account.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 32),
              
              // New Password
              TextField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
                decoration: InputDecoration(
                  hintText: 'New Password',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFADB5C7)),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFADB5C7), size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 20),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFF3F64B5), width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm Password
              TextField(
                controller: _confirmCtrl,
                obscureText: !_showConfirm,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
                decoration: InputDecoration(
                  hintText: 'Confirm Password',
                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFADB5C7)),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFADB5C7), size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 20),
                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFF3F64B5), width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Submit
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isValid && !_isLoading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? const Color(0xFF3F64B5) : const Color(0xFF94A3B8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
