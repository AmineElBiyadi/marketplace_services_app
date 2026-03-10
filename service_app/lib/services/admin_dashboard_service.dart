import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  final double totalRevenue; // AJOUTÉ

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
    required this.totalRevenue, // AJOUTÉ
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
    final pendingSnap = await _db
        .collection('experts')
        .where('etatCompte', isEqualTo: 'EN_ATTENTE')
        .get();
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
    for (final doc in allInterv) {
      final data = doc.data();
      final ts = data['createdAt'];
      if (ts is Timestamp && ts.toDate().isAfter(startOfMonth)) {
        thisMonth++;
      }
    }

    // Note moyenne depuis la collection 'evaluations' (plus précis)
    final evalSnap = await _db.collection('evaluations').get();
    double totalRating = 0;
    if (evalSnap.docs.isNotEmpty) {
      for (var doc in evalSnap.docs) {
        totalRating += (doc.data()['note'] ?? 0.0);
      }
    }
    final avgRating = evalSnap.docs.isNotEmpty ? totalRating / evalSnap.docs.length : 0.0;

    // Réclamations ouvertes
    final claimsSnap1 = await _db
        .collection('reclamations')
        .where('etatReclamation', isEqualTo: 'EN_ATTENTE')
        .get();
    final claimsSnap2 = await _db
        .collection('reclamations')
        .where('etatReclamation', isEqualTo: 'OUVERTE')
        .get();
    final openClaims = claimsSnap1.docs.length + claimsSnap2.docs.length;

    // Revenue total: Somme des montants d'abonnements
    final abonnementsSnap = await _db.collection('abonnements').get();
    double totalRevenue = 0;
    int premiumCount = 0;
    final Set<String> premiumExpertIds = {};

    for (var doc in abonnementsSnap.docs) {
      final data = doc.data();
      totalRevenue += (data['montant'] ?? 0.0);
      if (data['statut'] == 'ACTIVE') {
        premiumCount++;
        premiumExpertIds.add(data['idExpert']);
      }
    }

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
      averageRating: avgRating,
      freeProviders: freeCount,
      premiumProviders: premiumCount,
      totalRevenue: totalRevenue,
    );
  }

  // ─── Daily Inscriptions (last 30 days) ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDailyInscriptions() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    // On récupère les utilisateurs des 30 derniers jours
    final usersSnap = await _db
        .collection('utilisateurs')
        .where('created_At', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    // Map pour stocker par jour: { '2024-03-01': { 'Clients': 5, 'Experts': 2 } }
    final Map<String, Map<String, int>> dailyCounts = {};

    // Initialiser les 30 jours pour avoir des zéros
    for (int i = 0; i <= 30; i++) {
        final date = now.subtract(Duration(days: 30 - i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        dailyCounts[key] = {'Clients': 0, 'Experts': 0};
    }

    for (var doc in usersSnap.docs) {
      final data = doc.data();
      final ts = data['created_At'] as Timestamp;
      final key = DateFormat('yyyy-MM-dd').format(ts.toDate());
      
      if (dailyCounts.containsKey(key)) {
        // Déterminer le rôle
        final isExpert = (await _db.collection('experts').where('idUtilisateur', isEqualTo: doc.id).limit(1).get()).docs.isNotEmpty;
        if (isExpert) {
          dailyCounts[key]!['Experts'] = dailyCounts[key]!['Experts']! + 1;
        } else {
          dailyCounts[key]!['Clients'] = dailyCounts[key]!['Clients']! + 1;
        }
      }
    }

    // Convertir en liste ordonnée pour le graphe
    List<String> sortedKeys = dailyCounts.keys.toList()..sort();
    return sortedKeys.map((key) => {
      'day': key,
      'clients': dailyCounts[key]!['Clients'],
      'experts': dailyCounts[key]!['Experts'],
    }).toList();
  }

  // ─── Monthly Revenue (last 12 months) ──────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMonthlyRevenue() async {
    final now = DateTime.now();
    final twelveMonthsAgo = DateTime(now.year, now.month - 11, 1);
    
    final abonnementsSnap = await _db
        .collection('abonnements')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(twelveMonthsAgo))
        .get();

    final Map<String, double> monthlyData = {};

    // Initialiser les 12 mois
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM').format(date);
      monthlyData[key] = 0.0;
    }

    for (var doc in abonnementsSnap.docs) {
      final data = doc.data();
      final ts = data['createdAt'] as Timestamp;
      final key = DateFormat('MMM').format(ts.toDate());
      if (monthlyData.containsKey(key)) {
        monthlyData[key] = monthlyData[key]! + (data['montant'] ?? 0.0);
      }
    }

    // Liste des mois dans l'ordre chronologique
    List<String> months = [];
    for (int i = 11; i >= 0; i--) {
      months.add(DateFormat('MMM').format(DateTime(now.year, now.month - i, 1)));
    }

    return months.map((m) => {
      'month': m,
      'revenue': monthlyData[m],
    }).toList();
  }

  // ─── Pending Providers ─────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingProviders({int limit = 5}) async {
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
        final userDoc = await _db.collection('utilisateurs').doc(userId).get();
        if (userDoc.exists) {
          final ud = userDoc.data()!;
          name = ud['nom'] ?? ud['email'] ?? 'Expert';
        }
      }

      String category = '';
      final seSnap = await _db.collection('serviceExperts').where('idExpert', isEqualTo: doc.id).limit(1).get();
      if (seSnap.docs.isNotEmpty) {
        final serviceId = seSnap.docs.first.data()['idService'];
        if (serviceId != null) {
          final serviceDoc = await _db.collection('services').doc(serviceId).get();
          if (serviceDoc.exists) category = serviceDoc.data()?['nom'] ?? '';
        }
      }

      final ts = data['createdAt'];
      String date = _formatRelativeDate(ts);

      result.add({
        'id': doc.id,
        'name': name,
        'category': category,
        'date': date,
        'avatar': name.length >= 2 ? name.substring(0, 2).toUpperCase() : '??',
      });
    }
    return result;
  }

  // ─── Helper: Format Relative Date ──────────────────────────────────────────
  String _formatRelativeDate(dynamic ts) {
    if (ts is! Timestamp) return '';
    final d = ts.toDate();
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  // ─── Open Claims ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getOpenClaims({int limit = 5}) async {
    final snap = await _db
        .collection('reclamations')
        .where('etatReclamation', isEqualTo: 'EN_ATTENTE')
        .limit(limit)
        .get();

    final List<Map<String, dynamic>> result = [];
    for (final doc in snap.docs) {
      final data = doc.data();
      String clientName = 'Inconnu';
      final clientId = data['idClient'] as String?;
      if (clientId != null) {
        final clientDoc = await _db.collection('clients').doc(clientId).get();
        if (clientDoc.exists) {
          final idUtil = clientDoc.data()?['idUtilisateur'] as String?;
          if (idUtil != null) {
            final userDoc = await _db.collection('utilisateurs').doc(idUtil).get();
            if (userDoc.exists) clientName = userDoc.data()?['nom'] ?? userDoc.data()?['email'] ?? clientId;
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
    QuerySnapshot snap;
    try {
      snap = await _db.collection('utilisateurs').orderBy('created_At', descending: true).limit(limit).get();
    } catch (_) {
      snap = await _db.collection('utilisateurs').limit(limit).get();
    }

    final List<Map<String, dynamic>> result = [];
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['nom'] ?? data['email'] ?? 'Utilisateur';

      String type = 'Client';
      final expertCheck = await _db.collection('experts').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();
      final adminCheck = await _db.collection('admins').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();
      if (adminCheck.docs.isNotEmpty) type = 'Admin';
      else if (expertCheck.docs.isNotEmpty) type = 'Prestataire';

      result.add({
        'name': name,
        'type': type,
        'date': _formatRelativeDate(data['created_At']),
        'phone': data['telephone'] ?? '',
      });
    }
    return result;
  }

  // ─── Actions ──────────────────────────────────────────────────────────────
  Future<void> approveProvider(String expertId) async {
    await _db.collection('experts').doc(expertId).update({'etatCompte': 'ACTIVE'});
  }

  Future<void> rejectProvider(String expertId) async {
    await _db.collection('experts').doc(expertId).update({'etatCompte': 'SUSPENDUE'});
  }

  // ─── Reservations by category ─────────────────────────────────────────────
  Future<Map<String, int>> getReservationsByCategory() async {
    final snap = await _db.collection('interventions').get();
    final Map<String, int> counts = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      final cat = data['tacheSnapshot']?['serviceNom'] ?? 'Autre';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }
}
