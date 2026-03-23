import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/auth_errors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/location_service.dart';
import '../../shared/map_confirm_screen.dart';
import '../../../models/service.dart';

class ProviderSignupScreen extends StatefulWidget {
  const ProviderSignupScreen({super.key});

  @override
  State<ProviderSignupScreen> createState() => _ProviderSignupScreenState();
}

class _ProviderSignupScreenState extends State<ProviderSignupScreen> {
  int _step = 1;
  static const int _totalSteps = 3;

  // ── Step 1 ─────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _agreed = false;

  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _locationService = LocationService();
  bool _isLoading = false;
  String? _cguContent;
  String? _cguVersion;

  // Address fields
  final _villeController      = TextEditingController();
  final _paysController       = TextEditingController(text: 'Maroc');
  final _numBatController     = TextEditingController();
  final _rueController        = TextEditingController();
  final _quartierController   = TextEditingController();
  final _codePostalController = TextEditingController();

  GeoPoint? _confirmedGeoPoint;  // map-confirmed coordinate
  bool _detectingLoc = false;

  // ── Step 2 ─────────────────────────────────────────────────
  List<ServiceModel> _services = [];
  bool _isLoadingServices = false;
  final List<String> _selectedServiceIds = [];
  final _descriptionController = TextEditingController();
  final _zoneController = TextEditingController();

  // ── Step 3 ─────────────────────────────────────────────────
  String? _cinFrontName;
  Uint8List? _cinFrontBytes;
  String? _cinBackName;
  Uint8List? _cinBackBytes;
  String? _certificateName;
  Uint8List? _certificateBytes;
  final ImagePicker _picker = ImagePicker();

  // ── Validators ─────────────────────────────────────────────
  bool get _step1Valid {
    final hasContact = _phoneController.text.isNotEmpty ||
        _emailController.text.isNotEmpty;
    return _nameController.text.isNotEmpty &&
        hasContact &&
        _passwordController.text.length >= 6 &&
        _passwordController.text == _confirmController.text &&
        _agreed && _cguVersion != null;
  }

  bool get _step2Valid =>
      _selectedServiceIds.isNotEmpty &&
      _descriptionController.text.isNotEmpty &&
      _zoneController.text.isNotEmpty &&
      _villeController.text.isNotEmpty;

  bool get _step3Valid =>
      _cinFrontBytes != null &&
      _cinBackBytes != null &&
      _certificateBytes != null;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _fetchCgu();
  }

  Future<void> _fetchCgu() async {
    final cguData = await _firestoreService.fetchActiveCGU('EXPERT');
    if (cguData != null && mounted) {
      setState(() {
        _cguContent = cguData['content'];
        _cguVersion = cguData['version'];
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _descriptionController.dispose();
    _zoneController.dispose();
    _villeController.dispose();
    _paysController.dispose();
    _numBatController.dispose();
    _rueController.dispose();
    _quartierController.dispose();
    _codePostalController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    try {
      final services = await _firestoreService.getServices();
      if (mounted) setState(() => _services = services);
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _pickImage(Function(String, Uint8List) setter) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 30,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.length > 5000000) { // Increased to 5MB for Cloudinary
          if (mounted) _showError('Fichier trop volumineux (max ~5 Mo).');
          return;
        }
        setter(image.name, bytes);
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  Future<void> _pickDocument(Function(String, Uint8List) setter) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        if (bytes.length > 5000000) {
          if (mounted) _showError('Fichier trop volumineux (max ~5 Mo).');
          return;
        }
        setter(result.files.single.name, bytes);
        if (mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) _showError('Erreur: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.destructive,
    ));
  }

  // ── Nominatim reverse geocode ─────────────────────────────────
  Future<Map<String, String>?> _fallbackReverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1');
      final headers = kIsWeb ? <String, String>{} : {'User-Agent': 'service_app_amine/1.0'};
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data?['address'] != null) {
          final addr = data['address'];
          return {
            'locality': addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'] ?? '',
            'country': addr['country'] ?? 'Maroc',
          };
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Nominatim forward geocode ─────────────────────────────────
  Future<Map<String, double>?> _forwardGeocode(String query) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=$encoded&limit=1');
      final headers = kIsWeb ? <String, String>{} : {'User-Agent': 'service_app_amine/1.0'};
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat'].toString()),
            'lng': double.parse(data[0]['lon'].toString()),
          };
        }
      }
    } catch (_) {}
    return null;
  }

  // ── GPS Detection + Map Confirmation ─────────────────────────
  Future<void> _detectLocation() async {
    setState(() => _detectingLoc = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos == null) {
        _showError('Impossible de détecter la localisation.');
        return;
      }

      // Reverse geocode — city + country only
      String city = '';
      String country = 'Maroc';
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          city = p.administrativeArea ?? p.locality ?? '';
          country = p.country ?? 'Maroc';
        }
      } catch (_) {}

      if (city.isEmpty) {
        final fb = await _fallbackReverseGeocode(pos.latitude, pos.longitude);
        if (fb != null) {
          city = fb['locality'] ?? '';
          country = fb['country'] ?? 'Maroc';
        }
      }

      if (mounted) setState(() {
        if (city.isNotEmpty) _villeController.text = city;
        _paysController.text = country;
      });

      if (!mounted) return;
      final result = await Navigator.push<MapConfirmResult>(
        context,
        MaterialPageRoute(
          builder: (_) => MapConfirmScreen(
            initialLat: pos.latitude,
            initialLng: pos.longitude,
            initialCity: city,
            initialCountry: country,
          ),
        ),
      );
      if (result != null && mounted) {
        setState(() {
          _confirmedGeoPoint = result.geoPoint;
          if (result.city.isNotEmpty) _villeController.text = result.city;
          if (result.country.isNotEmpty) _paysController.text = result.country;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Position confirmée !'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) setState(() => _detectingLoc = false);
    }
  }

  void _handleSignup() async {
    if (!_step1Valid || !_step2Valid || !_step3Valid) return;
    setState(() => _isLoading = true);

    try {
      String phoneToCheck = _phoneController.text.trim();
      if (phoneToCheck.isNotEmpty && !phoneToCheck.startsWith('+')) {
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

      // Force map confirmation if no coordinates yet but city is filled
      GeoPoint? geoPoint = _confirmedGeoPoint;
      if (geoPoint == null && _villeController.text.isNotEmpty) {
        final city = _villeController.text.trim();
        final country = _paysController.text.trim();
        double lat = 31.7917;
        double lng = -7.0926;
        setState(() => _isLoading = false);
        final coords = await _forwardGeocode('$city, $country');
        if (coords != null) { lat = coords['lat']!; lng = coords['lng']!; }
        if (!mounted) return;
        final result = await Navigator.push<MapConfirmResult>(
          context,
          MaterialPageRoute(
            builder: (_) => MapConfirmScreen(
              initialLat: lat,
              initialLng: lng,
              initialCity: city,
              initialCountry: country,
              initialZoom: 11.0,
            ),
          ),
        );
        if (result == null) return; // User cancelled map confirm
        geoPoint = result.geoPoint;
        setState(() {
          _confirmedGeoPoint = geoPoint;
          _isLoading = true; // resume loading
        });
      }

      // extraData — no password sent to Firestore (Firebase Auth handles it)
      final extraData = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'serviceIds': _selectedServiceIds,
        'description': _descriptionController.text.trim(),
        'zone': _zoneController.text.trim(),
        'role': 'provider',
        'acceptedCguVersion': _cguVersion,
        'ville': _villeController.text.trim(),
        'pays': _paysController.text.trim(),
        'num_batiment': _numBatController.text.trim(),
        'rue': _rueController.text.trim(),
        'quartier': _quartierController.text.trim(),
        'code_postal': _codePostalController.text.trim(),
        'cinFront': _cinFrontBytes?.toList(), // Extra requires List<int> typically to survive GoRouter (or object if complex)
        'cinBack': _cinBackBytes?.toList(),
        'certificate': _certificateBytes?.toList(),
        if (geoPoint != null) 'lat': geoPoint.latitude,
        if (geoPoint != null) 'lng': geoPoint.longitude,
      };

      final hasPhone = _phoneController.text.trim().isNotEmpty;
      final hasEmail = _emailController.text.trim().isNotEmpty;

      if (hasPhone) {
        // Create proxy Firebase Auth account for phone user
        try {
          await _authService.signUpWithPhoneProxy(
            phone: phoneToCheck,
            password: _passwordController.text,
          );
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            throw Exception('Ce numéro de téléphone est déjà lié à un compte.');
          }
          rethrow;
        }
        await _authService.verifyPhoneNumber(
          phoneNumber: phoneToCheck,
          onVerificationCompleted: (_) =>
              setState(() => _isLoading = false),
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
          context.push('/otp',
              extra: {...extraData, 'method': 'email'});
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) _showError(friendlyAuthError(e));
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
              // ── Header ──
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      if (_step > 1) {
                        setState(() => _step--);
                      } else {
                        context.canPop()
                            ? context.pop()
                            : context.go('/welcome');
                      }
                    },
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF1A237E)),
                    padding: EdgeInsets.zero,
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _step / _totalSteps,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF3F64B5)),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_step/$_totalSteps',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ── Step content ──
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
              if (_step == 3) _buildStep3(),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // STEP 1 — Personal info
  // ══════════════════════════════════════════════════════════════
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _illustration(),
        const SizedBox(height: 20),
        const Text('Informations personnelles',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 4),
        const Text('Créez votre compte prestataire',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        _field(_nameController, 'Nom complet', icon: Icons.person_outline),
        const SizedBox(height: 14),
        _field(_phoneController, 'Téléphone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 14),
        _field(_emailController, 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _field(_passwordController, 'Mot de passe',
            icon: Icons.lock_outline,
            obscure: !_showPassword,
            suffix: _eyeButton(_showPassword,
                () => setState(() => _showPassword = !_showPassword))),
        const SizedBox(height: 14),
        _field(_confirmController, 'Confirmer le mot de passe',
            icon: Icons.lock_outline,
            obscure: !_showConfirm,
            suffix: _eyeButton(_showConfirm,
                () => setState(() => _showConfirm = !_showConfirm))),
        const SizedBox(height: 16),
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
                activeColor: const Color(0xFF3F64B5),
                side:
                    const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF64748B)),
                  children: [
                    const TextSpan(text: "J'accepte les "),
                    TextSpan(
                        text: "Conditions d'utilisation",
                        style: const TextStyle(
                            color: Color(0xFF3F64B5),
                            fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()..onTap = _showCguDialog,
                    ),
                    const TextSpan(text: ' et la '),
                    TextSpan(
                        text: 'Politique de confidentialité',
                        style: const TextStyle(
                            color: Color(0xFF3F64B5),
                            fontWeight: FontWeight.w600),
                        recognizer: TapGestureRecognizer()..onTap = _showCguDialog,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _continueButton(
            enabled: _step1Valid,
            onPressed: () => setState(() => _step = 2)),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // STEP 2 — Professional info
  // ══════════════════════════════════════════════════════════════
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Informations professionnelles',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 4),
        const Text('Décrivez votre activité',
            style: TextStyle(
                fontSize: 14,
                color: Color(0xFF3F64B5),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        const Text('Catégorie de métier',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 10),
        // Services grid
        _isLoadingServices
            ? const Center(child: CircularProgressIndicator())
            : _services.isEmpty
                ? const Text('Aucun service disponible',
                    style: TextStyle(color: Color(0xFF64748B)))
                : GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 3.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: _services.map((service) {
                      final id = service.id ?? '';
                      final nom = service.nom;
                      final selected = _selectedServiceIds.contains(id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedServiceIds.remove(id);
                            } else if (_selectedServiceIds.length < 3) {
                              _selectedServiceIds.add(id);
                            } else {
                              _showError('Maximum 3 services autorisés.');
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF3F64B5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF3F64B5)
                                  : const Color(0xFFE2E8F0),
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              nom,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF1A237E),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
        const SizedBox(height: 20),
        const Text('Description',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF1A237E)),
          decoration: InputDecoration(
            hintText: 'Décrivez votre expérience et vos spécialités...',
            hintStyle: const TextStyle(
                fontSize: 13, color: Color(0xFFADB5C7)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                  color: Color(0xFF3F64B5), width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 20),
        const Text("Zone d'intervention & Localisation",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 8),
        _field(_zoneController, "Ex: Casablanca, Rabat (zone d'action)", icon: Icons.map_outlined),
        const SizedBox(height: 14),

        // Address Fields
        Row(
          children: [
            Expanded(child: _field(_paysController, 'Pays', icon: Icons.public)),
            const SizedBox(width: 14),
            Expanded(child: _field(_villeController, 'Ville *', icon: Icons.location_city)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _field(_numBatController, 'N° Bât/Appart', icon: Icons.home_work_outlined)),
            const SizedBox(width: 14),
            Expanded(child: _field(_codePostalController, 'Code postal', keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 14),
        _field(_quartierController, 'Quartier', icon: Icons.location_on_outlined),
        const SizedBox(height: 14),
        _field(_rueController, 'Rue / Avenue', icon: Icons.add_road),
        const SizedBox(height: 16),

        // ── Location detector ──
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _detectingLoc ? null : _detectLocation,
            icon: _detectingLoc
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 18),
            label: Text(_detectingLoc ? 'Détection...' : '📍 Détecter ville et pays auto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        if (_confirmedGeoPoint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'Position exacte confirmée sur la carte',
                  style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        _continueButton(
            enabled: _step2Valid,
            onPressed: () => setState(() => _step = 3)),
        const SizedBox(height: 24),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // STEP 3 — Documents
  // ══════════════════════════════════════════════════════════════
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Documents justificatifs',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 4),
        const Text('Téléchargez vos pièces pour vérification',
            style: TextStyle(
                fontSize: 14,
                color: Color(0xFF3F64B5),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 24),
        _uploadCard(
          label: 'CIN - Recto',
          fileName: _cinFrontName,
          icon: Icons.camera_alt_outlined,
          onTap: () => _pickImage((name, bytes) {
            setState(() {
              _cinFrontName = name;
              _cinFrontBytes = bytes;
            });
          }),
        ),
        const SizedBox(height: 16),
        _uploadCard(
          label: 'CIN - Verso',
          fileName: _cinBackName,
          icon: Icons.camera_alt_outlined,
          onTap: () => _pickImage((name, bytes) {
            setState(() {
              _cinBackName = name;
              _cinBackBytes = bytes;
            });
          }),
        ),
        const SizedBox(height: 16),
        _uploadCard(
          label: 'Casier Judiciaire',
          fileName: _certificateName,
          icon: Icons.upload_outlined,
          onTap: () => _pickDocument((name, bytes) {
            setState(() {
              _certificateName = name;
              _certificateBytes = bytes;
            });
          }),
        ),
        const SizedBox(height: 18),
        // Info banner
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFEDE68), width: 1),
          ),
          child: const Row(
            children: [
              Text('⏳', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vos documents seront vérifiés par notre équipe sous 24-48h.',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF854D0E)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _step3Valid && !_isLoading ? _handleSignup : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _step3Valid
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
                : const Text('Continuer',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _illustration() {
    return Center(
      child: Image.asset(
        'assets/logo.png',
        height: 80,
        errorBuilder: (context, error, stackTrace) => const SizedBox(height: 80),
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

  Widget _eyeButton(bool visible, VoidCallback toggle) {
    return IconButton(
      icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF94A3B8),
          size: 20),
      onPressed: toggle,
    );
  }

  Widget _continueButton(
      {required bool enabled, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? const Color(0xFF3F64B5) : const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        child: const Text('Continuer',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
    );
  }

  Widget _uploadCard({
    required String label,
    required String? fileName,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final uploaded = fileName != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: 90,
            decoration: BoxDecoration(
              color: uploaded
                  ? const Color(0xFFEEF6FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: uploaded
                    ? const Color(0xFF3F64B5)
                    : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    uploaded ? Icons.check_circle_outline : icon,
                    size: 28,
                    color: uploaded
                        ? const Color(0xFF3F64B5)
                        : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    uploaded ? fileName! : 'Appuyez pour télécharger',
                    style: TextStyle(
                      fontSize: 13,
                      color: uploaded
                          ? const Color(0xFF3F64B5)
                          : const Color(0xFF94A3B8),
                      fontWeight: uploaded
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  void _showCguDialog() {
    if (_cguContent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les conditions d\'utilisation ne sont pas encore configurées.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Conditions d\'utilisation & Politique',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                child: Text(
                  _cguContent!.replaceAll('\\n', '\n'),
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _agreed = true);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F64B5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Accepter', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
