import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/expert.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import 'expert_details_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../theme/app_colors.dart';

const _kBlue = AppColors.primary;

class ExpertMapScreen extends StatefulWidget {
  const ExpertMapScreen({super.key});

  @override
  State<ExpertMapScreen> createState() => _ExpertMapScreenState();
}

class _ExpertMapScreenState extends State<ExpertMapScreen> {
  final _firestoreService = FirestoreService();
  final _locationService  = LocationService();
  final MapController _mapController = MapController();

  LatLng? _userLatLng;
  List<Expert> _allExperts = [];
  List<Expert> _filteredExperts = [];
  List<Map<String, dynamic>> _clientAddresses = [];
  List<String> _serviceCategories = [];

  // ── Filter state ──────────────────────────────────────────────
  double _radiusKm = 20;   // 0 = ALL
  String? _selectedServiceFilter;
  LatLng? _selectedAddressLatLng;
  String? _selectedAddressLabel;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Get user GPS
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      _userLatLng = LatLng(pos.latitude, pos.longitude);
    }

    // Load experts with location
    final experts = await _firestoreService.getExpertsWithLocation(onlyAvailable: true);

    // Load client addresses
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    List<Map<String, dynamic>> addresses = [];
    if (uid.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('adresses')
          .where('idUtilisateur', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final gp = data['location'] as GeoPoint?;
        if (gp != null) {
          addresses.add({
            'label': '${data['Quartier'] ?? ''}, ${data['Ville'] ?? ''}',
            'latLng': LatLng(gp.latitude, gp.longitude),
          });
        }
      }
    }

    // Extract service categories from experts
    final cats = <String>{};
    for (final e in experts) { cats.addAll(e.services); }

    if (mounted) {
      setState(() {
        _allExperts = experts;
        _clientAddresses = addresses;
        _serviceCategories = cats.toList()..sort();
        _isLoading = false;
      });
      _applyFilters();
      
      final mCenter = _selectedAddressLatLng ?? _userLatLng;
      if (mCenter != null) {
        _mapController.move(mCenter, 12.0);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  FILTER
  // ─────────────────────────────────────────────────────────────
  void _applyFilters() {
    final center = _selectedAddressLatLng ?? _userLatLng;

    List<Expert> result = _allExperts.where((e) {
      // Service filter
      if (_selectedServiceFilter != null &&
          !e.services.contains(_selectedServiceFilter)) {
        return false;
      }

      // Radius filter (0 = ALL)
      if (_radiusKm > 0 && center != null && e.location != null) {
        final dist = _distanceKm(
          center.latitude, center.longitude,
          e.location!.latitude, e.location!.longitude,
        );
        if (dist > _radiusKm) {
          return false;
        }
      }
      return true;
    }).toList();

    setState(() {
      _filteredExperts = result;
    });
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  void _showExpertSheet(Expert expert) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ExpertPreviewSheet(
        expert: expert,
        userLatLng: _selectedAddressLatLng ?? _userLatLng,
        onViewProfile: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ExpertProfileScreen(expert: expert),
          ));
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final center = _userLatLng ?? const LatLng(33.5731, -7.5898); // Casablanca fallback

    return Scaffold(
      body: Stack(
        children: [
          // ── Flutter Map (Mapbox) ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=${dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? ''}',
                additionalOptions: {
                  'access_token': dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '',
                },
                userAgentPackageName: 'com.example.service_app',
              ),
              MarkerLayer(
                markers: _buildMarkers(),
              ),
            ],
          ),

          // ── Top panel (back + title + address picker) ──
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AppBar-like row
                Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: _kBlue, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text('Nearby Experts', style: TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 16)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '${_filteredExperts.length} found',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Address picker chips ──
                if (_clientAddresses.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        _addrChip('📍 My Position', null, null),
                        ..._clientAddresses.map((addr) =>
                          _addrChip(addr['label'] as String, addr['latLng'] as LatLng, addr['label'] as String),
                        ),
                      ],
                    ),
                  ),

                // ── Service filter chips ──
                if (_serviceCategories.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Row(
                      children: [
                        _serviceChip('All', null),
                        ..._serviceCategories.map((s) => _serviceChip(s, s)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom radius slider ──
          if (!_isLoading)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Search radius', style: TextStyle(fontWeight: FontWeight.w600, color: _kBlue)),
                        Text(
                          _radiusKm == 0 ? 'All' : '${_radiusKm.toInt()} km',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue),
                        ),
                      ],
                    ),
                    Slider(
                      value: _radiusKm,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      activeColor: _kBlue,
                      inactiveColor: const Color(0xFFDCDFEA),
                      label: _radiusKm == 0 ? 'All' : '${_radiusKm.toInt()} km',
                      onChanged: (v) {
                        setState(() => _radiusKm = v);
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
            ),

          // ── Loading overlay ──
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  // ── Build Markers ─────────────────────────────────────────────
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // Selected Location (or User Location) Marker
    final centerPos = _selectedAddressLatLng ?? _userLatLng;
    if (centerPos != null) {
      markers.add(
        Marker(
          point: centerPos,
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
        ),
      );
    }

    // Expert Markers
    for (final e in _filteredExperts) {
      if (e.location == null) continue;
      markers.add(
        Marker(
          point: LatLng(e.location!.latitude, e.location!.longitude),
          width: 100,
          height: 65,
          child: GestureDetector(
            onTap: () => _showExpertSheet(e),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFDCDFEA),
                    backgroundImage: e.photo.isNotEmpty ? NetworkImage(e.photo) : null,
                    child: e.photo.isEmpty
                        ? Text(e.nom.isNotEmpty ? e.nom[0].toUpperCase() : 'E', style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 14))
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                  ),
                  child: Text(
                    e.nom,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _kBlue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // ── Address chip ──────────────────────────────────────────────
  Widget _addrChip(String label, LatLng? latLng, String? addrLabel) {
    final isSelected = _selectedAddressLabel == addrLabel;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddressLatLng = latLng;
          _selectedAddressLabel = addrLabel;
        });
        _applyFilters();
        if (latLng != null) {
          _mapController.move(latLng, 13);
        } else if (_userLatLng != null) {
          _mapController.move(_userLatLng!, 12);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _kBlue : Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : _kBlue)),
      ),
    );
  }

  // ── Service chip ──────────────────────────────────────────────
  Widget _serviceChip(String label, String? value) {
    final isSelected = _selectedServiceFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedServiceFilter = value);
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3D5A99) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF3D5A99) : Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  EXPERT PREVIEW BOTTOM SHEET
// ─────────────────────────────────────────────────────────────
class _ExpertPreviewSheet extends StatelessWidget {
  final Expert expert;
  final LatLng? userLatLng;
  final VoidCallback onViewProfile;

  const _ExpertPreviewSheet({required this.expert, required this.userLatLng, required this.onViewProfile});

  double _distKm() {
    if (userLatLng == null || expert.location == null) return -1;
    const R = 6371.0;
    final dLat = (expert.location!.latitude - userLatLng!.latitude) * pi / 180;
    final dLon = (expert.location!.longitude - userLatLng!.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(userLatLng!.latitude * pi / 180) *
            cos(expert.location!.latitude * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final dist = _distKm();
    final photo = expert.photo;
    ImageProvider? avatarImg;
    if (photo.isNotEmpty) avatarImg = NetworkImage(photo);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFDCDFEA),
                backgroundImage: avatarImg,
                child: avatarImg == null
                    ? Text(expert.nom[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: _kBlue, fontSize: 18))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(expert.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: _kBlue)),
                    if (expert.services.isNotEmpty)
                      Text(expert.services.join(', '), style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                ),
              ),
              if (dist >= 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${dist.toStringAsFixed(1)} km', style: const TextStyle(color: _kBlue, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 18),
              const SizedBox(width: 4),
              Text(expert.noteMoyenne.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('View Profile', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
