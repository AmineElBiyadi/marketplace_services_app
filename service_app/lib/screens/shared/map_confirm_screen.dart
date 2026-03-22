import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// A full-screen map that lets the user confirm and optionally adjust
/// a location pin before saving.
///
/// Usage:
/// ```dart
/// final result = await Navigator.push<MapConfirmResult>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => MapConfirmScreen(
///       initialLat: lat,
///       initialLng: lng,
///     ),
///   ),
/// );
/// if (result != null) { /* use result.geoPoint, result.city, result.country */ }
/// ```
class MapConfirmResult {
  final GeoPoint geoPoint;
  final String city;
  final String country;

  const MapConfirmResult({
    required this.geoPoint,
    required this.city,
    required this.country,
  });
}

class MapConfirmScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final String? initialCity;
  final String? initialCountry;
  /// Zoom level: use 13 for GPS (precise), 11 for city-level forward geocode
  final double initialZoom;

  const MapConfirmScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialCity,
    this.initialCountry,
    this.initialZoom = 13.0,
  });

  @override
  State<MapConfirmScreen> createState() => _MapConfirmScreenState();
}

class _MapConfirmScreenState extends State<MapConfirmScreen> {
  late LatLng _markerPos;
  late final MapController _mapController;
  bool _isGeocoding = false;
  String _city = '';
  String _country = '';

  @override
  void initState() {
    super.initState();
    _markerPos = LatLng(widget.initialLat, widget.initialLng);
    _mapController = MapController();
    _city = widget.initialCity ?? '';
    _country = widget.initialCountry ?? '';
    if (_city.isEmpty) {
      // Reverse geocode the initial position
      _reverseGeocode(_markerPos.latitude, _markerPos.longitude);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    setState(() => _isGeocoding = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10&addressdetails=1',
      );
      final headers = kIsWeb ? <String, String>{} : {'User-Agent': 'service_app_amine/1.0'};
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['address'] != null) {
          final addr = data['address'];
          if (mounted) {
            setState(() {
              _city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'] ?? '';
              _country = addr['country'] ?? '';
            });
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _onMapTap(TapPosition _, LatLng latlng) {
    setState(() => _markerPos = latlng);
    _reverseGeocode(latlng.latitude, latlng.longitude);
  }

  void _confirm() {
    Navigator.of(context).pop(
      MapConfirmResult(
        geoPoint: GeoPoint(_markerPos.latitude, _markerPos.longitude),
        city: _city,
        country: _country,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Confirmer la position',
          style: TextStyle(
            color: Color(0xFF1A237E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A237E)),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _markerPos,
              initialZoom: widget.initialZoom,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.service_app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _markerPos,
                    width: 48,
                    height: 56,
                    child: const Column(
                      children: [
                        Icon(
                          Icons.location_pin,
                          color: Color(0xFF3F64B5),
                          size: 48,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Instruction banner at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color(0xFF3F64B5).withAlpha(230),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: const Row(
                children: [
                  Icon(Icons.touch_app, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Appuyez sur la carte pour déplacer le marqueur',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom panel with detected location + confirm
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black12)],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Location summary
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF3F64B5), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _isGeocoding
                            ? const SizedBox(
                                height: 18,
                                child: LinearProgressIndicator(
                                  color: Color(0xFF3F64B5),
                                  backgroundColor: Color(0xFFE8EAF6),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _city.isNotEmpty ? _city : 'Position sélectionnée',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Color(0xFF1A237E),
                                    ),
                                  ),
                                  if (_country.isNotEmpty)
                                    Text(
                                      _country,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isGeocoding ? null : _confirm,
                      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text(
                        'Confirmer cette position',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F64B5),
                        disabledBackgroundColor: const Color(0xFF94A3B8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
