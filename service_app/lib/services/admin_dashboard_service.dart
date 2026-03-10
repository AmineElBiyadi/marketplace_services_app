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
    // Clients → collection 'clients'
    final clientsSnap = await _db.collection('clients').get();
    final totalClients = clientsSnap.docs.length;

    // Experts → collection 'experts'
    final expertsSnap = await _db.collection('experts').get();
    final totalProviders = expertsSnap.docs.length;

    // Total utilisateurs
    final usersSnap = await _db.collection('utilisateurs').get();
    final totalUsers = usersSnap.docs.length;

    // Experts en attente de validation
    // etatCompte peut être : ACTIVE | DESACTIVE | SUSPENDUE | EN_ATTENTE
    final pendingSnap = await _db
        .collection('experts')
        .where('etatCompte', isEqualTo: 'EN_ATTENTE')
        .get();
    // Aussi chercher 'En attente' (format français utilisé dans l'UI)
    final pendingSnap2 = await _db
        .collection('experts')
        .where('etatCompte', isEqualTo: 'En attente')
        .get();
    final pendingCount =
        pendingSnap.docs.length + pendingSnap2.docs.length;

    // Interventions / Réservations
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final interventionsSnap = await _db.collection('interventions').get();
    final allInterv = interventionsSnap.docs;

    int thisMonth = 0;
    double totalRating = 0;
    int ratingCount = 0;

    for (final doc in allInterv) {
      final data = doc.data();

      // Date: champ 'createdAt' dans le seed
      final ts = data['createdAt'];
      if (ts is Timestamp && ts.toDate().isAfter(startOfMonth)) {
        thisMonth++;
      }

      // Note depuis expertSnapshot.note_moyenne
      final note = data['expertSnapshot']?['note_moyenne'];
      if (note != null) {
        totalRating += (note as num).toDouble();
        ratingCount++;
      }
    }

    // Réclamations ouvertes: champ 'etatReclamation' == 'EN_ATTENTE' ou 'OUVERTE'
    final claimsSnap1 = await _db
        .collection('reclamations')
        .where('etatReclamation', isEqualTo: 'EN_ATTENTE')
        .get();
    final claimsSnap2 = await _db
        .collection('reclamations')
        .where('etatReclamation', isEqualTo: 'OUVERTE')
        .get();
    final openClaims = claimsSnap1.docs.length + claimsSnap2.docs.length;

    // Premium vs Gratuit: abonnements avec statut == 'ACTIVE'
    final abonnementsSnap = await _db
        .collection('abonnements')
        .where('statut', isEqualTo: 'ACTIVE')
        .get();
    final premiumExpertIds =
        abonnementsSnap.docs.map((d) => d.data()['idExpert']).toSet();
    final freeCount =
        expertsSnap.docs.where((d) => !premiumExpertIds.contains(d.id)).length;

    return AdminDashboardStats(
      totalUsers: totalUsers,
      totalClients: totalClients,
      totalProviders: totalProviders,
      pendingProviders: pendingCount,
      totalReservations: allInterv.length,
      reservationsThisMonth: thisMonth,
      openClaims: openClaims,
      averageRating:
          ratingCount > 0 ? (totalRating / ratingCount) : 0.0,
      freeProviders: freeCount,
      premiumProviders: premiumExpertIds.length,
    );
  }

  // ─── Pending Providers ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingProviders({int limit = 5}) async {
    // Chercher experts EN_ATTENTE ou 'En attente'
    final snap1 = await _db
        .collection('experts')
        .where('etatCompte', isEqualTo: 'EN_ATTENTE')
        .limit(limit)
        .get();
    final snap2 = await _db
        .collection('experts')
        .where('etatCompte', isEqualTo: 'En attente')
        .limit(limit)
        .get();

    final allDocs = [...snap1.docs, ...snap2.docs];
    if (allDocs.isEmpty) return [];

    final List<Map<String, dynamic>> result = [];

    for (final doc in allDocs.take(limit)) {
      final data = doc.data();
      final userId = data['idUtilisateur'] as String?;
      String name = 'Expert';

      if (userId != null) {
        final userDoc =
            await _db.collection('utilisateurs').doc(userId).get();
        if (userDoc.exists) {
          final ud = userDoc.data()!;
          // nom n'existe pas dans le seed, fallback sur email
          name = ud['nom'] ?? ud['email'] ?? 'Expert';
        }
      }

      // Service principal depuis serviceExperts
      String category = '';
      final seSnap = await _db
          .collection('serviceExperts')
          .where('idExpert', isEqualTo: doc.id)
          .limit(1)
          .get();
      if (seSnap.docs.isNotEmpty) {
        final serviceId = seSnap.docs.first.data()['idService'];
        if (serviceId != null) {
          final serviceDoc =
              await _db.collection('services').doc(serviceId).get();
          if (serviceDoc.exists) {
            category = serviceDoc.data()?['nom'] ?? '';
          }
        }
      }

      // Date: champ 'createdAt' dans le seed
      final ts = data['createdAt'];
      String date = '';
      if (ts is Timestamp) {
        final d = ts.toDate();
        final diff = DateTime.now().difference(d);
        if (diff.inMinutes < 60) {
          date = 'Il y a ${diff.inMinutes} min';
        } else if (diff.inHours < 24) {
          date = 'Il y a ${diff.inHours}h';
        } else {
          date = 'Il y a ${diff.inDays}j';
        }
      }

      result.add({
        'id': doc.id,
        'name': name,
        'category': category,
        'date': date,
        'avatar': name.length >= 2
            ? name.substring(0, 2).toUpperCase()
            : '??',
      });
    }

    return result;
  }

  // ─── Open Claims ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getOpenClaims({int limit = 5}) async {
    // etatReclamation: 'EN_ATTENTE' | 'TRAITEE'
    // On prend les EN_ATTENTE (= ouvertes)
    final snap = await _db
        .collection('reclamations')
        .where('etatReclamation', isEqualTo: 'EN_ATTENTE')
        .limit(limit)
        .get();

    final List<Map<String, dynamic>> result = [];

    for (final doc in snap.docs) {
      final data = doc.data();

      // Résoudre le nom du client depuis idClient → clients → utilisateurs
      String clientName = data['idClient'] ?? 'Inconnu';
      final clientId = data['idClient'] as String?;
      if (clientId != null) {
        final clientDoc =
            await _db.collection('clients').doc(clientId).get();
        if (clientDoc.exists) {
          final idUtil = clientDoc.data()?['idUtilisateur'] as String?;
          if (idUtil != null) {
            final userDoc =
                await _db.collection('utilisateurs').doc(idUtil).get();
            if (userDoc.exists) {
              clientName =
                  userDoc.data()?['nom'] ?? userDoc.data()?['email'] ?? clientId;
            }
          }
        }
      }

      result.add({
        'id': doc.id,
        'from': clientName,
        'subject': data['description'] ?? 'Sans objet',
        'priority': data['typeReclamateur'] == 'CLIENT' ? 'Normal' : 'Urgent',
        'status': data['etatReclamation'] ?? 'EN_ATTENTE',
      });
    }

    return result;
  }

  // ─── Recent Users ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getRecentUsers({int limit = 5}) async {
    // Champ: created_At (avec underscore, selon le seed)
    QuerySnapshot snap;
    try {
      snap = await _db
          .collection('utilisateurs')
          .orderBy('created_At', descending: true)
          .limit(limit)
          .get();
    } catch (_) {
      // Fallback si l'index n'existe pas
      snap = await _db.collection('utilisateurs').limit(limit).get();
    }

    final List<Map<String, dynamic>> result = [];

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['nom'] ?? data['email'] ?? 'Utilisateur';

      // Déterminer le rôle via les collections clients/experts/admins
      String type = 'Client';
      final clientCheck =
          await _db.collection('clients').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();
      final expertCheck =
          await _db.collection('experts').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();
      final adminCheck =
          await _db.collection('admins').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();

      if (adminCheck.docs.isNotEmpty) {
        type = 'Admin';
      } else if (expertCheck.docs.isNotEmpty) {
        type = 'Prestataire';
      } else if (clientCheck.docs.isNotEmpty) {
        type = 'Client';
      }

      // Date: created_At
      final ts = data['created_At'];
      String date = '';
      if (ts is Timestamp) {
        final d = ts.toDate();
        final diff = DateTime.now().difference(d);
        if (diff.inMinutes < 60) {
          date = 'Il y a ${diff.inMinutes} min';
        } else if (diff.inHours < 24) {
          date = 'Il y a ${diff.inHours}h';
        } else {
          date = 'Il y a ${diff.inDays}j';
        }
      }

      result.add({
        'name': name,
        'type': type,
        'date': date,
        'phone': data['telephone'] ?? '',
      });
    }

    return result;
  }

  // ─── Approve / Reject Provider ───────────────────────────────────────────
  Future<void> approveProvider(String expertId) async {
    await _db.collection('experts').doc(expertId).update({
      'etatCompte': 'ACTIVE',
    });
  }

  Future<void> rejectProvider(String expertId) async {
    await _db.collection('experts').doc(expertId).update({
      'etatCompte': 'SUSPENDUE',
    });
  }

  // ─── Reservations by category (for bar chart) ─────────────────────────────
  Future<Map<String, int>> getReservationsByCategory() async {
    final snap = await _db.collection('interventions').get();
    final Map<String, int> counts = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      // serviceNom est dans tacheSnapshot.serviceNom
      final cat = data['tacheSnapshot']?['serviceNom'] ??
          data['expertSnapshot']?['categorie'] ??
          'Autre';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }
}
