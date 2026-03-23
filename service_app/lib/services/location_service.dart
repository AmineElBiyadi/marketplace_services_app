import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  /// Cache en mémoire pour les coordonnées des villes
  final Map<String, GeoPoint> _cityCache = {};

  /// Récupère les coordonnées d'une ville via Nominatim (OpenStreetMap)
  Future<GeoPoint?> getCoordinatesFromCity(String city) async {
    if (city.isEmpty) return null;
    
    // Pour Nominatim, on ne garde que la ville principale, pas le quartier.
    final cityName = city.split(',').first.trim();
    if (cityName.isEmpty) return null;
    
    final cacheKey = cityName.toLowerCase();
    if (_cityCache.containsKey(cacheKey)) {
      return _cityCache[cacheKey];
    }

    try {
      final encoded = Uri.encodeComponent('$cityName, Maroc');
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?format=json&q=$encoded&limit=1');
      
      final response = await http.get(url, headers: {'User-Agent': 'service_app_amine/1.0'});
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final lat = double.tryParse(data[0]['lat'].toString());
          final lon = double.tryParse(data[0]['lon'].toString());
          if (lat != null && lon != null) {
            final geoPoint = GeoPoint(lat, lon);
            _cityCache[cacheKey] = geoPoint;
            return geoPoint;
          }
        }
      }
    } catch (_) {}
    return null;
  }
  /// Demande la permission et retourne la position actuelle.
  /// Retourne null si la permission est refusée ou en cas d'erreur.
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Vérifie si le service de localisation est activé
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
  }

  /// Calcule la distance en km entre deux coordonnées.
  double distanceInKm({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return meters / 1000;
  }

  /// Retourne la distance en km entre la position de l'utilisateur
  /// et un [GeoPoint] Firestore. Retourne null si l'un des deux est absent.
  double? distanceFromGeoPoint({
    required Position? userPosition,
    required GeoPoint? expertGeoPoint,
  }) {
    if (userPosition == null || expertGeoPoint == null) return null;
    return distanceInKm(
      lat1: userPosition.latitude,
      lon1: userPosition.longitude,
      lat2: expertGeoPoint.latitude,
      lon2: expertGeoPoint.longitude,
    );
  }
}