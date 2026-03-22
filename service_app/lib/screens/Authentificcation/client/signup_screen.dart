import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/location_service.dart';
import '../../../utils/auth_errors.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // ── Step ──────────────────────────────────────────────────────
  int _step = 1; // 1 = account info, 2 = address

  // ── Step 1 controllers ────────────────────────────────────────
  final _nameController    = TextEditingController();
  final _phoneController   = TextEditingController();
  final _emailController   = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  // ── Step 2 controllers ────────────────────────────────────────
  final _rueController         = TextEditingController();
  final _numBatCtrl            = TextEditingController();
  final _quartierController    = TextEditingController();
  final _villeController       = TextEditingController();
  final _codePostalController  = TextEditingController();
  final _paysController        = TextEditingController(text: 'Maroc');

  // ── Detected coords ───────────────────────────────────────────
  GeoPoint? _detectedGeoPoint;

  // ── Services ──────────────────────────────────────────────────
  final _authService      = AuthService();
  final _firestoreService = FirestoreService();
  final _locationService  = LocationService();

  // ── UI State ──────────────────────────────────────────────────
  bool _showPassword   = false;
  bool _showConfirm    = false;
  bool _agreed         = false;
  bool _isLoading      = false;
  bool _detectingLoc   = false;

  bool get _step1Valid {
    final hasContact = _phoneController.text.isNotEmpty ||
        _emailController.text.isNotEmpty;
    return _nameController.text.isNotEmpty &&
        hasContact &&
        _passwordController.text.length >= 6 &&
        _passwordController.text == _confirmController.text &&
        _agreed;
  }

  bool get _step2Valid =>
      _villeController.text.isNotEmpty && _quartierController.text.isNotEmpty;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _rueController.dispose();
    _numBatCtrl.dispose();
    _quartierController.dispose();
    _villeController.dispose();
    _codePostalController.dispose();
    _paysController.dispose();
    super.dispose();
  }

  // ── Detect Location ───────────────────────────────────────────
  Future<void> _detectLocation() async {
    setState(() => _detectingLoc = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos == null) {
        _showError('Impossible de détecter la localisation.');
        return;
      }

      setState(() {
        _detectedGeoPoint = GeoPoint(pos.latitude, pos.longitude);
      });

      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          setState(() {
            // We only fill reliable information. We don't touch NumBatiment.
            if (p.street != null && p.street!.isNotEmpty) _rueController.text = p.street!;
            if (p.subLocality != null && p.subLocality!.isNotEmpty) {
              _quartierController.text = p.subLocality!;
            } else if (p.locality != null && p.locality!.isNotEmpty) {
               _quartierController.text = p.locality!;
            }
            if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
              _villeController.text = p.administrativeArea!;
            } else if (p.locality != null && p.locality!.isNotEmpty) {
              _villeController.text = p.locality!;
            }
            if (p.postalCode != null && p.postalCode!.isNotEmpty) _codePostalController.text = p.postalCode!;
            if (p.country != null && p.country!.isNotEmpty) _paysController.text = p.country!;
          });
        }
      } catch (e) {
        // Geocoding failed (common on emulator without Play Services).
        // We do absolutely nothing here because the GPS coordinates were already saved successfully.
      }
      
      // Show success instead of error!
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Position GPS détectée avec succès !'),
          backgroundColor: Colors.green,
        ));
      }

    } catch (e) {
      _showError('Erreur de localisation: $e');
    } finally {
      if (mounted) setState(() => _detectingLoc = false);
    }
  }

  // ── Geocode address to GeoPoint ───────────────────────────────
  Future<GeoPoint?> _geocodeAddress() async {
    try {
      final address =
          '${_numBatCtrl.text} ${_rueController.text}, ${_quartierController.text}, ${_villeController.text}, ${_paysController.text}';
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return GeoPoint(locations.first.latitude, locations.first.longitude);
      }
    } catch (_) {}
    return null;
  }

  // ── Signup ────────────────────────────────────────────────────
  Future<void> _handleSignup() async {
    if (!_step1Valid) return;
    setState(() => _isLoading = true);

    try {
      final hasPhone = _phoneController.text.trim().isNotEmpty;
      final hasEmail = _emailController.text.trim().isNotEmpty;

      String phoneToCheck = _phoneController.text.trim();
      if (hasPhone && !phoneToCheck.startsWith('+')) {
        if (phoneToCheck.startsWith('0')) {
          phoneToCheck = '+212${phoneToCheck.substring(1)}';
        } else {
          phoneToCheck = '+$phoneToCheck';
        }
      }

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

      // Geocode address if not already detected
      GeoPoint? addressGeoPoint = _detectedGeoPoint ?? await _geocodeAddress();

      // Build address data map  
      final addressData = _step2Valid ? {
        'rue':        _rueController.text.trim(),
        'numBatiment': _numBatCtrl.text.trim(),
        'quartier':   _quartierController.text.trim(),
        'ville':      _villeController.text.trim(),
        'codePostal': _codePostalController.text.trim(),
        'pays':       _paysController.text.trim(),
        if (addressGeoPoint != null) 'geoPoint': addressGeoPoint,
      } : null;

      final extraData = {
        'name':    _nameController.text.trim(),
        'phone':   _phoneController.text.trim(),
        'email':   _emailController.text.trim(),
        'role':    'client',
        if (addressData != null) 'address': addressData,
        if (addressGeoPoint != null) 'lat': addressGeoPoint.latitude,
        if (addressGeoPoint != null) 'lng': addressGeoPoint.longitude,
      };

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
      } else if (hasEmail) {
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

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
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
                onPressed: () {
                  if (_step == 2) {
                    setState(() => _step = 1);
                  } else {
                    context.canPop() ? context.pop() : context.go('/welcome');
                  }
                },
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1A237E), size: 24),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              // ── Logo ──
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 70,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 70),
                ),
              ),
              const SizedBox(height: 16),
              // ── Step indicator ──
              _buildStepIndicator(),
              const SizedBox(height: 20),

              if (_step == 1) ..._buildStep1(),
              if (_step == 2) ..._buildStep2(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step indicator ─────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(1, 'Compte'),
        Expanded(child: Divider(
          color: _step >= 2 ? AppColors.primary : Colors.grey.shade300,
          thickness: 2,
        )),
        _stepDot(2, 'Adresse'),
      ],
    );
  }

  Widget _stepDot(int n, String label) {
    final active = _step >= n;
    return Column(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.primary : Colors.grey.shade300,
          ),
          child: Center(
            child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: active ? AppColors.primary : Colors.grey)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  STEP 1 — Account Info
  // ─────────────────────────────────────────────────────────────
  List<Widget> _buildStep1() => [
    const Text('Créez votre compte', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
    const SizedBox(height: 4),
    const Text('Rejoignez des milliers de clients satisfaits', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
    const SizedBox(height: 24),
    _field(_nameController, 'Nom complet', icon: Icons.person_outline),
    const SizedBox(height: 14),
    _field(_phoneController, 'Numéro de téléphone', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
    const SizedBox(height: 14),
    _field(_emailController, 'Email (optionnel)', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
    const SizedBox(height: 14),
    _field(_passwordController, 'Mot de passe',
        icon: Icons.lock_outline,
        obscure: !_showPassword,
        suffix: IconButton(
          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 20),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        )),
    const SizedBox(height: 14),
    _field(_confirmController, 'Confirmer le mot de passe',
        icon: Icons.lock_outline,
        obscure: !_showConfirm,
        suffix: IconButton(
          icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 20),
          onPressed: () => setState(() => _showConfirm = !_showConfirm),
        )),
    const SizedBox(height: 16),
    // Terms
    Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24, height: 24,
          child: Checkbox(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            activeColor: AppColors.primary,
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              children: [
                TextSpan(text: "J'accepte les "),
                TextSpan(text: 'Conditions générales', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                TextSpan(text: ' et la '),
                TextSpan(text: 'Politique de confidentialité', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    ),
    const SizedBox(height: 24),
    // Next button
    SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton(
        onPressed: _step1Valid ? () => setState(() => _step = 2) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _step1Valid ? const Color(0xFF3F64B5) : const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        child: const Text('Suivant →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    ),
    const SizedBox(height: 16),
    Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Déjà un compte ? ', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          GestureDetector(
            onTap: () => context.go('/login'),
            child: const Text('Se connecter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF3F64B5))),
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),
  ];

  // ─────────────────────────────────────────────────────────────
  //  STEP 2 — Address
  // ─────────────────────────────────────────────────────────────
  List<Widget> _buildStep2() => [
    const Text('Votre adresse', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
    const SizedBox(height: 4),
    const Text('Pour trouver les experts près de vous', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
    const SizedBox(height: 20),

    // Detect location button
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _detectingLoc ? null : _detectLocation,
        icon: _detectingLoc
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location, size: 18),
        label: Text(_detectingLoc ? 'Détection...' : '📍 Détecter ma position actuelle'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ),
    if (_detectedGeoPoint != null)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 6),
            Text(
              'Position détectée (${_detectedGeoPoint!.latitude.toStringAsFixed(4)}, ${_detectedGeoPoint!.longitude.toStringAsFixed(4)})',
              style: const TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ),
      ),
    const SizedBox(height: 16),
    const Divider(),
    const SizedBox(height: 8),
    const Text('Ou saisissez manuellement', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
    const SizedBox(height: 12),

    Row(children: [
      Expanded(child: _field(_numBatCtrl, 'Nº Bâtiment', icon: Icons.home_outlined)),
      const SizedBox(width: 10),
      Expanded(flex: 2, child: _field(_rueController, 'Rue', icon: Icons.map_outlined)),
    ]),
    const SizedBox(height: 12),
    _field(_quartierController, 'Quartier *', icon: Icons.location_city_outlined),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: _field(_villeController, 'Ville *', icon: Icons.location_on_outlined)),
      const SizedBox(width: 10),
      Expanded(child: _field(_codePostalController, 'Code Postal', icon: Icons.markunread_mailbox_outlined, keyboardType: TextInputType.number)),
    ]),
    const SizedBox(height: 12),
    _field(_paysController, 'Pays', icon: Icons.flag_outlined),
    const SizedBox(height: 8),
    Text('* Champs obligatoires', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    const SizedBox(height: 24),

    // S'inscrire button
    SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton(
        onPressed: _step2Valid && !_isLoading ? _handleSignup : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _step2Valid ? const Color(0xFF3F64B5) : const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text("S'inscrire", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    ),
    // Skip option
    Center(
      child: TextButton(
        onPressed: _isLoading ? null : _handleSignup,
        child: const Text('Passer cette étape', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
      ),
    ),
    const SizedBox(height: 24),
  ];

  // ── Text field helper ──────────────────────────────────────────
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
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFFADB5C7), size: 20) : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Color(0xFF3F64B5), width: 1.6),
        ),
      ),
    );
  }
}
