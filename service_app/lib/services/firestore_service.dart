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
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expert.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Expert>> getExperts() async {
    try {
      final expertsSnapshot = await _db.collection('experts').get();
      List<Expert> experts = [];

      for (var expertDoc in expertsSnapshot.docs) {
        final expertData = expertDoc.data();
        final expertId = expertDoc.id;
        final userId = expertData['idUtilisateur'];

        // 1 — Récupérer l'utilisateur lié
        final userDoc = await _db
            .collection('utilisateurs')
            .doc(userId)
            .get();
        final userData = userDoc.data() ?? {};

        // 2 — Récupérer la ville depuis adresses
        final adresseSnapshot = await _db
            .collection('adresses')
            .where('idUtilisateur', isEqualTo: userId)
            .get();

        String ville = '';
        if (adresseSnapshot.docs.isNotEmpty) {
          final adresse = adresseSnapshot.docs.first.data();
          ville =
          '${adresse['Ville'] ?? ''}, ${adresse['Quartier'] ?? ''}';
        }

        // 3 — Vérifier si Premium
        final abonnementSnapshot = await _db
            .collection('abonnements')
            .where('idExpert', isEqualTo: expertId)
            .where('statut', isEqualTo: 'ACTIVE')
            .get();
        final isPremium = abonnementSnapshot.docs.isNotEmpty;

        // 4 — Récupérer les services
        final serviceExpertsSnapshot = await _db
            .collection('serviceExperts')
            .where('idExpert', isEqualTo: expertId)
            .get();

        List<String> services = [];
        for (var se in serviceExpertsSnapshot.docs) {
          final serviceDoc = await _db
              .collection('services')
              .doc(se.data()['idService'])
              .get();
          if (serviceDoc.exists) {
            services.add(serviceDoc.data()?['nom'] ?? '');
          }
        }

        // 5 — Récupérer note moyenne
        final interventionsSnapshot = await _db
            .collection('interventions')
            .where('idExpert', isEqualTo: expertId)
            .get();

        double noteMoyenne = 0.0;
        if (interventionsSnapshot.docs.isNotEmpty) {
          final firstIntervention =
          interventionsSnapshot.docs.first.data();
          noteMoyenne = (firstIntervention['expertSnapshot']
          ?['note_moyenne'] ??
              0.0)
              .toDouble();
        }

        // 6 — Construire Expert
        experts.add(Expert(
          id: expertId,
          nom: userData['nom'] ?? userData['email'] ?? 'Expert',
          photo: userData['image_profile'] ?? '',
          telephone: userData['telephone'] ?? '',
          noteMoyenne: noteMoyenne,
          isPremium: isPremium,
          services: services,
          ville: ville,
        ));
      }

      // 7 — Trier : Premium en premier, ensuite par note
      experts.sort((a, b) {
        if (a.isPremium && !b.isPremium) return -1;
        if (!a.isPremium && b.isPremium) return 1;
        return b.noteMoyenne.compareTo(a.noteMoyenne);
      });

      return experts;
    } catch (e) {
      print('Erreur getExperts: $e');
      return [];
    }
  }

  // Récupérer toutes les villes des experts
  Future<List<String>> getVillesExperts() async {
    try {
      final expertsSnapshot = await _db.collection('experts').get();
      Set<String> villes = {};

      for (var expertDoc in expertsSnapshot.docs) {
        final userId = expertDoc.data()['idUtilisateur'];

        final adresseSnapshot = await _db
            .collection('adresses')
            .where('idUtilisateur', isEqualTo: userId)
            .get();

        if (adresseSnapshot.docs.isNotEmpty) {
          final adresse = adresseSnapshot.docs.first.data();
          final ville =
              '${adresse['Ville'] ?? ''}, ${adresse['Quartier'] ?? ''}';
          if (ville.trim() != ',') villes.add(ville);
        }
      }

      return villes.toList();
    } catch (e) {
      print('Erreur getVillesExperts: $e');
      return [];
    }
  }
}import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'hash_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Utilisateurs (Shared) ─────────────────────────────────

  /// Checks if a user already exists with the given phone or email
  Future<String?> checkUserExists({required String phone, required String email}) async {
    // Check phone
    final phoneQuery = await _firestore
        .collection('utilisateurs')
        .where('telephone', isEqualTo: phone)
        .limit(1)
        .get();
        
    if (phoneQuery.docs.isNotEmpty) {
      return 'phone';
    }

    // Check email
    final emailQuery = await _firestore
        .collection('utilisateurs')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (emailQuery.docs.isNotEmpty) {
      return 'email';
    }
    
    return null; // Neither exists
  }

  // ─── Clients ───────────────────────────────────────────────
  
  /// Register a new client
  Future<void> registerClient({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    // Hash password before saving
    final hashedPassword = HashService.hashPassword(password);
    
    // 1. Create the document in 'utilisateurs' collection
    final userRef = await _firestore.collection('utilisateurs').add({
      'created_At': FieldValue.serverTimestamp(),
      'updated_At': FieldValue.serverTimestamp(),
      'email': email,
      'image_profile': null,
      'location': null,
      'motDePasse': hashedPassword,
      'nom': name,
      'telephone': phone,
      'token': "", // Will be updated when handling push notifications
    });

    // 2. Create the document in 'clients' collection linking to the user
    await _firestore.collection('clients').add({
      'etatCompte': 'ACTIVE',
      'idUtilisateur': userRef.id,
    });
  }

  /// Login a client using phone and password
  Future<Map<String, dynamic>?> loginClient({
    required String phone,
    required String password,
  }) async {
    final hashedPassword = HashService.hashPassword(password);
    
    final query = await _firestore
        .collection('utilisateurs')
        .where('telephone', isEqualTo: phone)
        .where('motDePasse', isEqualTo: hashedPassword)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;
      
      // Check if they are actually a client
      final clientQuery = await _firestore
          .collection('clients')
          .where('idUtilisateur', isEqualTo: data['id'])
          .limit(1)
          .get();
          
      if (clientQuery.docs.isNotEmpty) {
        return data;
      }
    }
    return null; // Login failed
  }

  // ─── Providers ─────────────────────────────────────────────
  
  /// Register a new provider in the 'providers' collection
  Future<void> registerProvider({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String category,
    required String description,
    required String zone,
    required String? cinFrontBase64,
    required String? cinBackBase64,
    required String? certificateBase64,
  }) async {
    final hashedPassword = HashService.hashPassword(password);

    // 1. Create the document in 'utilisateurs' collection
    final userRef = await _firestore.collection('utilisateurs').add({
      'created_At': FieldValue.serverTimestamp(),
      'updated_At': FieldValue.serverTimestamp(),
      'email': email,
      'image_profile': null,
      'location': null,
      'motDePasse': hashedPassword,
      'nom': name,
      'telephone': phone,
      'token': "", // Will be updated when handling push notifications
    });

    // 2. Create the document in 'experts' collection linking to the user
    await _firestore.collection('experts').add({
      'CarteNationale': cinFrontBase64 ?? '', // Recto
      'CarteNationaleVerso': cinBackBase64 ?? '', // Verso (ajouté pour ne pas le perdre)
      'CasierJudiciaire': certificateBase64 != null && certificateBase64.isNotEmpty,
      'CertificatDocs': certificateBase64 ?? '',
      'Experience': description,
      'etatCompte': 'PENDING', // PENDING en attente de validation admin
      'idUtilisateur': userRef.id,
      'rayonTravaille': int.tryParse(zone) ?? 30, // Si la zone est un code postal ou texte, on met un rayon par défaut
      'zoneTexte': zone, // On garde la zone d'origine au cas où
      'categorie': category,
      'views': 0,
    });
  }

  /// Login a provider using phone and password
  Future<Map<String, dynamic>?> loginProvider({
    required String phone,
    required String password,
  }) async {
    final hashedPassword = HashService.hashPassword(password);
    
    final query = await _firestore
        .collection('utilisateurs')
        .where('telephone', isEqualTo: phone)
        .where('motDePasse', isEqualTo: hashedPassword)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;
      
      // Check if they are actually an expert
      final expertQuery = await _firestore
          .collection('experts')
          .where('idUtilisateur', isEqualTo: data['id'])
          .limit(1)
          .get();
          
      if (expertQuery.docs.isNotEmpty) {
        return data;
      }
    }
    return null; // Login failed
  }

  // ─── Admins ────────────────────────────────────────────────

  /// Login an admin using email and password
  Future<Map<String, dynamic>?> loginAdmin({
    required String email,
    required String password,
  }) async {
    final hashedPassword = HashService.hashPassword(password);
    
    // 1. Find user in utilisateurs by email + motDePasse
    final query = await _firestore
        .collection('utilisateurs')
        .where('email', isEqualTo: email)
        .where('motDePasse', isEqualTo: hashedPassword)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;
      
      // 2. Verify they are actually an admin
      final adminQuery = await _firestore
          .collection('admins')
          .where('idUtilisateur', isEqualTo: data['id'])
          .limit(1)
          .get();
          
      if (adminQuery.docs.isNotEmpty) {
        return data;
      }
    }
    return null; // Login failed
  }
}
