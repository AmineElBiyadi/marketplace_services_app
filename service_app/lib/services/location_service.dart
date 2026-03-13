import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
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