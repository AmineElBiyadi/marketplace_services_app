import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../utils/auth_errors.dart';
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
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());

  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  bool _isLoading = false;
  bool _emailVerified = false;
  Timer? _emailPollingTimer;

  bool get _isEmailMethod => widget.extraData?['method'] == 'email';
  bool get _isFilled => _otp.every((d) => d.isNotEmpty);

  @override
  void initState() {
    super.initState();
    if (_isEmailMethod) _startEmailPolling();
  }

  void _startEmailPolling() {
    _emailPollingTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      final isVerified = await _authService.checkEmailVerified();
      if (isVerified) {
        timer.cancel();
        setState(() => _emailVerified = true);
        await _finalizeRegistration();
      }
    });
  }

  @override
  void dispose() {
    _emailPollingTimer?.cancel();
    for (var n in _focusNodes) { n.dispose(); }
    for (var c in _controllers) { c.dispose(); }
    super.dispose();
  }

  void _handleChange(int index, String value) {
    if (value.length > 1) return;
    setState(() => _otp[index] = value);
    if (value.isNotEmpty && index < 5) { _focusNodes[index + 1].requestFocus(); }
  }

  void _handleKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otp[index].isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    if (!_isFilled || widget.extraData == null) return;
    setState(() => _isLoading = true);
    try {
      await _authService.linkPhoneCredential(
        verificationId: widget.extraData!['verificationId'],
        smsCode: _otp.join(),
      );
      await _finalizeRegistration();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyAuthError(e)),
          backgroundColor: AppColors.destructive,
        ));
      }
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizeRegistration() async {
    setState(() => _isLoading = true);
    final role = widget.extraData!['role'];
    try {
      if (role == 'client') {
        // Reconstruct GeoPoint from extraData if available
        GeoPoint? geoPoint;
        final lat = widget.extraData!['lat'];
        final lng = widget.extraData!['lng'];
        if (lat != null && lng != null) {
          geoPoint = GeoPoint((lat as num).toDouble(), (lng as num).toDouble());
        }

        final uid = await _firestoreService.registerClient(
          name: widget.extraData!['name'],
          phone: widget.extraData!['phone'],
          email: widget.extraData!['email'],
          rue: widget.extraData!['address']?['rue'],
          numBatiment: widget.extraData!['address']?['numBatiment'],
          quartier: widget.extraData!['address']?['quartier'],
          ville: widget.extraData!['address']?['ville'],
          codePostal: widget.extraData!['address']?['codePostal'],
          pays: widget.extraData!['address']?['pays'],
          location: geoPoint,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_client_id', uid);
        if (mounted) context.go('/home');
      } else if (role == 'provider') {
        await _firestoreService.registerProvider(
          name: widget.extraData!['name'],
          phone: widget.extraData!['phone'],
          email: widget.extraData!['email'],
          serviceIds: List<String>.from(widget.extraData!['serviceIds'] ?? []),
          description: widget.extraData!['description'] ?? '',
          zone: widget.extraData!['zone'] ?? '',
          cinFrontBase64: widget.extraData!['cinFront'] ?? '',
          cinBackBase64: widget.extraData!['cinBack'] ?? '',
          certificateBase64: widget.extraData!['certificate'] ?? '',
        );
        if (mounted) context.go('/provider/pending');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyAuthError(e)),
          backgroundColor: AppColors.destructive,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        try {
          await FirebaseAuth.instance.currentUser?.delete();
        } catch (_) {}
        if (context.mounted) {
          context.canPop() ? context.pop() : context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                IconButton(
                  onPressed: () async {
                    try {
                      await FirebaseAuth.instance.currentUser?.delete();
                    } catch (_) {}
                    if (context.mounted) {
                      context.canPop() ? context.pop() : context.go('/login');
                    }
                  },
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF1A237E), size: 24),
                  padding: EdgeInsets.zero,
                ),
              const SizedBox(height: 20),
              // ── Title ──
              Text(
                _isEmailMethod ? 'Vérifiez votre email' : 'Verify your number',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isEmailMethod
                    ? 'Un lien de vérification a été envoyé à\n${widget.extraData?['email'] ?? ''}'
                    : 'Entrez le code à 6 chiffres envoyé à votre téléphone',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF64748B), height: 1.5),
              ),
              const SizedBox(height: 40),

              // ── Email waiting state ──
              if (_isEmailMethod) ...[
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: _emailVerified
                            ? const Icon(Icons.check_circle_rounded,
                                size: 52, color: Color(0xFF10B981))
                            : const Icon(Icons.mark_email_unread_outlined,
                                size: 52, color: Color(0xFF3F64B5)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _emailVerified
                            ? 'Email vérifié ! Redirection...'
                            : 'En attente de votre vérification...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _emailVerified
                              ? const Color(0xFF10B981)
                              : const Color(0xFF3F64B5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_emailVerified) ...[
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Color(0xFF3F64B5),
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            "Renvoyer l'email",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3F64B5)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ]

              // ── SMS OTP state ──
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 48,
                      height: 56,
                      margin: EdgeInsets.only(right: index < 5 ? 10 : 0),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (e) => _handleKey(index, e),
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A237E),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFFCBD5E1), width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: Color(0xFF3F64B5), width: 2),
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (v) => _handleChange(index, v),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isFilled && !_isLoading ? _verifyOtp : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFilled
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
                            'Vérifier',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Vous n'avez pas reçu le code ? ",
                          style: TextStyle(
                              fontSize: 14, color: Color(0xFF64748B))),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Renvoyer',
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
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}
