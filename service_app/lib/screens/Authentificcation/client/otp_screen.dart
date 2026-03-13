import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/custom_button.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class OTPScreen extends StatefulWidget {
  final Map<String, dynamic>? extraData;
  const OTPScreen({super.key, this.extraData});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<String> _otp = ['', '', '', '', '', ''];
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _isLoading = false;
  Timer? _emailPollingTimer;

  bool get _isEmailMethod => widget.extraData?['method'] == 'email';

  bool get _isFilled => _otp.every((d) => d.isNotEmpty);

  @override
  void initState() {
    super.initState();
    if (_isEmailMethod) {
      _startEmailPolling();
    }
  }

  void _startEmailPolling() {
    _emailPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
       bool isVerified = await _authService.checkEmailVerified();
       if (isVerified) {
         timer.cancel();
         _finalizeRegistration();
       }
    });
  }

  @override
  void dispose() {
    _emailPollingTimer?.cancel();
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleChange(int index, String value) {
    if (value.length > 1) return;
    setState(() {
      _otp[index] = value;
    });
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    if (!_isFilled || widget.extraData == null) return;

    setState(() => _isLoading = true);
    
    final verificationId = widget.extraData!['verificationId'];
    final smsCode = _otp.join();

    try {
      // 1. Verify OTP with Firebase
      await _authService.signInWithPhone(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      // 2. Verified! Save into Firestore
      await _finalizeRegistration();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code invalide ou erreur: ${e.toString()}'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizeRegistration() async {
    setState(() => _isLoading = true);
    final role = widget.extraData!['role'];

    try {
      if (role == 'client') {
        final uid = await _firestoreService.registerClient(
          name: widget.extraData!['name'],
          phone: widget.extraData!['phone'],
          email: widget.extraData!['email'],
          password: widget.extraData!['password'],
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_client_id', uid);
        if (mounted) context.go('/home');
      } else if (role == 'provider') {
        await _firestoreService.registerProvider(
          name: widget.extraData!['name'],
          phone: widget.extraData!['phone'],
          email: widget.extraData!['email'],
          password: widget.extraData!['password'],
          category: widget.extraData!['category'] ?? '',
          description: widget.extraData!['description'] ?? '',
          zone: widget.extraData!['zone'] ?? '',
          cinFrontBase64: widget.extraData!['cinFront'] ?? '',
          cinBackBase64: widget.extraData!['cinBack'] ?? '',
          certificateBase64: widget.extraData!['certificate'] ?? '',
        );
        if (mounted) {
          // Navigation updated to go to pending screen before dashboard as per original flow
          context.go('/provider/pending');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _handleKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otp[index].isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
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
            const SizedBox(height: 24),
            Text(
              _isEmailMethod ? 'Vérifier votre email' : 'Verify your number',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isEmailMethod
                  ? 'Un lien de vérification a été envoyé à votre adresse email. Veuillez cliquer sur le lien pour vérifier votre compte.'
                  : 'Enter the 6-digit code sent to your phone',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 32),
            if (_isEmailMethod) ...[
              const Center(
                 child: CircularProgressIndicator(color: AppColors.primary),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'En attente de votre vérification...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                return Container(
                  width: 48,
                  height: 56,
                  margin: EdgeInsets.only(right: index < 5 ? 12 : 0),
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) => _handleKey(index, event),
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.card,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _handleChange(index, value),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: _isLoading ? 'Vérification...' : 'Verify',
              height: 48,
              onPressed: _isFilled && !_isLoading ? _verifyOtp : null,
              isLoading: _isLoading,
            ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Didn't receive the code? ",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    // Resend code
                  },
                  child: const Text(
                    'Resend',
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
