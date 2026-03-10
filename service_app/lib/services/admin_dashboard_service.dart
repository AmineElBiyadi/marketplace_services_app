import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardStats {
  final int totalUsers;
  final int totalClients;
  final int totalProviders;
  final int pendingProviders;
  final int totalReservations;
  final int reservationsThisMonth;
  final int openClaims;
  final double averageRating;
  final int freeProviders;
  final int premiumProviders;

  AdminDashboardStats({
    required this.totalUsers,
    required this.totalClients,
    required this.totalProviders,
    required this.pendingProviders,
    required this.totalReservations,
    required this.reservationsThisMonth,
    required this.openClaims,
    required this.averageRating,
    required this.freeProviders,
    required this.premiumProviders,
  });
}

class AdminDashboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Aggregate KPI Stats ───────────────────────────────────────────────────
  Future<AdminDashboardStats> getDashboardStats() async {
    try {
      // Total utilisateurs
      final usersSnap = await _db.collection('utilisateurs').get();
      final allUsers = usersSnap.docs;
      final clients = allUsers.where((d) => (d.data()['role'] ?? '').toString().toLowerCase() == 'client').length;
      final providers = allUsers.where((d) => (d.data()['role'] ?? '').toString().toLowerCase() == 'expert').length;

      // Experts à valider (statut en attente)
      final pendingSnap = await _db.collection('experts')
          .where('statut', isEqualTo: 'EN_ATTENTE')
          .get();

      // Réservations / Interventions
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final interventionsSnap = await _db.collection('interventions').get();
      final allInterv = interventionsSnap.docs;
      int thisMonth = 0;
      double totalRating = 0;
      int ratingCount = 0;
      for (var doc in allInterv) {
        final data = doc.data();
        final ts = data['dateCreation'];
        if (ts is Timestamp && ts.toDate().isAfter(startOfMonth)) {
          thisMonth++;
        }
        final note = data['expertSnapshot']?['note_moyenne'];
        if (note != null) {
          totalRating += (note as num).toDouble();
          ratingCount++;
        }
      }

      // Réclamations ouvertes
      final claimsSnap = await _db.collection('reclamations')
          .where('statut', isEqualTo: 'OUVERTE')
          .get();

      // Premium vs Gratuit
      final abonnementsSnap = await _db.collection('abonnements')
          .where('statut', isEqualTo: 'ACTIVE')
          .get();
      final premiumExpertIds = abonnementsSnap.docs.map((d) => d.data()['idExpert']).toSet();
      final allExpertsSnap = await _db.collection('experts').get();
      final freeCount = allExpertsSnap.docs.where((d) => !premiumExpertIds.contains(d.id)).length;

      return AdminDashboardStats(
        totalUsers: allUsers.length,
        totalClients: clients,
        totalProviders: providers,
        pendingProviders: pendingSnap.docs.length,
        totalReservations: allInterv.length,
        reservationsThisMonth: thisMonth,
        openClaims: claimsSnap.docs.length,
        averageRating: ratingCount > 0 ? (totalRating / ratingCount) : 0.0,
        freeProviders: freeCount,
        premiumProviders: premiumExpertIds.length,
      );
    } catch (e) {
      print('getDashboardStats error: $e');
      rethrow;
    }
  }

  // ─── Pending Providers ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingProviders({int limit = 5}) async {
    try {
      final snap = await _db.collection('experts')
          .where('statut', isEqualTo: 'EN_ATTENTE')
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> result = [];
      for (var doc in snap.docs) {
        final data = doc.data();
        final userId = data['idUtilisateur'] as String?;
        String name = 'Expert';
        String category = '';
        if (userId != null) {
          final userDoc = await _db.collection('utilisateurs').doc(userId).get();
          name = userDoc.data()?['nom'] ?? userDoc.data()?['email'] ?? 'Expert';
        }
        // Fetch first service category
        final seSnap = await _db.collection('serviceExperts')
            .where('idExpert', isEqualTo: doc.id)
            .limit(1)
            .get();
        if (seSnap.docs.isNotEmpty) {
          final serviceId = seSnap.docs.first.data()['idService'];
          final serviceDoc = await _db.collection('services').doc(serviceId).get();
          category = serviceDoc.data()?['nom'] ?? '';
        }
        final ts = data['dateCreation'];
        String date = '';
        if (ts is Timestamp) {
          final d = ts.toDate();
          final diff = DateTime.now().difference(d);
          if (diff.inMinutes < 60) date = 'Il y a ${diff.inMinutes} min';
          else if (diff.inHours < 24) date = 'Il y a ${diff.inHours}h';
          else date = 'Il y a ${diff.inDays}j';
        }
        result.add({
          'id': doc.id,
          'name': name,
          'category': category,
          'date': date,
          'avatar': name.length >= 2 ? name.substring(0, 2).toUpperCase() : '??',
        });
      }
      return result;
    } catch (e) {
      print('getPendingProviders error: $e');
      return [];
    }
  }

  // ─── Open Claims ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getOpenClaims({int limit = 5}) async {
    try {
      final snap = await _db.collection('reclamations')
          .orderBy('dateCreation', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'from': data['nomClient'] ?? data['idClient'] ?? 'Inconnu',
          'subject': data['sujet'] ?? data['description'] ?? 'Sans objet',
          'priority': data['priorite'] ?? 'Normal',
          'status': data['statut'] ?? 'Ouverte',
        };
      }).toList();
    } catch (e) {
      print('getOpenClaims error: $e');
      return [];
    }
  }

  // ─── Recent Users ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRecentUsers({int limit = 5}) async {
    try {
      final snap = await _db.collection('utilisateurs')
          .orderBy('dateCreation', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        final name = data['nom'] ?? data['email'] ?? 'Utilisateur';
        final role = (data['role'] ?? '').toString().toLowerCase();
        String type = 'Client';
        if (role == 'expert') type = 'Prestataire';
        else if (role == 'admin') type = 'Admin';

        final ts = data['dateCreation'];
        String date = '';
        if (ts is Timestamp) {
          final d = ts.toDate();
          final diff = DateTime.now().difference(d);
          if (diff.inMinutes < 60) date = 'Il y a ${diff.inMinutes} min';
          else if (diff.inHours < 24) date = 'Il y a ${diff.inHours}h';
          else date = 'Il y a ${diff.inDays}j';
        }

        return {
          'name': name,
          'type': type,
          'date': date,
          'phone': data['telephone'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('getRecentUsers error: $e');
      return [];
    }
  }

  // ─── Approve / Reject Provider ───────────────────────────────────────────
  Future<void> approveProvider(String expertId) async {
    await _db.collection('experts').doc(expertId).update({'statut': 'VALIDE'});
  }

  Future<void> rejectProvider(String expertId) async {
    await _db.collection('experts').doc(expertId).update({'statut': 'REFUSE'});
  }

  // ─── Reservations by category (for bar chart) ─────────────────────────────
  Future<Map<String, int>> getReservationsByCategory() async {
    try {
      final snap = await _db.collection('interventions').get();
      Map<String, int> counts = {};
      for (var doc in snap.docs) {
        final data = doc.data();
        final cat = data['expertSnapshot']?['categorie'] ?? data['categorie'] ?? 'Autre';
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      print('getReservationsByCategory error: $e');
      return {};
    }
  }
}
