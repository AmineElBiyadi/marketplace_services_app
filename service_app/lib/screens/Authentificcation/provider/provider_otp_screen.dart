import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/glass_container.dart';
import '../../../widgets/custom_button.dart';

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';

class ProviderOTPScreen extends StatefulWidget {
  final Map<String, dynamic>? extraData;
  const ProviderOTPScreen({super.key, this.extraData});

  @override
  State<ProviderOTPScreen> createState() => _ProviderOTPScreenState();
}

class _ProviderOTPScreenState extends State<ProviderOTPScreen> {
  final _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  String _otp = "";
  
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _isLoading = false;
  Timer? _emailVerificationTimer;

  @override
  void initState() {
    super.initState();
    if (widget.extraData?['method'] == 'email') {
      _startEmailVerificationPolling();
    }
  }

  void _startEmailVerificationPolling() {
    _emailVerificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      final isVerified = await _authService.checkEmailVerified();
      if (isVerified) {
        timer.cancel();
        _finalizeRegistration();
      }
    });
  }

  Future<void> _finalizeRegistration() async {
    setState(() => _isLoading = true);
    try {
      if (widget.extraData == null) throw Exception('Missing registration data');
      
      await _firestoreService.registerProvider(
        name: widget.extraData!['name'],
        phone: widget.extraData!['phone'],
        email: widget.extraData!['email'],
        serviceIds: List<String>.from(widget.extraData!['serviceIds'] ?? []),
        description: widget.extraData!['description'],
        zone: widget.extraData!['zone'],
        cinFrontBase64: widget.extraData!['cinFront'],
        cinBackBase64: widget.extraData!['cinBack'],
        certificateBase64: widget.extraData!['certificate'],
      );

      if (mounted) {
        context.go('/provider/pending');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    setState(() => _isLoading = true);
    try {
      await _authService.linkPhoneCredential(
        verificationId: widget.extraData!['verificationId'],
        smsCode: _otp,
      );
      await _finalizeRegistration();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_authService.getErrorMessage(e))),
        );
      }
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    _updateOtp();
  }

  void _updateOtp() {
    _otp = _otpControllers.map((c) => c.text).join();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.pushReplacement('/provider/login');
                  }
                },
                icon: const Icon(Icons.arrow_back),
                color: AppColors.textPrimary,
              ),
              const Spacer(),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      "📱",
                      style: TextStyle(fontSize: 40),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Vérification SMS",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Entrez le code de vérification envoyé à votre numéro de téléphone",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              if (widget.extraData?['method'] == 'email')
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        "En attente de votre vérification...",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          // Allow resending email or switching back setup
                        },
                        child: Text(
                          "Didn't receive the email? Resend",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          return Container(
                            width: 48,
                            height: 56,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: GlassContainer(
                              padding: EdgeInsets.zero,
                              child: TextField(
                                controller: _otpControllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  counterText: "",
                                  border: InputBorder.none,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) => _onOtpChanged(index, value),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: _isLoading ? "Chargement..." : "Vérifier",
                        onPressed: _otp.length == 6 && !_isLoading
                            ? _verifyOTP
                            : null,
                        disabled: _otp.length < 6 || _isLoading,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            "Renvoyer le code",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailVerificationTimer?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}
