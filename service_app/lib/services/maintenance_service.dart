import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isMaintenance = false;
  String _message = "L'application est en maintenance. Nous serons bientôt de retour.";
  bool _initialized = false;

  bool get isMaintenance => _isMaintenance;
  String get message => _message;
  bool get initialized => _initialized;

  MaintenanceService() {
    _listenToMaintenanceMode();
  }

  void _listenToMaintenanceMode() {
    _db.collection('settings').doc('global_config').snapshots().listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _isMaintenance = data['is_maintenance'] ?? false;
        _message = data['maintenance_message'] ?? "L'application est en maintenance. Nous serons bientôt de retour.";
      } else {
        _isMaintenance = false;
      }
      _initialized = true;
      notifyListeners();
    }, onError: (e) {
      debugPrint("Error listening to maintenance mode: $e");
      _initialized = true; // Still allow app to try loading
      notifyListeners();
    });
  }

  Future<void> checkMaintenanceStatus() async {
     try {
       final doc = await _db.collection('settings').doc('global_config').get();
       if (doc.exists) {
         final data = doc.data() as Map<String, dynamic>;
         _isMaintenance = data['is_maintenance'] ?? false;
         _message = data['maintenance_message'] ?? "L'application est en maintenance. Nous serons bientôt de retour.";
       }
       notifyListeners();
     } catch (e) {
       debugPrint("Error checking maintenance status: $e");
     }
  }
}
