import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/location_service.dart';
import '../shared/map_confirm_screen.dart';

class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({super.key});

  @override
  State<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _locationService = LocationService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _addresses = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    if (_userId == null) return;
    setState(() => _isLoading = true);
    try {
      final snap = await _db
          .collection('adresses')
          .where('idUtilisateur', isEqualTo: _userId)
          .get();
      setState(() {
        _addresses = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (e) {
      debugPrint('Error fetching addresses: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      await _db.collection('adresses').doc(addressId).delete();
      _fetchAddresses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adresse supprimée.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddAddressSheet(
        userId: _userId!,
        locationService: _locationService,
        onAddressAdded: () {
          Navigator.pop(context);
          _fetchAddresses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mes Adresses',
            style: TextStyle(
                color: Color(0xFF1A237E),
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A237E)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? const Center(
                  child: Text('Aucune adresse trouvée.',
                      style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final addr = _addresses[index];
                    final subtitle = [
                      if ((addr['Quartier'] ?? '').isNotEmpty) addr['Quartier'],
                      if ((addr['Ville'] ?? '').isNotEmpty) addr['Ville'],
                      if ((addr['Pays'] ?? '').isNotEmpty) addr['Pays'],
                    ].join(', ');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      color: Colors.white,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8EAF6),
                          child: Icon(Icons.location_on,
                              color: Color(0xFF3F64B5)),
                        ),
                        title: Text(
                          addr['Rue'] ?? addr['Ville'] ?? 'Adresse',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E)),
                        ),
                        subtitle: Text(subtitle),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _deleteAddress(addr['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAddressSheet,
        backgroundColor: const Color(0xFF3F64B5),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Address Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddAddressSheet extends StatefulWidget {
  final String userId;
  final LocationService locationService;
  final VoidCallback onAddressAdded;

  const _AddAddressSheet({
    required this.userId,
    required this.locationService,
    required this.onAddressAdded,
  });

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  // All original fields are preserved
  final _rueCtrl = TextEditingController();
  final _batCtrl = TextEditingController();
  final _quartierCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _paysCtrl = TextEditingController(text: 'Maroc');

  // GPS-detected or map-confirmed coordinates
  GeoPoint? _confirmedGeoPoint;
  bool _isLoading = false;

  // ── Nominatim forward geocode (city+country → lat/lng) ────────
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

  // ── GPS detection ─────────────────────────────────────────────
  Future<void> _detectLoc() async {
    setState(() => _isLoading = true);
    try {
      final pos = await widget.locationService.getCurrentPosition();
      if (pos == null) throw Exception('Impossible de détecter la localisation.');

      // Reverse geocode the GPS position
      String city = '';
      String country = 'Maroc';
      bool hasData = false;

      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          city = p.administrativeArea ?? p.locality ?? '';
          country = p.country ?? 'Maroc';
          hasData = city.isNotEmpty;
        }
      } catch (_) {}

      // Nominatim fallback
      if (!hasData) {
        try {
          final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${pos.latitude}&lon=${pos.longitude}&zoom=10&addressdetails=1',
          );
          final headers = kIsWeb ? <String, String>{} : {'User-Agent': 'service_app_amine/1.0'};
          final response = await http.get(url, headers: headers);
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data?['address'] != null) {
              final addr = data['address'];
              city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'] ?? '';
              country = addr['country'] ?? 'Maroc';
            }
          }
        } catch (_) {}
      }

      // Fill only city + country
      setState(() {
        if (city.isNotEmpty) _villeCtrl.text = city;
        _paysCtrl.text = country;
      });

      // Open map confirmation
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
          if (result.city.isNotEmpty) _villeCtrl.text = result.city;
          if (result.country.isNotEmpty) _paysCtrl.text = result.country;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Position confirmée !'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Open map from manual city/country entry ────────────────────
  Future<void> _openMapForManualEntry() async {
    final city = _villeCtrl.text.trim();
    final country = _paysCtrl.text.trim();

    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez entrer une ville d\'abord.')));
      return;
    }

    setState(() => _isLoading = true);
    double lat = 31.7917; // Morocco center fallback
    double lng = -7.0926;

    final coords = await _forwardGeocode('$city, $country');
    if (coords != null) {
      lat = coords['lat']!;
      lng = coords['lng']!;
    }
    setState(() => _isLoading = false);

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

    if (result != null && mounted) {
      setState(() {
        _confirmedGeoPoint = result.geoPoint;
        if (result.city.isNotEmpty) _villeCtrl.text = result.city;
        if (result.country.isNotEmpty) _paysCtrl.text = result.country;
      });
    }
  }

  // ── Duplicate check ────────────────────────────────────────────
  Future<bool> _isDuplicate(GeoPoint gp) async {
    // Check if within ~100m (0.001 degree ≈ 111m)
    const delta = 0.001;
    final snap = await FirebaseFirestore.instance
        .collection('adresses')
        .where('idUtilisateur', isEqualTo: widget.userId)
        .get();
    for (final doc in snap.docs) {
      final loc = doc.data()['location'];
      if (loc is GeoPoint) {
        if ((loc.latitude - gp.latitude).abs() < delta &&
            (loc.longitude - gp.longitude).abs() < delta) {
          return true;
        }
      }
    }
    return false;
  }

  // ── Save ──────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_villeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La ville est obligatoire.')));
      return;
    }

    // If no map confirmation yet, prompt the user to confirm on map
    if (_confirmedGeoPoint == null) {
      await _openMapForManualEntry();
      if (_confirmedGeoPoint == null) return; // User cancelled
    }

    setState(() => _isLoading = true);

    try {
      // Duplicate check
      final duplicate = await _isDuplicate(_confirmedGeoPoint!);
      if (duplicate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Cette position est déjà enregistrée. Choisissez un autre emplacement.'),
            backgroundColor: Colors.orange,
          ));
        }
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('adresses').add({
        'idUtilisateur': widget.userId,
        'Rue': _rueCtrl.text.trim(),
        'NumBatiment': _batCtrl.text.trim(),
        'Quartier': _quartierCtrl.text.trim(),
        'Ville': _villeCtrl.text.trim(),
        'CodePostal': _cpCtrl.text.trim(),
        'Pays': _paysCtrl.text.trim(),
        'location': _confirmedGeoPoint,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update master location on user document
      await FirebaseFirestore.instance
          .collection('utilisateurs')
          .doc(widget.userId)
          .update({'location': _confirmedGeoPoint});

      widget.onAddressAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ajouter une adresse',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E))),
            const SizedBox(height: 16),

            // ── GPS Button ──
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _detectLoc,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF3F64B5)))
                  : const Icon(Icons.my_location),
              label: const Text('Utiliser ma position GPS'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3F64B5),
                side: const BorderSide(color: Color(0xFF3F64B5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text('— ou entrez manuellement —',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
            const SizedBox(height: 12),

            // ── Form Fields (all preserved) ──
            _field(_batCtrl, 'N° Bâtiment / Appt'),
            _field(_rueCtrl, 'Rue'),
            _field(_quartierCtrl, 'Quartier'),
            _field(_villeCtrl, 'Ville *'),
            _field(_cpCtrl, 'Code Postal'),
            _field(_paysCtrl, 'Pays'),
            const SizedBox(height: 12),

            // Map preview button (only if city filled and no GPS)
            if (_confirmedGeoPoint == null)
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _openMapForManualEntry,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Confirmer sur la carte'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3F64B5),
                  side: const BorderSide(color: Color(0xFF3F64B5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

            // GPS confirmed indicator
            if (_confirmedGeoPoint != null) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text('Coordonnées GPS confirmées',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F64B5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Enregistrer',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
