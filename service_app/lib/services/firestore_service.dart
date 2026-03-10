import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking.dart';
import '../models/expert.dart';
import '../models/user.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Expert related methods
  Future<ExpertModel?> getExpertProfile(String expertId) async {
    try {
      DocumentSnapshot expertDoc = await _db.collection('experts').doc(expertId).get();
      if (!expertDoc.exists) return null;

      ExpertModel expert = ExpertModel.fromFirestore(expertDoc);
      
      // Optionally fetch basic user info
      DocumentSnapshot userDoc = await _db.collection('utilisateurs').doc(expert.idUtilisateur).get();
      if (userDoc.exists) {
        UserModel user = UserModel.fromFirestore(userDoc);
        return ExpertModel.fromFirestore(expertDoc, user: user);
      }
      
      return expert;
    } catch (e) {
      print("Error fetching expert profile: $e");
      return null;
    }
  }

  // Interventions (Bookings)
  Stream<List<InterventionModel>> getPendingInterventions(String expertId) {
    return _db
        .collection('interventions')
        .where('idExpert', isEqualTo: expertId)
        .where('statut', isEqualTo: 'EN_ATTENTE')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InterventionModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<InterventionModel>> getUpcomingInterventions(String expertId) {
    final now = DateTime.now();
    return _db
        .collection('interventions')
        .where('idExpert', isEqualTo: expertId)
        .where('statut', isEqualTo: 'ACCEPTEE')
        .where('dateDebutIntervention', isGreaterThan: now)
        .orderBy('dateDebutIntervention', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InterventionModel.fromFirestore(doc))
            .toList());
  }

  // KPI helper
  Future<Map<String, dynamic>> getExpertKPIs(String expertId) async {
    final Map<String, dynamic> results = {
      "reservations_today": "0",
      "rating": "0.0",
      "revenue": "0 DH",
      "views": "0",
    };

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // 1. Profile views and Basic info (Direct doc fetch - Should always work if expert exists)
      try {
        final expertDoc = await _db.collection('experts').doc(expertId).get();
        if (expertDoc.exists) {
          final data = expertDoc.data() as Map<String, dynamic>;
          results["views"] = (data['profileViews'] ?? 0).toString();
          results["rating"] = "4.8"; // Default or from DB
        }
      } catch (e) {
        print("Error fetching profile views: $e");
      }

      // 2. Revenue this month (Requires composite index)
      try {
        final terminatedInterventions = await _db
            .collection('interventions')
            .where('idExpert', isEqualTo: expertId)
            .where('statut', isEqualTo: 'TERMINEE')
            .where('dateDebutIntervention', isGreaterThanOrEqualTo: startOfMonth)
            .get();

        double totalRevenue = 0;
        for (var doc in terminatedInterventions.docs) {
          totalRevenue += (doc.data()['prixNegocie'] as num?)?.toDouble() ?? 0.0;
        }
        results["revenue"] = "${totalRevenue.toStringAsFixed(0)} DH";
      } catch (e) {
        print("Error fetching revenue (Check for missing index): $e");
      }

      // 3. Reservations today (Requires composite index)
      try {
        final reservationsToday = await _db
            .collection('interventions')
            .where('idExpert', isEqualTo: expertId)
            .where('statut', isEqualTo: 'ACCEPTEE')
            .where('dateDebutIntervention', isGreaterThanOrEqualTo: startOfToday)
            .where('dateDebutIntervention', isLessThanOrEqualTo: endOfToday)
            .get();
        results["reservations_today"] = reservationsToday.docs.length.toString();
      } catch (e) {
        print("Error fetching today's reservations (Check for missing index): $e");
      }

      return results;
    } catch (e) {
      print("Global error in getExpertKPIs: $e");
      return results;
    }
  }

  // Availability toggle
  Future<void> updateExpertAvailability(String expertId, bool isOnline) async {
    await _db.collection('experts').doc(expertId).update({
      'etatCompte': isOnline ? 'ACTIVE' : 'DESACTIVE',
    });
  }
}
