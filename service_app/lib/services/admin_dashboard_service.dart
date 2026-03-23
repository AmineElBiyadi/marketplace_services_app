import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_service.dart';

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
  final int cancelledReservations;
  final int totalFinishedReservations;

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
    required this.cancelledReservations,
    required this.totalFinishedReservations,
  });
}

class AdminDashboardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

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

    // Revenue total + statuts premium
    final abonnementsSnap = await _db.collection('abonnements').get();
    double totalRevenue = 0;
    int premiumCount = 0;
    final Set<String> premiumExpertIds = {};

    for (var doc in abonnementsSnap.docs) {
      final data = doc.data();
      final statut = (data['statut'] ?? '').toString().toUpperCase();
      totalRevenue += (data['montant'] ?? 0.0);
      if (statut == 'ACTIVE' || statut == 'GRACE') {
        premiumCount++;
        premiumExpertIds.add(data['idExpert']);
      }
    }

    final freeCount =
        expertsSnap.docs.where((d) => !premiumExpertIds.contains(d.id)).length;

    // Notifications non lues
    final notifSnap = await _db.collection('notifications').where('estLue', isEqualTo: false).get();
    final unreadCount = notifSnap.docs.length;

    // Calcul de la croissance (Clients)
    final lastMonth = DateTime(now.year, now.month - 1, now.day);
    final clientsLastMonthSnap = await _db.collection('clients').where('createdAt', isLessThan: Timestamp.fromDate(lastMonth)).get();
    final clientsLastMonth = clientsLastMonthSnap.docs.length;
    String userGrowth = '';
    if (clientsLastMonth > 0) {
      double growth = ((totalClients - clientsLastMonth) / clientsLastMonth) * 100;
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

    int finishedCount = 0;
    int cancelledCount = 0;
    for (var doc in allInterv) {
      final s = doc.data()['statut'];
      if (s == 'TERMINEE') finishedCount++;
      if (s == 'ANNULEE' || s == 'REFUSEE') cancelledCount++;
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
      totalRevenue: totalRevenue, // Sum of all subscription 'montant' only
      unreadNotifications: unreadCount,
      userGrowth: userGrowth,
      revenueGrowth: revGrowth,
      cancelledReservations: cancelledCount,
      totalFinishedReservations: finishedCount,
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
      String clientName = data['clientSnapshot']?['nom'] ?? 'Client';
      String expertName = data['expertSnapshot']?['nom'] ?? 'Expert';

      if (clientName == 'Client' || expertName == 'Expert') {
        final intervId = data['idIntervention'];
        if (intervId != null) {
          final intervDoc = await _db.collection('interventions').doc(intervId).get();
          if (intervDoc.exists) {
            final intervData = intervDoc.data()!;
            clientName = intervData['clientSnapshot']?['nom'] ?? clientName;
            expertName = intervData['expertSnapshot']?['nom'] ?? expertName;
          }
        }
      }

      final complainerStr = data['typeReclamateur'] == 'EXPERT' 
          ? 'Plaintif: $expertName (Expert) • Contre: $clientName'
          : 'Plaintif: $clientName (Client) • Contre: $expertName';

      result.add({
        'id': doc.id,
        'from': complainerStr,
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
      if (result.length >= limit) break;

      final data = doc.data() as Map<String, dynamic>;
      final name = data['nom'] ?? data['email'] ?? 'Utilisateur';

      final expertCheck = await _db.collection('experts').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();
      final adminCheck = await _db.collection('admins').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();
      
      if (adminCheck.docs.isNotEmpty || expertCheck.docs.isNotEmpty) {
        continue; // Skip non-clients
      }

      result.add({
        'name': name,
        'type': 'Client',
        'date': _formatRelativeDate(data['created_At']),
        'phone': data['telephone'] ?? '',
        'imageUrl': data['image_profile'],
      });
    }
    return result;
  }

  Future<void> updateProviderStatus(String expertId, String status) async {
    // Re-linking to the unified method that triggers email notifications
    await updateUserStatus(expertId, 'Prestataire', status);
  }

  Future<void> approveProvider(String expertId) async {
    await updateProviderStatus(expertId, 'ACTIVE');
  }

  Future<void> rejectProvider(String expertId) async {
    await updateProviderStatus(expertId, 'SUSPENDUE');
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
      
      String status = 'ACTIVE';
      final clientCheck = await _db.collection('clients').where('idUtilisateur', isEqualTo: doc.id).limit(1).get();
      if (clientCheck.docs.isNotEmpty) {
        status = clientCheck.docs.first.data()['etatCompte'] ?? 'ACTIVE';
      }

      if (adminCheck.docs.isNotEmpty || expertCheck.docs.isNotEmpty) {
        continue; // Skip admins and providers (experts)
      }

      result.add({
        'id': doc.id,
        'name': name,
        'type': type,
        'date': _formatRelativeDate(data['created_At']),
        'createdAt': data['created_At'] is Timestamp ? DateFormat('dd/MM/yyyy HH:mm').format((data['created_At'] as Timestamp).toDate()) : 'N/A',
        'updatedAt': data['updated_At'] is Timestamp ? DateFormat('dd/MM/yyyy HH:mm').format((data['updated_At'] as Timestamp).toDate()) : (data['created_At'] is Timestamp ? DateFormat('dd/MM/yyyy HH:mm').format((data['created_At'] as Timestamp).toDate()) : 'N/A'),
        'phone': data['telephone'] ?? '',
        'imageUrl': data['image_profile'],
        'status': status,
        'rawDate': data['created_At'] is Timestamp ? (data['created_At'] as Timestamp).toDate() : DateTime(2000),
        'avatar': name.length >= 2 ? name.substring(0, 2).toUpperCase() : '??',
      });
    }
    return result;
  }

  // ─── All Providers (Management) ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAllProviders() async {
    final snap = await _db.collection('experts').get();
    final List<Map<String, dynamic>> result = [];
    
    // Fetch all services and tasks lookup maps once to avoid multiple hits if possible, 
    // but for simple implementation we fetch per provider or as needed.
    final servicesSnap = await _db.collection('services').get();
    final Map<String, String> serviceNames = {for (var doc in servicesSnap.docs) doc.id: doc.data()['nom'] ?? ''};
    
    final tasksSnap = await _db.collection('taches').get();
    final Map<String, String> taskNames = {for (var doc in tasksSnap.docs) doc.id: doc.data()['nom'] ?? ''};

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

      // Services Join
      final List<String> services = [];
      final seSnap = await _db.collection('serviceExperts').where('idExpert', isEqualTo: doc.id).get();
      for (var seDoc in seSnap.docs) {
        final sid = seDoc.data()['idService'];
        if (serviceNames.containsKey(sid)) services.add(serviceNames[sid]!);
      }

      // Tasks Join
      final List<String> tasks = [];
      final teSnap = await _db.collection('tachesExpert').where('idExpert', isEqualTo: doc.id).get();
      for (var teDoc in teSnap.docs) {
        final tid = teDoc.data()['idTache'];
        if (taskNames.containsKey(tid)) tasks.add(taskNames[tid]!);
      }

      // Interventions Count
      final intervSnap = await _db.collection('interventions').where('idExpert', isEqualTo: doc.id).get();
      final int interventionsCount = intervSnap.docs.length;

      // Subscription check
      final subSnap = await _db.collection('abonnements')
          .where('idExpert', isEqualTo: doc.id)
          .where('statut', isEqualTo: 'ACTIVE')
          .get();
      final bool hasActiveSubscription = subSnap.docs.isNotEmpty;

      final status = data['etatCompte'] ?? 'DESACTIVE';
      final pack = hasActiveSubscription ? 'Premium' : 'Gratuit';
      
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
        'services': services,
        'tasks': tasks,
        'pack': pack,
        'hasSubscription': hasActiveSubscription,
        'rating': rating,
        'interventionsCount': interventionsCount,
        'status': status, // Raw status for buttons: ACTIVE, DESACTIVE, SUSPENDUE
        'date': _formatRelativeDate(data['createdAt']),
        'avatar': name.length >= 2 ? name.substring(0, 2).toUpperCase() : '??',
        'imageUrl': imageUrl,
        'rawDate': data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime(2000),
        'zone': (services.isNotEmpty ? services.first : (data['region'] ?? 'N/A')),
        // New detailed fields
        'CarteNationale': data['CarteNationale'] ?? 'Non fourni',
        'CasierJudiciaire': data['CasierJudiciaire'] ?? 'Non fourni',
        'Experience': data['Experience'] ?? 'Non fourni',
        'profileViews': data['profileViews'] ?? 0,
        'rayonTravaille': data['rayonTravaille'] ?? 0,
      });
    }
    return result;
  }

  // ─── All Reservations (Management) ────────────────────────────────────────
  
  /// Fetches reservations with advanced filtering and optional query.
  Future<List<Map<String, dynamic>>> getFilteredReservations({
    String? status,
    DateTimeRange? dateRange,
    String? expertId,
    String? clientId,
    String? query,
    int limit = 50,
  }) async {
    Query q = _db.collection('interventions');

    if (status != null && status != 'TOUS') {
      q = q.where('statut', isEqualTo: status);
    }
    if (expertId != null) {
      q = q.where('idExpert', isEqualTo: expertId);
    }
    if (clientId != null) {
      q = q.where('idClient', isEqualTo: clientId);
    }
    if (dateRange != null) {
      q = q.where('dateDebutIntervention', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
           .where('dateDebutIntervention', isLessThanOrEqualTo: Timestamp.fromDate(dateRange.end));
    } else {
      q = q.orderBy('createdAt', descending: true);
    }

    final snap = await q.limit(limit * 4).get(); // Increase lookback for post-fetch filtering
    final List<Map<String, dynamic>> result = [];

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Basic search logic for client/expert names if query is provided
      if (query != null && query.isNotEmpty) {
        final clientName = (data['clientSnapshot']?['nom'] ?? '').toString().toLowerCase();
        final expertName = (data['expertSnapshot']?['nom'] ?? '').toString().toLowerCase();
        final serviceName = (data['tacheSnapshot']?['serviceNom'] ?? '').toString().toLowerCase();
        final qLower = query.toLowerCase();
        
        if (!clientName.contains(qLower) && !expertName.contains(qLower) && !serviceName.contains(qLower) && !doc.id.contains(qLower)) {
          continue;
        }
      }

      result.add({
        'id': doc.id,
        'idClient': data['idClient'],
        'idExpert': data['idExpert'],
        'clientName': data['clientSnapshot']?['nom'] ?? 'Client',
        'expertName': data['expertSnapshot']?['nom'] ?? 'Expert',
        'service': data['tacheSnapshot']?['serviceNom'] ?? 'Service',
        'date': data['dateDebutIntervention'] != null 
            ? DateFormat('dd/MM/yyyy').format((data['dateDebutIntervention'] as Timestamp).toDate()) 
            : '-',
        'time': data['dateDebutIntervention'] != null 
            ? DateFormat('HH:mm').format((data['dateDebutIntervention'] as Timestamp).toDate()) 
            : '-',
        'amount': data['prixNegocie'] ?? 0,
        'status': data['statut'] ?? 'EN_ATTENTE',
        'isUrgent': data['isUrgent'] ?? false,
        'createdAt': data['createdAt'],
      });
    }
    return result;
  }

  /// Updates reservation status, adds a log entry, and sends notifications.
  Future<void> updateReservationStatus(String id, String newStatus, {String? reason}) async {
    final batch = _db.batch();
    final ref = _db.collection('interventions').doc(id);

    // 1. Update status
    batch.update(ref, {
      'statut': newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Add to timeline logs (sub-collection)
    final logRef = ref.collection('logs').doc();
    batch.set(logRef, {
      'action': 'STATUS_CHANGE',
      'fromStatus': null, // Optional: fetch old status if needed
      'toStatus': newStatus,
      'note': reason ?? 'Action par l\'administrateur',
      'timestamp': FieldValue.serverTimestamp(),
      'performedBy': 'ADMIN',
    });

    await batch.commit();

    // 3. Trigger notification
    final doc = await ref.get();
    if (doc.exists) {
      final data = doc.data()!;
      final idClient = data['idClient'];
      final idExpert = data['idExpert'];
      final service = data['tacheSnapshot']?['serviceNom'] ?? 'votre service';

      _sendNotification(
        userId: idClient,
        title: 'Mise à jour de votre réservation',
        body: 'Le statut de votre réservation pour $service est passé à $newStatus.',
      );

      _sendNotification(
        userId: idExpert,
        title: 'Mise à jour de l\'intervention',
        body: 'Le statut de l\'intervention pour $service est passé à $newStatus.',
      );
    }
  }

  /// Fetches the timeline logs for a specific reservation.
  Future<List<Map<String, dynamic>>> getReservationTimeline(String id) async {
    final snap = await _db.collection('interventions').doc(id).collection('logs').orderBy('timestamp', descending: false).get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
        'toStatus': data['toStatus'] ?? data['statut'] ?? 'ACTION',
      };
    }).toList();
  }

  /// Helper to send notifications by adding to the 'notifications' collection.
  /// Resolves the actual idUtilisateur (UID) if a collection ID (clients/experts) is passed.
  Future<void> _sendNotification({required String userId, required String title, required String body}) async {
    String resolvedUid = userId;
    
    // 1. Try resolving as Expert ID
    final expertDoc = await _db.collection('experts').doc(userId).get();
    if (expertDoc.exists) {
      resolvedUid = expertDoc.data()?['idUtilisateur'] ?? userId;
    } else {
      // 2. Try resolving as Client ID
      final clientDoc = await _db.collection('clients').doc(userId).get();
      if (clientDoc.exists) {
        resolvedUid = clientDoc.data()?['idUtilisateur'] ?? userId;
      }
    }

    await _db.collection('notifications').add({
      'idUtilisateur': resolvedUid,
      'titre': title,
      'corps': body,
      'estLue': false,
      'createdAt': FieldValue.serverTimestamp(),
      'type': 'BOOKING_UPDATE',
    });
    debugPrint('DEBUG: Admin in-app notification sent to $resolvedUid (orig: $userId)');
  }

  // ─── All Reviews & Claims (Management) ────────────────────────────────────
  
  /// Fetches all reviews/evaluations
  Future<List<Map<String, dynamic>>> getAdminEvaluations() async {
    final snap = await _db.collection('evaluations').orderBy('createdAt', descending: true).get();
    final List<Map<String, dynamic>> result = [];
    
    for (final doc in snap.docs) {
      final data = doc.data();
      String clientName = data['clientSnapshot']?['nom'] ?? 'Client';
      String expertName = data['expertSnapshot']?['nom'] ?? 'Expert';
      
      // Fallback: Si les snapshots manquent, chercher dans l'intervention
      if (clientName == 'Client' || expertName == 'Expert') {
        final intervId = data['idIntervention'];
        if (intervId != null) {
          final intervDoc = await _db.collection('interventions').doc(intervId).get();
          if (intervDoc.exists) {
            final intervData = intervDoc.data()!;
            clientName = intervData['clientSnapshot']?['nom'] ?? clientName;
            expertName = intervData['expertSnapshot']?['nom'] ?? expertName;
          }
        }
      }

      result.add({
        'id': doc.id,
        'note': (data['note'] ?? 0).toDouble(),
        'commentaire': data['commentaire'] ?? '',
        'clientName': clientName,
        'expertName': expertName,
        'idIntervention': data['idIntervention'],
        'date': data['createdAt'] != null 
            ? DateFormat('dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate()) 
            : 'N/A',
        'isHidden': data['isHidden'] ?? false,
      });
    }
    return result;
  }

  Future<void> updateEvaluationVisibility(String id, bool isHidden) async {
    await _db.collection('evaluations').doc(id).update({'isHidden': isHidden});
  }

  Future<void> deleteEvaluation(String id) async {
    await _db.collection('evaluations').doc(id).delete();
  }

  /// Fetches all claims/reclamations
  Future<List<Map<String, dynamic>>> getAdminClaims() async {
    final snap = await _db.collection('reclamations').orderBy('createdAt', descending: true).get();
    
    final Map<String, int> targetClaimCounts = {};
    for (final d in snap.docs) {
      final data = d.data();
      final isClientComplaining = (data['typeReclamateur'] ?? 'CLIENT') == 'CLIENT';
      final targetId = isClientComplaining ? data['idExpert'] : data['idClient'];
      if (targetId != null) {
        targetClaimCounts[targetId as String] = (targetClaimCounts[targetId as String] ?? 0) + 1;
      }
    }

    final List<Map<String, dynamic>> result = [];
    
    for (final doc in snap.docs) {
      final data = doc.data();
      String clientName = data['clientSnapshot']?['nom'] ?? 'Client';
      String expertName = data['expertSnapshot']?['nom'] ?? 'Expert';

      String? idClient = data['idClient'];
      String? idExpert = data['idExpert'];

      if (clientName == 'Client' || expertName == 'Expert') {
        final intervId = data['idIntervention'];
        if (intervId != null) {
          final intervDoc = await _db.collection('interventions').doc(intervId).get();
          if (intervDoc.exists) {
            final intervData = intervDoc.data()!;
            clientName = intervData['clientSnapshot']?['nom'] ?? clientName;
            expertName = intervData['expertSnapshot']?['nom'] ?? expertName;
            idClient ??= intervData['idClient'];
            idExpert ??= intervData['idExpert'];
          }
        }
      }

      final isClientComplaining = (data['typeReclamateur'] ?? 'CLIENT') == 'CLIENT';
      final targetId = isClientComplaining ? idExpert : idClient;

      result.add({
        'id': doc.id,
        'description': data['description'] ?? '',
        'typeReclamateur': data['typeReclamateur'] ?? 'CLIENT',
        'etat': data['etatReclamation'] ?? 'EN_ATTENTE',
        'idIntervention': data['idIntervention'],
        'clientName': clientName,
        'expertName': expertName,
        'idClient': idClient,
        'idExpert': idExpert,
        'targetClaimCount': targetClaimCounts[targetId] ?? 0,
        'adminResponse': data['adminResponse'],
        'date': data['createdAt'] != null 
            ? DateFormat('dd/MM/yyyy').format((data['createdAt'] as Timestamp).toDate()) 
            : '-',
      });
    }
    return result;
  }

  Future<void> updateClaim(String id, {String? status, String? response}) async {
    final Map<String, dynamic> updates = {};
    if (status != null) updates['etatReclamation'] = status;
    if (response != null) updates['adminResponse'] = response;
    updates['updatedAt'] = FieldValue.serverTimestamp();
    
    await _db.collection('reclamations').doc(id).update(updates);
  }

  Future<void> deleteClaim(String id) async {
    await _db.collection('reclamations').doc(id).delete();
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

      final tsEnd = data['dateFin'] as Timestamp?;
      final dateEndStr = tsEnd != null ? DateFormat('dd/MM/yyyy').format(tsEnd.toDate()) : 'Auto';

      final rawStatus = (data['statut'] ?? 'ACTIVE') as String;
      String statusLabel;
      switch (rawStatus.toUpperCase()) {
        case 'ACTIVE':
          statusLabel = 'Actif';
          break;
        case 'GRACE':
          statusLabel = 'Grâce';
          break;
        case 'SUSPENDU':
        case 'SUSPENDED':
          statusLabel = 'Suspendu';
          break;
        case 'EXPIREE':
        case 'EXPIRE':
        case 'EXPIRED':
          statusLabel = 'Expiré';
          break;
        case 'ANNULE':
        case 'CANCELLED':
          statusLabel = 'Annulé';
          break;
        default:
          statusLabel = rawStatus;
      }

      result.add({
        'id': doc.id,
        'expertName': expertName,
        'pack': data['packId'] ?? 'Premium',
        'amount': data['montant'] ?? data['prix'] ?? 0,
        'date': dateStr,
        'renewal': dateEndStr,
        'status': statusLabel,
      });
    }
    return result;
  }

  /// Fetches a single reservation by ID
  Future<Map<String, dynamic>?> getReservationById(String id) async {
    final doc = await _db.collection('interventions').doc(id).get();
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    String clientName = data['clientSnapshot']?['nom'] ?? 'Client';
    String expertName = data['expertSnapshot']?['nom'] ?? 'Expert';

    // If names are generic, try fetching from users
    if (clientName == 'Client' && data['idClient'] != null) {
      final cDoc = await _db.collection('clients').doc(data['idClient']).get();
      if (cDoc.exists) {
        final uDoc = await _db.collection('utilisateurs').doc(cDoc.data()?['idUtilisateur']).get();
        if (uDoc.exists) clientName = uDoc.data()?['nom'] ?? clientName;
      }
    }
    if (expertName == 'Expert' && data['idExpert'] != null) {
      final eDoc = await _db.collection('experts').doc(data['idExpert']).get();
      if (eDoc.exists) {
        final uDoc = await _db.collection('utilisateurs').doc(eDoc.data()?['idUtilisateur']).get();
        if (uDoc.exists) expertName = uDoc.data()?['nom'] ?? expertName;
      }
    }

    int cancelCount = 0;
    String cancelRole = '';
    if (data['statut'] == 'ANNULEE' && data['annulerPar'] != null) {
      cancelRole = data['annulerPar'].toString().toLowerCase();
      final targetId = cancelRole == 'expert' ? data['idExpert'] : data['idClient'];
      
      if (targetId != null) {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        
        final snap = await _db.collection('interventions')
            .where('statut', isEqualTo: 'ANNULEE')
            .where(cancelRole == 'expert' ? 'idExpert' : 'idClient', isEqualTo: targetId)
            .get();
        
        cancelCount = snap.docs.where((d) {
          final docData = d.data();
          if (docData['annulerPar']?.toString().toLowerCase() != cancelRole) return false;
          final updatedTs = docData['updatedAt'] as Timestamp? ?? docData['createdAt'] as Timestamp?;
          if (updatedTs == null) return false;
          return updatedTs.toDate().isAfter(startOfMonth) || updatedTs.toDate().isAtSameMomentAs(startOfMonth);
        }).length;
      }
    }

    return {
      'id': doc.id,
      'idClient': data['idClient'],
      'idExpert': data['idExpert'],
      'clientName': clientName,
      'expertName': expertName,
      'service': data['tacheSnapshot']?['serviceNom'] ?? 
                 data['serviceNom'] ?? 
                 data['nomService'] ?? 'Service',
      'date': data['dateDebutIntervention'] != null 
          ? DateFormat('dd/MM/yyyy').format((data['dateDebutIntervention'] as Timestamp).toDate()) 
          : '-',
      'time': data['dateDebutIntervention'] != null 
          ? DateFormat('HH:mm').format((data['dateDebutIntervention'] as Timestamp).toDate()) 
          : '-',
      'amount': data['prixNegocie'] ?? data['prix'] ?? 0,
      'status': data['statut'] ?? 'EN_ATTENTE',
      'isUrgent': data['isUrgent'] ?? false,
      'createdAt': data['createdAt'],
      'motifAnnulation': data['motifAnnulation'],
      'motifRefus': data['motifRefus'],
      'cancelCount': cancelCount,
      'cancelRole': cancelRole,
      'annulerPar': data['annulerPar'],
    };
  }

  /// Fetches a combined user profile (client or expert) for the admin management modal
  Future<Map<String, dynamic>?> getUserProfile(String id, String role) async {
    final collection = (role == 'Expert' || role == 'Prestataire') ? 'experts' : 'clients';
    DocumentSnapshot<Map<String, dynamic>> doc = await _db.collection(collection).doc(id).get();
    
    // Fallback: If not found by direct ID, search by idUtilisateur
    if (!doc.exists) {
      final snap = await _db.collection(collection).where('idUtilisateur', isEqualTo: id).limit(1).get();
      if (snap.docs.isEmpty) return null;
      doc = snap.docs.first;
    }
    
    final data = doc.data()!;
    final userId = data['idUtilisateur'];
    final userDoc = await _db.collection('utilisateurs').doc(userId).get();
    final userData = userDoc.data() ?? {};
    
    // Resolve City from addresses
    String ville = 'N/A';
    try {
      final addrSnap = await _db.collection('adresses')
          .where('idUtilisateur', isEqualTo: userId)
          .limit(1)
          .get();
      if (addrSnap.docs.isNotEmpty) {
        final a = addrSnap.docs.first.data();
        ville = '${a['Ville'] ?? a['ville'] ?? ''}${a['Quartier'] != null ? ', ${a['Quartier']}' : ''}';
        if (ville.isEmpty) ville = 'N/A';
      }
    } catch (_) {}

    return {
      'id': id,
      'userId': userId,
      'name': userData['nom'] ?? userData['name'] ?? userData['email'] ?? role,
      'email': userData['email'] ?? '',
      'phone': userData['telephone'] ?? userData['phone'] ?? '',
      'status': data['etatCompte'] ?? 'ACTIVE',
      'role': role,
      'imageUrl': userData['image_profile'] ?? userData['photoUrl'],
      'region': ville,
      // Professional Docs and Stats (for Experts)
      'CarteNationale': data['CarteNationale'] ?? 'N/A',
      'CasierJudiciaire': data['CasierJudiciaire'] ?? 'N/A',
      'Experience': data['Experience'] ?? 'N/A',
      'rating': (data['rating'] ?? 0.0) as double,
      'interventionsCount': data['interventionsCount'] ?? 0,
      'rayonTravaille': data['rayonTravaille'],
      'services': data['services'] ?? [],
      'tasks': data['tasks'] ?? [],
    };
  }

  /// Updates the account status in the role collection (experts or clients)
  Future<void> updateUserStatus(String id, String role, String status) async {
    final collection = (role == 'Expert' || role == 'Prestataire') ? 'experts' : 'clients';
    DocumentReference docRef = _db.collection(collection).doc(id);
    
    // Fallback: If not found by direct ID, search by idUtilisateur
    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      final snap = await _db.collection(collection).where('idUtilisateur', isEqualTo: id).limit(1).get();
      if (snap.docs.isNotEmpty) {
        docRef = snap.docs.first.reference;
      } else {
        // Create the document if it doesn't exist so we can set the status
        await docRef.set({
          'idUtilisateur': id,
          'etatCompte': status,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    Map<String, dynamic> updates = {
      'etatCompte': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (collection == 'experts') {
      if (status == 'DESACTIVE' || status == 'SUSPENDUE') {
        updates['desactiveParAdmin'] = true;
      } else if (status == 'ACTIVE') {
        updates['desactiveParAdmin'] = false;
      }
    }
    
    await docRef.update(updates);

    // Resolve idUtilisateur for notification
    String? idUtilisateur;
    if (docSnap.exists) {
      final data = docSnap.data() as Map<String, dynamic>?;
      idUtilisateur = data?['idUtilisateur'];
    } else {
      idUtilisateur = id; // id was already the UID
    }

    if (idUtilisateur != null) {
      await _notificationService.sendNotification(
        idUtilisateur: idUtilisateur,
        titre: status == 'ACTIVE' 
            ? "Compte Activé" 
            : (status == 'SUSPENDUE' ? "Compte Suspendu" : "Compte Désactivé"),
        corps: status == 'ACTIVE' 
            ? "Bonne nouvelle ! Votre compte a été activé par l'administration." 
            : (status == 'SUSPENDUE' 
                ? "Votre compte a été suspendu temporairement pour vérification." 
                : "Votre compte a été désactivé par un administrateur."),
        type: 'account',
        relatedId: idUtilisateur,
      );
    }

    debugPrint('DEBUG: updateUserStatus called for $id ($role) to $status');
    // Automatically send an email notification for important status changes
    if (status == 'SUSPENDUE' || status == 'ACTIVE' || status == 'DESACTIVE') {
      final profile = await getUserProfile(id, role);
      debugPrint('DEBUG: profile resolved: ${profile?['name']} - ${profile?['email']}');
      
      if (profile != null && profile['email'] != null && profile['email'].isNotEmpty) {
        String subject = "";
        String title = "";
        String desc = "";
        String color = "#4F46E5"; // Default primary
        
        if (status == 'ACTIVE') {
          subject = "🎉 Votre compte a été activé !";
          title = "Bienvenue sur Marketplace";
          desc = "Félicitations <b>${profile['name']}</b>,<br><br>Votre compte est désormais entièrement vérifié et actif sur notre plateforme. Vous pouvez dès à présent profiter de toutes les fonctionnalités et commencer à interagir avec notre communauté.";
          color = "#10B981"; // success green
        } else if (status == 'SUSPENDUE') {
          subject = "⚠️ Votre compte a été temporairement suspendu";
          title = "Action requise sur votre compte";
          desc = "Bonjour <b>${profile['name']}</b>,<br><br>Nous vous informons que votre compte a été temporairement suspendu par notre équipe d'administration dans le cadre d'une vérification de routine.<br><br>Pour nous aider à rétablir votre accès rapidement, veuillez répondre à cet email ou contacter le support client.";
          color = "#F59E0B"; // warning orange
        } else if (status == 'DESACTIVE') {
          subject = "❌ Désactivation de votre compte";
          title = "Compte désactivé";
          desc = "Bonjour <b>${profile['name']}</b>,<br><br>Nous vous informons que votre compte a été désactivé suite à une décision administrative.<br><br>Si vous pensez qu'il s'agit d'une erreur, merci de contacter immédiatement notre support par email.";
          color = "#EF4444"; // danger red
        }

        final htmlBody = '''
        <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 600px; margin: 0 auto; background-color: #f9fafb; padding: 40px 20px; border-radius: 8px;">
          <div style="background-color: white; padding: 40px; border-radius: 16px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); border-top: 6px solid $color;">
            <h2 style="color: #111827; font-size: 24px; margin-top: 0; margin-bottom: 24px;">\$title</h2>
            <p style="color: #4b5563; font-size: 16px; line-height: 1.6; margin-bottom: 32px;">
              \$desc
            </p>
            <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 32px 0;">
            <p style="color: #6b7280; font-size: 14px; margin: 0;">
              Cordialement,<br>
              <strong>L'équipe d'administration Marketplace</strong>
            </p>
          </div>
        </div>
        ''';

        await sendAutomaticEmail(
          to: profile['email'],
          subject: subject,
          html: htmlBody.replaceAll('\$', ''), // Remove literal escape
        );
      } else {
        debugPrint('DEBUG: No email found for user $id');
      }
    }
  }

  /// Sends an automated email using a zero-cost Google Apps Script Bridge
  Future<void> sendAutomaticEmail({
    required String to,
    required String subject,
    String? text,
    String? html,
  }) async {
    final scriptUrl = dotenv.get('GOOGLE_APPS_SCRIPT_URL', fallback: '');
    debugPrint('DEBUG: sendAutomaticEmail hit for $to. URL: $scriptUrl');

    if (scriptUrl.isEmpty || scriptUrl.contains('VOTRE_ID')) {
      debugPrint("Email Error: GOOGLE_APPS_SCRIPT_URL is not configured in .env");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(scriptUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'to': to,
          'subject': subject,
          'text': text ?? '',
          'html': html ?? '',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        debugPrint('Google Bridge: Email sent successfully');
      } else {
        debugPrint('Google Bridge Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Error calling Google Email Bridge: $e");
    }
  }

  // ─── Grace Subscriptions (Paiements Échoués) ────────────────────────────────
  /// Returns all subscriptions currently in GRACE period (failed payment, retrying).
  Future<List<Map<String, dynamic>>> getGraceSubscriptions() async {
    final snap = await _db
        .collection('abonnements')
        .where('statut', whereIn: ['GRACE', 'SUSPENDU', 'SUSPENDED'])
        .get();
    final List<Map<String, dynamic>> result = [];

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final expertDoc = await _db.collection('experts').doc(data['idExpert']).get();
      String expertName = 'Expert';
      if (expertDoc.exists) {
        final exUserDoc = await _db
            .collection('utilisateurs')
            .doc(expertDoc.data()?['idUtilisateur'])
            .get();
        expertName = exUserDoc.data()?['nom'] ?? exUserDoc.data()?['email'] ?? 'Expert';
      }

      final graceTs = (data['graceStartedAt'] ?? data['updatedAt']) as Timestamp?;
      final dateStr = graceTs != null
          ? DateFormat('dd/MM/yyyy').format(graceTs.toDate())
          : 'N/A';

      result.add({
        'id': doc.id,
        'idExpert': data['idExpert'],
        'provider': expertName,
        'amount': '${data['montant'] ?? 99} DH',
        'date': dateStr,
        'attempts': (data['retryCount'] ?? 1) as int,
      });
    }
    return result;
  }

  /// Admin: manually suspends a subscription.
  Future<void> suspendSubscription(String subscriptionId) async {
    await _db.collection('abonnements').doc(subscriptionId).update({
      'statut': 'SUSPENDU',
      'suspendedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin: reactivates a suspended/grace subscription.
  Future<void> reactivateSubscription(String subscriptionId) async {
    await _db.collection('abonnements').doc(subscriptionId).update({
      'statut': 'ACTIVE',
      'suspendedAt': null,
      'graceStartedAt': null,
      'retryCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Admin: met à jour le montant de tous les abonnements actuels
  Future<void> updateAllSubscriptionsPrice(double newPrice) async {
    final snap = await _db.collection('abonnements').get();
    
    // Firestore batch writes have a limit of 500 operations per batch
    List<WriteBatch> batches = [];
    WriteBatch currentBatch = _db.batch();
    int opCount = 0;

    for (var doc in snap.docs) {
      if (opCount == 490) {
        batches.add(currentBatch);
        currentBatch = _db.batch();
        opCount = 0;
      }
      currentBatch.update(doc.reference, {
        'montant': newPrice,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      opCount++;
    }
    
    if (opCount > 0) {
      batches.add(currentBatch);
    }

    for (var batch in batches) {
      await batch.commit();
    }
  }

  // ─── CGU Management ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getActiveCgu(String type) async {
    final snap = await _db
        .collection('cgu')
        .where('type', isEqualTo: type)
        .where('is_active', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return {'id': snap.docs.first.id, ...snap.docs.first.data()};
  }

  Future<void> createNewCguVersion(String type, String content, String version) async {
    final batch = _db.batch();

    // 1. Deactivate old versions
    final oldActiveSnap = await _db
        .collection('cgu')
        .where('type', isEqualTo: type)
        .where('is_active', isEqualTo: true)
        .get();

    for (var doc in oldActiveSnap.docs) {
      batch.update(doc.reference, {'is_active': false});
    }

    // 2. Create new version
    final newDocRef = _db.collection('cgu').doc();
    batch.set(newDocRef, {
      'type': type,
      'content': content,
      'version': version,
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getCguHistory(String type) async {
    final snap = await _db
        .collection('cgu')
        .where('type', isEqualTo: type)
        .get();

    final docs = snap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();

    // Sort in memory by created_at descending
    docs.sort((a, b) {
      final ta = a['created_at'] as Timestamp?;
      final tb = b['created_at'] as Timestamp?;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    return docs;
  }

  Future<Map<String, dynamic>?> getMaintenanceSettings() async {
    final doc = await _db.collection('settings').doc('global_config').get();
    return doc.data();
  }

  Future<void> updateMaintenanceSettings(bool isMaintenance, String message) async {
    await _db.collection('settings').doc('global_config').set({
      'is_maintenance': isMaintenance,
      'maintenance_message': message,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─── Services & Tasks Management ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getServices() async {
    final snap = await _db.collection('services').orderBy('nom').get();
    return snap.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  Future<void> addService(Map<String, dynamic> data) async {
    await _db.collection('services').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    await _db.collection('services').doc(id).update(data);
  }

  Future<void> deleteService(String id) async {
    // Delete service
    await _db.collection('services').doc(id).delete();

    // Delete tasks associated with this service
    final tasksSnap = await _db.collection('taches').where('idService', isEqualTo: id).get();
    final batch = _db.batch();
    for (var doc in tasksSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getTasksByService(String serviceId) async {
    final snap = await _db.collection('taches')
        .where('idService', isEqualTo: serviceId)
        .get();

    final docs = snap.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .where((task) => task['idExpert'] == null || task['idExpert'] == "" || task['idExpert'] == "null")
        .toList();

    docs.sort((a, b) => (a['nom'] ?? '').toString().compareTo((b['nom'] ?? '').toString()));

    return docs;
  }

  Future<void> addTask(Map<String, dynamic> data) async {
    await _db.collection('taches').add({
      ...data,
      'idExpert': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTask(String id, Map<String, dynamic> data) async {
    await _db.collection('taches').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTask(String id) async {
    await _db.collection('taches').doc(id).delete();
  }
}
