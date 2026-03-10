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
  final double totalRevenue;
  final int unreadNotifications;
  final String userGrowth;
  final String revenueGrowth;

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
    required this.totalRevenue,
    required this.unreadNotifications,
    required this.userGrowth,
    required this.revenueGrowth,
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

    // Notifications non lues
    final notifSnap = await _db.collection('notifications').where('estLue', isEqualTo: false).get();
    final unreadCount = notifSnap.docs.length;

    // Calcul de la croissance (Utilisateurs)
    final lastMonth = DateTime(now.year, now.month - 1, now.day);
    final usersLastMonthSnap = await _db.collection('utilisateurs').where('created_At', isLessThan: Timestamp.fromDate(lastMonth)).get();
    final usersLastMonth = usersLastMonthSnap.docs.length;
    String userGrowth = '';
    if (usersLastMonth > 0) {
      double growth = ((totalUsers - usersLastMonth) / usersLastMonth) * 100;
      userGrowth = '${growth >= 0 ? '+' : ''}${growth.toInt()}%';
    }

    // Calcul de la croissance (Revenus)
    double revenueLastMonth = 0;
    for (var doc in abonnementsSnap.docs) {
      final data = doc.data();
      final ts = data['createdAt'];
      if (ts is Timestamp && ts.toDate().isBefore(startOfMonth)) {
        revenueLastMonth += (data['montant'] ?? 0.0);
      }
    }
    String revGrowth = '';
    double currentMonthRevenue = totalRevenue - revenueLastMonth;
    if (revenueLastMonth > 0) {
      double growth = (currentMonthRevenue / revenueLastMonth) * 100;
      revGrowth = '${growth >= 0 ? '+' : ''}${growth.toInt()}%';
    }

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
      unreadNotifications: unreadCount,
      userGrowth: userGrowth,
      revenueGrowth: revGrowth,
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

      String? imageUrl;
      if (userId != null) {
        final userDoc = await _db.collection('utilisateurs').doc(userId).get();
        if (userDoc.exists) {
          final ud = userDoc.data()!;
          name = ud['nom'] ?? ud['email'] ?? 'Expert';
          imageUrl = ud['image_profile'];
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
        'imageUrl': imageUrl,
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
        'imageUrl': data['image_profile'],
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

  // ─── All Users (Management) ───────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final snap = await _db.collection('utilisateurs').orderBy('created_At', descending: true).get();
    
    final List<Map<String, dynamic>> result = [];
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['nom'] ?? data['email'] ?? 'Utilisateur';

      String type = 'Client';
      final expertCheck = await _db.collection('experts').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();
      final adminCheck = await _db.collection('admins').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();
      
      String status = 'Actif';
      if (adminCheck.docs.isNotEmpty) {
        type = 'Admin';
      } else if (expertCheck.docs.isNotEmpty) {
        type = 'Prestataire';
        status = expertCheck.docs.first.data()['etatCompte'] == 'ACTIVE' ? 'Actif' : 'Suspendu';
      }

      result.add({
        'id': doc.id,
        'name': name,
        'type': type,
        'date': _formatRelativeDate(data['created_At']),
        'fullDate': data['created_At'] is Timestamp ? DateFormat('dd/MM/yyyy').format((data['created_At'] as Timestamp).toDate()) : 'N/A',
        'phone': data['telephone'] ?? '',
        'imageUrl': data['image_profile'],
        'status': status,
        'avatar': name.length >= 2 ? name.substring(0, 2).toUpperCase() : '??',
      });
    }
    return result;
  }

  // ─── All Providers (Management) ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllProviders() async {
    final snap = await _db.collection('experts').get();
    final List<Map<String, dynamic>> result = [];
    
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['idUtilisateur'] as String?;
      String name = 'Expert';
      String? imageUrl;
      
      if (userId != null) {
        final userDoc = await _db.collection('utilisateurs').doc(userId).get();
        if (userDoc.exists) {
          final ud = userDoc.data()!;
          name = ud['nom'] ?? ud['email'] ?? 'Expert';
          imageUrl = ud['image_profile'];
        }
      }

      String category = 'Non défini';
      final seSnap = await _db.collection('serviceExperts').where('idExpert', isEqualTo: doc.id).limit(1).get();
      if (seSnap.docs.isNotEmpty) {
        final serviceId = seSnap.docs.first.data()['idService'];
        if (serviceId != null) {
          final serviceDoc = await _db.collection('services').doc(serviceId).get();
          if (serviceDoc.exists) category = serviceDoc.data()?['nom'] ?? 'Autre';
        }
      }

      final status = data['etatCompte'] == 'ACTIVE' ? 'Validé' : (data['etatCompte'] == 'SUSPENDUE' ? 'Suspendu' : 'En attente');
      final pack = data['packId'] == 'premium' ? 'Premium' : 'Gratuit';
      
      // Calculate average rating
      double rating = 0.0;
      final evalSnap = await _db.collection('evaluations').where('idExpert', isEqualTo: doc.id).get();
      if (evalSnap.docs.isNotEmpty) {
        double sum = 0;
        for (final e in evalSnap.docs) {
          sum += (e.data()['note'] ?? 0).toDouble();
        }
        rating = sum / evalSnap.docs.length;
      }

      result.add({
        'id': doc.id,
        'name': name,
        'category': category,
        'pack': pack,
        'rating': rating,
        'services': seSnap.docs.length, // approximation
        'status': status,
        'date': _formatRelativeDate(data['createdAt']),
        'avatar': name.length >= 2 ? name.substring(0, 2).toUpperCase() : '??',
        'imageUrl': imageUrl,
        'zone': data['region'] ?? 'N/A',
      });
    }
    return result;
  }

  // ─── All Reservations (Management) ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllReservations() async {
    final snap = await _db.collection('interventions').orderBy('dateIntervention', descending: true).get();
    final List<Map<String, dynamic>> result = [];
    
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final clientDoc = await _db.collection('utilisateurs').doc(data['idClient']).get();
      final expertDoc = await _db.collection('experts').doc(data['idExpert']).get();
      
      String expertName = 'Expert';
      if (expertDoc.exists) {
        final exUserDoc = await _db.collection('utilisateurs').doc(expertDoc.data()?['idUtilisateur']).get();
        expertName = exUserDoc.data()?['nom'] ?? exUserDoc.data()?['email'] ?? 'Expert';
      }

      result.add({
        'id': doc.id,
        'clientName': clientDoc.data()?['nom'] ?? clientDoc.data()?['email'] ?? 'Client',
        'expertName': expertName,
        'service': data['tacheSnapshot']?['serviceNom'] ?? 'Service',
        'date': data['dateIntervention']?['date'] ?? 'N/A',
        'time': data['dateIntervention']?['heure'] ?? 'N/A',
        'amount': data['tacheSnapshot']?['prix'] ?? 0,
        'status': data['statut'] ?? 'En attente',
      });
    }
    return result;
  }

  // ─── All Reviews & Claims (Management) ────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllReviews() async {
    final snap = await _db.collection('reclamations').orderBy('createdAt', descending: true).get();
    final List<Map<String, dynamic>> result = [];
    
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userDoc = await _db.collection('utilisateurs').doc(data['idUtilisateur']).get();
      
      result.add({
        'id': doc.id,
        'from': userDoc.data()?['nom'] ?? userDoc.data()?['email'] ?? 'Utilisateur',
        'subject': data['sujet'] ?? 'Sans sujet',
        'message': data['description'] ?? '',
        'priority': data['priorite'] ?? 'Normale',
        'status': data['statut'] ?? 'Ouvert',
        'date': _formatRelativeDate(data['createdAt']),
      });
    }
    return result;
  }

  // ─── Financial Transactions (Abonnements) ────────────────────────────────
  Future<List<Map<String, dynamic>>> getFinancialTransactions() async {
    final snap = await _db.collection('abonnements').orderBy('dateDebut', descending: true).get();
    final List<Map<String, dynamic>> result = [];
    
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final expertDoc = await _db.collection('experts').doc(data['idExpert']).get();
      
      String expertName = 'Expert';
      if (expertDoc.exists) {
        final exUserDoc = await _db.collection('utilisateurs').doc(expertDoc.data()?['idUtilisateur']).get();
        expertName = exUserDoc.data()?['nom'] ?? exUserDoc.data()?['email'] ?? 'Expert';
      }

      final ts = data['dateDebut'] as Timestamp?;
      final dateStr = ts != null ? DateFormat('dd/MM/yyyy').format(ts.toDate()) : 'N/A';

      result.add({
        'id': doc.id,
        'expertName': expertName,
        'pack': data['packId'] ?? 'Premium',
        'amount': data['prix'] ?? 0,
        'date': dateStr,
        'status': 'Payé', // Abonnements in collection are usually successful ones
      });
    }
    return result;
  }
}
