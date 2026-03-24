import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_colors.dart';
import '../../layouts/provider_layout.dart';
import '../../services/firestore_service.dart';
import '../../models/expert.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart' hide Location;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/location_service.dart';
import '../shared/map_confirm_screen.dart';

class ProviderPersonalInfoScreen extends StatefulWidget {
  final String expertId;

  const ProviderPersonalInfoScreen({super.key, required this.expertId});

  @override
  State<ProviderPersonalInfoScreen> createState() => _ProviderPersonalInfoScreenState();
}

class _ProviderPersonalInfoScreenState extends State<ProviderPersonalInfoScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  bool _isSaving = false;
  Expert? _expertData;
  ExpertModel? _expertModel;

  final TextEditingController _prenomCtrl = TextEditingController();
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  
  // Address fields
  final TextEditingController _villeCtrl = TextEditingController();
  final TextEditingController _paysCtrl = TextEditingController(text: 'Maroc');
  final TextEditingController _numBatCtrl = TextEditingController();
  final TextEditingController _rueCtrl = TextEditingController();
  final TextEditingController _quartierCtrl = TextEditingController();
  final TextEditingController _codePostalCtrl = TextEditingController();

  final TextEditingController _bioCtrl = TextEditingController();
  
  final LocationService _locationService = LocationService();
  GeoPoint? _confirmedGeoPoint;
  bool _detectingLoc = false;
  
  double _rayon = 20.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final expertModel = await _firestoreService.getExpertProfile(widget.expertId);
      final expertDetailed = await _firestoreService.getExpertDetailed(widget.expertId);
      
      Map<String, dynamic>? addressData;
      if (expertModel != null) {
        addressData = await _firestoreService.getAddressForUser(expertModel.idUtilisateur);
      }

      if (mounted) {
        setState(() {
          _expertModel = expertModel;
          _expertData = expertDetailed;

          // Hydrate fields
          final splitNom = (_expertData?.nom ?? _expertModel?.user?.nom ?? 'Expert').split(' ');
          _prenomCtrl.text = splitNom.isNotEmpty ? splitNom[0] : '';
          _nomCtrl.text = splitNom.length > 1 ? splitNom[1] : '';

          _phoneCtrl.text = _expertData?.telephone ?? '';
          _emailCtrl.text = _expertModel?.user?.email ?? '';
          
          if (addressData != null) {
            _villeCtrl.text = addressData['Ville'] ?? _expertData?.ville.split(',').first ?? 'Casablanca';
            _paysCtrl.text = addressData['Pays'] ?? 'Maroc';
            _numBatCtrl.text = addressData['NumBatiment'] ?? '';
            _rueCtrl.text = addressData['Rue'] ?? '';
            _quartierCtrl.text = addressData['Quartier'] ?? '';
            _codePostalCtrl.text = addressData['CodePostal'] ?? '';
            if (addressData['location'] is GeoPoint) {
              _confirmedGeoPoint = addressData['location'];
            }
          } else {
            _villeCtrl.text = _expertData?.ville.split(',').first ?? 'Casablanca';
            _paysCtrl.text = 'Maroc';
            _rueCtrl.text = _expertData?.ville ?? '';
          }
          
          _rayon = (_expertModel?.rayonTravaille ?? 20).toDouble();
          _bioCtrl.text = _expertModel?.experience ?? "Professional expert with years of experience.";

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _saveChanges() async {
    if (_expertData == null || _expertModel == null) return;
    
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateExpertProfileInfo(
        widget.expertId,
        _expertModel!.idUtilisateur,
        prenom: _prenomCtrl.text,
        nom: _nomCtrl.text,
        telephone: _phoneCtrl.text,
        email: _emailCtrl.text,
        ville: _villeCtrl.text,
        pays: _paysCtrl.text,
        numBatiment: _numBatCtrl.text,
        rue: _rueCtrl.text,
        quartier: _quartierCtrl.text,
        codePostal: _codePostalCtrl.text,
        location: _confirmedGeoPoint,
        rayonTravaille: _rayon,
        experience: _bioCtrl.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Changes saved successfully!"), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error while saving : $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ProviderLayout(
      activeRoute: '/provider/profile',
      expertId: widget.expertId,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            "Personal Information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          centerTitle: false,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildTextField("First Name", LucideIcons.user, _prenomCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField("Last Name", null, _nomCtrl, isLabeled: true)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField("Phone", LucideIcons.phone, _phoneCtrl, enabled: false),
                    const SizedBox(height: 20),
                    _buildTextField("Email", LucideIcons.mail, _emailCtrl, enabled: false),
                    const SizedBox(height: 32),
                    
                    const Text("Address & Location", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("Country", LucideIcons.globe, _paysCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField("City", LucideIcons.building, _villeCtrl)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("Building N°", LucideIcons.home, _numBatCtrl)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField("Postal Code", null, _codePostalCtrl, isLabeled: true)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField("Neighborhood", LucideIcons.mapPin, _quartierCtrl),
                    const SizedBox(height: 16),
                    _buildTextField("Street / Avenue", LucideIcons.map, _rueCtrl),
                    const SizedBox(height: 20),
                    
                    // Map detector
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _detectingLoc ? null : _detectLocation,
                        icon: _detectingLoc
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(LucideIcons.mapPin, size: 18),
                        label: Text(_detectingLoc ? 'Detecting...' : 'Detect on Map Automatically'),
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
                              'Exact location confirmed on map',
                              style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                    _buildRayonSlider(),
                    const SizedBox(height: 24),
                    _buildTextField("Bio / Description", LucideIcons.fileText, _bioCtrl, maxLines: 3),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(String label, IconData? icon, TextEditingController controller, {bool isLabeled = false, int maxLines = 1, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          enabled: enabled,
          style: TextStyle(
            color: enabled ? Colors.black : const Color(0xFF94A3B8), // Griser le texte si désactivé
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: !enabled,
            fillColor: enabled ? Colors.transparent : const Color(0xFFF1F5F9), // Fond grisé
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, IconData icon, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: controller.text.isNotEmpty ? controller.text : null,
              icon: const Icon(LucideIcons.chevronDown, color: Color(0xFF64748B), size: 18),
              items: [controller.text].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRayonSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.search, size: 16, color: Color(0xFF64748B)), // Or any radius icon
            const SizedBox(width: 8),
            const Text(
              "Working radius",
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Maximum distance", style: TextStyle(color: Color(0xFF64748B))),
                  Text(
                    "${_rayon.toInt()} km",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                ),
                child: Slider(
                  value: _rayon,
                  min: 5,
                  max: 100,
                  onChanged: (val) {
                    setState(() {
                      _rayon = val;
                    });
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text("5 km", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                  Text("100 km", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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
      GeoPoint? geoPoint;
      String city = _villeCtrl.text.trim();
      String country = _paysCtrl.text.trim().isEmpty ? 'Maroc' : _paysCtrl.text.trim();
      double lat = 31.7917;
      double lng = -7.0926;

      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        // Reverse geocode
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
      } else if (city.isNotEmpty) {
        // Fallback forward geocode if location denied but city entered
        final coords = await _forwardGeocode('$city, $country');
        if (coords != null) { lat = coords['lat']!; lng = coords['lng']!; }
      }

      if (mounted) setState(() {
        if (city.isNotEmpty) _villeCtrl.text = city;
        _paysCtrl.text = country;
      });

      if (!mounted) return;
      final result = await Navigator.push<MapConfirmResult>(
        context,
        MaterialPageRoute(
          builder: (_) => MapConfirmScreen(
            initialLat: lat,
            initialLng: lng,
            initialCity: city,
            initialCountry: country,
          ),
        ),
      );
      if (result != null && mounted) {
        setState(() {
          _confirmedGeoPoint = result.geoPoint;
          if (result.city.isNotEmpty) _villeCtrl.text = result.city;
          if (result.country.isNotEmpty) _paysCtrl.text = result.country;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location confirmed!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.destructive,
        ));
      }
    } finally {
      if (mounted) setState(() => _detectingLoc = false);
    }
  }
}
