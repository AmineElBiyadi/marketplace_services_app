import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/booking.dart';
import '../models/expert.dart';
import '../models/user.dart';
import '../models/service.dart';
import '../models/task_model.dart';
import '../models/task_expert_model.dart';
import '../models/expert_service_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFirestore getFirestoreInstance() => _firestore;

  // ─── Expert Profile ────────────────────────────────────────

  Future<ExpertModel?> getExpertProfile(String expertId) async {
    try {
      DocumentSnapshot expertDoc =
          await _firestore.collection('experts').doc(expertId).get();
      if (!expertDoc.exists) return null;

      ExpertModel expert = ExpertModel.fromFirestore(expertDoc);

      DocumentSnapshot userDoc = await _firestore
          .collection('utilisateurs')
          .doc(expert.idUtilisateur)
          .get();
      if (userDoc.exists) {
        UserModel user = UserModel.fromFirestore(userDoc);
        return ExpertModel.fromFirestore(expertDoc, user: user);
      }

      return expert;
    } catch (e) {
      return null;
    }
  }

  // ─── Interventions / Bookings ──────────────────────────────

  Stream<List<InterventionModel>> getPendingInterventions(String expertId) {
    return _firestore
        .collection('interventions')
        .where('idExpert', isEqualTo: expertId)
        .where('statut', isEqualTo: 'EN_ATTENTE')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => InterventionModel.fromFirestore(doc)).toList());
  }

  Stream<List<InterventionModel>> getUpcomingInterventions(String expertId) {
    final now = DateTime.now();
    return _firestore
        .collection('interventions')
        .where('idExpert', isEqualTo: expertId)
        .where('statut', isEqualTo: 'ACCEPTEE')
        .where('dateDebutIntervention', isGreaterThan: now)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => InterventionModel.fromFirestore(doc)).toList());
  }

  Stream<List<InterventionModel>> getExpertInterventionsByMonth(String expertId, DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    return _firestore
        .collection('interventions')
        .where('idExpert', isEqualTo: expertId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => InterventionModel.fromFirestore(doc)).toList();
          
          // Filter by date range only — show ALL statuses so expert sees full agenda
          return list.where((interv) {
            final date = interv.dateDebutIntervention;
            if (date == null) return false;
            return !date.isBefore(firstDay) && !date.isAfter(lastDay);
          }).toList();
        });
  }

  Future<Map<String, dynamic>> getExpertKPIs(String expertId) async {
    try {
      final interventions = await _firestore
          .collection('interventions')
          .where('idExpert', isEqualTo: expertId)
          .get();

      final today = DateTime.now();
      int reservationsToday = 0;
      double totalRating = 0;
      int ratedCount = 0;
      double revenue = 0;

      for (var doc in interventions.docs) {
        final data = doc.data();
        final date = (data['dateDebutIntervention'] as dynamic)?.toDate();
        if (date != null &&
            date.year == today.year &&
            date.month == today.month &&
            date.day == today.day) {
          reservationsToday++;
        }
        if (data['note'] != null) {
          totalRating += (data['note'] as num).toDouble();
          ratedCount++;
        }
        if (data['statut'] == 'TERMINEE' && data['prix'] != null) {
          revenue += (data['prix'] as num).toDouble();
        }
      }

      final expertDoc = await _firestore.collection('experts').doc(expertId).get();
      final views = expertDoc.data()?['views'] ?? 0;

      return {
        'reservations_today': reservationsToday.toString(),
        'rating': ratedCount > 0
            ? (totalRating / ratedCount).toStringAsFixed(1)
            : '0.0',
        'revenue': '${revenue.toStringAsFixed(0)} DH',
        'views': views.toString(),
      };
    } catch (e) {
      return {
        'reservations_today': '0',
        'rating': '0.0',
        'revenue': '0 DH',
        'views': '0',
      };
    }
  }

  Future<List<Map<String, dynamic>>> getExpertPerformanceHistory(String expertId) async {
    try {
      final interventions = await _firestore
          .collection('interventions')
          .where('idExpert', isEqualTo: expertId)
          .get();

      final now = DateTime.now();
      // Initialize last 6 months with 0
      Map<String, int> monthlyCounts = {};
      for (int i = 5; i >= 0; i--) {
        final d = DateTime(now.year, now.month - i, 1);
        final key = "${d.year}-${d.month.toString().padLeft(2, '0')}";
        monthlyCounts[key] = 0;
      }

      for (var doc in interventions.docs) {
        final data = doc.data();
        final status = data['statut'] ?? 'EN_ATTENTE';
        if (status == 'ANNULEE' || status == 'REFUSEE') continue;

        final date = (data['dateDebutIntervention'] as dynamic)?.toDate();
        if (date != null) {
          final key = "${date.year}-${date.month.toString().padLeft(2, '0')}";
          if (monthlyCounts.containsKey(key)) {
            monthlyCounts[key] = monthlyCounts[key]! + 1;
          }
        }
      }

      // Convert to sorted list of maps
      final sortedKeys = monthlyCounts.keys.toList()..sort();
      return sortedKeys.map((k) => {
        'month': k,
        'count': monthlyCounts[k],
      }).toList();
    } catch (e) {
      debugPrint("Error fetching performance history: $e");
      return [];
    }
  }

  Stream<bool> isExpertPremium(String expertId) {
    return _firestore
        .collection('abonnements')
        .where('idExpert', isEqualTo: expertId)
        .where('statut', isEqualTo: 'ACTIVE')
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  /// Returns the full active subscription document, or null if not premium.
  Stream<Map<String, dynamic>?> getActiveSubscription(String expertId) {
    return _firestore
        .collection('abonnements')
        .where('idExpert', isEqualTo: expertId)
        .where('statut', isEqualTo: 'ACTIVE')
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return {'id': doc.id, ...doc.data()};
        });
  }

  Future<void> cancelSubscription(String subscriptionId) async {
    await _firestore.collection('abonnements').doc(subscriptionId).update({
      'statut': 'DESACTIVE',
      'dateFin': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> getExpertIdByUserId(String userId) async {
    try {
      final query = await _firestore
          .collection('experts')
          .where('idUtilisateur', isEqualTo: userId)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getExpertIdByEmail(String email) async {
    debugPrint("[FirestoreService] Resolving Expert ID for email: $email");
    try {
      QuerySnapshot userQuery;
      
      if (email.endsWith('@proxy.app.com')) {
        final phonePart = email.split('@')[0];
        debugPrint("[FirestoreService] Phone-based proxy detected: $phonePart");
        
        userQuery = await _firestore
            .collection('utilisateurs')
            .where('telephone', isEqualTo: phonePart)
            .limit(1)
            .get();
            
        if (userQuery.docs.isEmpty) {
          userQuery = await _firestore
              .collection('utilisateurs')
              .where('telephone', isEqualTo: '+$phonePart')
              .limit(1)
              .get();
        }
      } else {
        userQuery = await _firestore
            .collection('utilisateurs')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
      }

      if (userQuery.docs.isEmpty) {
        debugPrint("[FirestoreService] No user document found for $email");
        return null;
      }
      
      final userId = userQuery.docs.first.id;
      debugPrint("[FirestoreService] Found User ID: $userId");

      final expertQuery = await _firestore
          .collection('experts')
          .where('idUtilisateur', isEqualTo: userId)
          .limit(1)
          .get();
          
      if (expertQuery.docs.isNotEmpty) {
        final expertId = expertQuery.docs.first.id;
        debugPrint("[FirestoreService] Resolved Expert ID: $expertId");
        return expertId;
      }
      
      debugPrint("[FirestoreService] No expert document found for User ID: $userId");
      return null;
    } catch (e) {
      debugPrint("[FirestoreService] ERROR in getExpertIdByEmail: $e");
      return null;
    }
  }

  Future<String?> getExpertIdFromSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    if (user.email != null) return await getExpertIdByEmail(user.email!);
    
    // Fallback search by UID if email is null (though email should be present for providers)
    final q = await _firestore.collection('experts').where('idUtilisateur', isEqualTo: user.uid).limit(1).get();
    if (q.docs.isNotEmpty) return q.docs.first.id;
    
    return null;
  }

  Future<void> subscribeToPremium(String expertId) async {
    try {
      await _firestore.collection('abonnements').add({
        'idExpert': expertId,
        'statut': 'ACTIVE',
        'dateDebut': FieldValue.serverTimestamp(),
        'type': 'PREMIUM',
        'montant': 99,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveCardInfo({
    required String expertId,
    required String cardNumber,
    required String expiryDate,
    required String cvv,
  }) async {
    final last4 = cardNumber.replaceAll(' ', '').length >= 4
        ? cardNumber.replaceAll(' ', '').substring(cardNumber.replaceAll(' ', '').length - 4)
        : '????';
    final maskedNumber = '**** **** **** $last4';

    await _firestore.collection('cartesBancaires').add({
      'idExpert': expertId,
      'CardNumber': maskedNumber,
      'CVV': '***',
      'ExpirationDate': expiryDate,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns list of subscription payment records derived from the active subscription.
  /// Generates one entry per month elapsed since subscription start.
  Future<List<Map<String, dynamic>>> getPaymentHistory(String expertId) async {
    try {
      final snap = await _firestore
          .collection('abonnements')
          .where('idExpert', isEqualTo: expertId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return [];

      final data = snap.docs.first.data();
      final createdAtRaw = data['createdAt'];
      if (createdAtRaw == null) return [];

      final DateTime start = (createdAtRaw is Timestamp)
          ? createdAtRaw.toDate()
          : DateTime.now();
      final now = DateTime.now();

      int monthsElapsed = (now.year - start.year) * 12 + (now.month - start.month) + 1;
      if (monthsElapsed < 1) monthsElapsed = 1;
      if (monthsElapsed > 24) monthsElapsed = 24; // cap at 2 years display

      final List<Map<String, dynamic>> history = [];
      for (int i = 0; i < monthsElapsed; i++) {
        final d = DateTime(start.year, start.month + i, 1);
        history.insert(0, {
          'date': '1 ${_monthName(d.month)} ${d.year}',
          'amount': '99 DH',
          'status': d.isBefore(DateTime(now.year, now.month + 1)) ? 'Payé' : 'À venir',
        });
      }
      return history;
    } catch (e) {
      return [];
    }
  }

  static String _monthName(int m) {
    const months = ['Jan', 'Fév', 'Mars', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
    return months[(m - 1).clamp(0, 11)];
  }

  /// Fetch client snapshot data from Firestore using the clientId from an intervention.
  Future<Map<String, dynamic>?> getClientSnapshot(String clientId) async {
    try {
      // First get the client doc to find idUtilisateur
      final clientDoc = await _firestore.collection('clients').doc(clientId).get();
      if (!clientDoc.exists) return null;

      final idUtilisateur = clientDoc.data()?['idUtilisateur'];
      if (idUtilisateur == null) return null;

      // Fetch user data
      final userDoc = await _firestore.collection('utilisateurs').doc(idUtilisateur).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data()!;
      return {
        'nom': data['nom'] ?? 'Client',
        'telephone': data['telephone'] ?? '',
        'photo': data['image_profile'],
      };
    } catch (e) {
      return null;
    }
  }

  // ─── Availability toggle ───────────────────────────────────

  Future<void> updateExpertAvailability(String expertId, bool isOnline) async {
    await _firestore.collection('experts').doc(expertId).update({
      'estDisponible': isOnline,
    });
  }

  // ─── Search Experts ────────────────────────────────────────

  Future<List<Expert>> getExperts() async {
    try {
      final expertsSnapshot = await _firestore.collection('experts').get();
      
      // Fetch all experts' data in parallel
      List<Expert> experts = await Future.wait(expertsSnapshot.docs.map((expertDoc) async {
        final expertData = expertDoc.data();
        final expertId = expertDoc.id;
        final userId = expertData['idUtilisateur'];

        // Run independent queries in parallel for each expert
        final results = await Future.wait([
          _firestore.collection('utilisateurs').doc(userId).get(),
          _firestore.collection('adresses').where('idUtilisateur', isEqualTo: userId).get(),
          _firestore.collection('abonnements').where('idExpert', isEqualTo: expertId).where('statut', isEqualTo: 'ACTIVE').get(),
          _firestore.collection('serviceExperts').where('idExpert', isEqualTo: expertId).get(),
          _firestore.collection('evaluations').where('idExpert', isEqualTo: expertId).get(),
        ]);

        final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
        final adresseSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
        final abonnementSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
        final serviceExpertsSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
        final evaluationsSnapshot = results[4] as QuerySnapshot<Map<String, dynamic>>;

        final userData = userDoc.data() ?? {};

        // Resolve City from addresses
        String ville = '';
        if (adresseSnapshot.docs.isNotEmpty) {
          final adresse = adresseSnapshot.docs.first.data();
          ville = '${adresse['Ville'] ?? ''}, ${adresse['Quartier'] ?? ''}';
        }

        // Check Premium status
        final isPremium = abonnementSnapshot.docs.isNotEmpty;

        // Fetch service names in parallel
        List<String> services = [];
        if (serviceExpertsSnapshot.docs.isNotEmpty) {
          final serviceDocs = await Future.wait(serviceExpertsSnapshot.docs.map(
            (se) => _firestore.collection('services').doc(se.data()['idService']).get()
          ));
          for (var sDoc in serviceDocs) {
            if (sDoc.exists) {
              services.add(sDoc.data()?['nom'] ?? '');
            }
          }
        }

        // Calculate average rating from evaluations
        double noteMoyenne = 0.0;
        if (evaluationsSnapshot.docs.isNotEmpty) {
          double totalNote = 0.0;
          for (final eDoc in evaluationsSnapshot.docs) {
            totalNote += (eDoc.data()['note'] ?? 0.0).toDouble();
          }
          noteMoyenne = totalNote / evaluationsSnapshot.docs.length;
        } else {
          // Fallback to legacy fields
          noteMoyenne = (expertData['noteMoyenne'] ??
                  expertData['note'] ??
                  expertData['rating'] ??
                  userData['note'] ??
                  0.0)
              .toDouble();
        }

        String finalPhoto = (userData['image_profile'] ?? '').toString();

        return Expert(
          id: expertId,
          nom: userData['nom'] ?? userData['email'] ?? 'Expert',
          photo: finalPhoto,
          telephone: userData['telephone'] ?? expertData['telephone'] ?? '',
          noteMoyenne: noteMoyenne,
          isPremium: isPremium,
          services: services,
          ville: ville,
          location: (userData['location'] ?? expertData['location']) as GeoPoint?,
        );
      }));

      // Sort: Premium first, then by rating
      experts.sort((a, b) {
        if (a.isPremium && !b.isPremium) return -1;
        if (!a.isPremium && b.isPremium) return 1;
        return b.noteMoyenne.compareTo(a.noteMoyenne);
      });

      return experts;
    } catch (e) {
      debugPrint("Error fetching experts: $e");
      return [];
    }
  }

  Future<Expert?> getExpertDetailed(String expertId) async {
    try {
      final doc = await _firestore.collection('experts').doc(expertId).get();
      if (!doc.exists) return null;
      
      final expertData = doc.data()!;
      final userId = expertData['idUtilisateur'];
      
      // Fetch related data in parallel
      final results = await Future.wait([
        _firestore.collection('utilisateurs').doc(userId).get(),
        _firestore.collection('evaluations').where('idExpert', isEqualTo: expertId).get(),
        _firestore.collection('abonnements').where('idExpert', isEqualTo: expertId).where('statut', isEqualTo: 'ACTIVE').get(),
        _firestore.collection('serviceExperts').where('idExpert', isEqualTo: expertId).get(),
        _firestore.collection('adresses').where('idUtilisateur', isEqualTo: userId).get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final evaluationsSnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final abonnementSnapshot = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final serviceExpertsSnapshot = results[3] as QuerySnapshot<Map<String, dynamic>>;
      final adresseSnapshot = results[4] as QuerySnapshot<Map<String, dynamic>>;

      final userData = userDoc.data() ?? {};
      
      // Calculate average rating
      double noteMoyenne = 0.0;
      if (evaluationsSnapshot.docs.isNotEmpty) {
        double totalNote = 0.0;
        for (final eDoc in evaluationsSnapshot.docs) {
          totalNote += (eDoc.data()['note'] ?? 0.0).toDouble();
        }
        noteMoyenne = totalNote / evaluationsSnapshot.docs.length;
      } else {
        // Fallback
        noteMoyenne = (expertData['noteMoyenne'] ??
                expertData['note'] ??
                expertData['rating'] ??
                userData['note'] ??
                0.0)
            .toDouble();
      }

      final isPremium = abonnementSnapshot.docs.isNotEmpty;

      // Fetch service names in parallel
      List<String> services = [];
      if (serviceExpertsSnapshot.docs.isNotEmpty) {
        final serviceDocs = await Future.wait(serviceExpertsSnapshot.docs.map(
          (se) => _firestore.collection('services').doc(se.data()['idService']).get()
        ));
        for (var sDoc in serviceDocs) {
          if (sDoc.exists) {
            services.add(sDoc.data()?['nom'] ?? '');
          }
        }
      }

      // Resolve City
      String ville = '';
      if (adresseSnapshot.docs.isNotEmpty) {
        final adresse = adresseSnapshot.docs.first.data();
        ville = '${adresse['Ville'] ?? ''}, ${adresse['Quartier'] ?? ''}';
      }

      final finalPhoto = (userData['image_profile'] ?? '').toString();

      return Expert(
        id: expertId,
        nom: userData['nom'] ?? userData['email'] ?? 'Expert',
        photo: finalPhoto,
        telephone: userData['telephone'] ?? expertData['telephone'] ?? '',
        noteMoyenne: noteMoyenne,
        isPremium: isPremium,
        services: services,
        ville: ville,
        location: (userData['location'] ?? expertData['location']) as GeoPoint?,
      );
    } catch (e) {
      debugPrint("Error getting detailed expert: $e");
      return null;
    }
  }

  Future<List<String>> getVillesExperts() async {
    try {
      final expertsSnapshot = await _firestore.collection('experts').get();
      Set<String> villes = {};

      for (var expertDoc in expertsSnapshot.docs) {
        final userId = expertDoc.data()['idUtilisateur'];

        final adresseSnapshot = await _firestore
            .collection('adresses')
            .where('idUtilisateur', isEqualTo: userId)
            .get();

        if (adresseSnapshot.docs.isNotEmpty) {
          final adresse = adresseSnapshot.docs.first.data();
          final ville = '${adresse['Ville'] ?? ''}, ${adresse['Quartier'] ?? ''}';
          if (ville.trim() != ',') villes.add(ville);
        }
      }

      return villes.toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Reviews (Avis) depuis evaluations ──────────────────

  /// Récupère les reviews réelles d'un expert depuis la collection [evaluations].
  Future<List<Map<String, dynamic>>> getExpertReviews(String expertId) async {
    try {
      // NOTE: pas de orderBy('createdAt') ici pour éviter l'obligation
      // d'un index composite Firestore. On trie côté client après.
      final snapshot = await _firestore
          .collection('evaluations')
          .where('idExpert', isEqualTo: expertId)
          .get();

      // Parallelize client name resolution
      final results = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        String clientNom = 'Client';
        final idClient = data['idClient'] as String?;

        if (idClient != null && idClient.isNotEmpty) {
          try {
            final clientDoc = await _firestore.collection('clients').doc(idClient).get();
            final idUtilisateur = clientDoc.data()?['idUtilisateur'];
            
            if (idUtilisateur != null) {
              final userDoc = await _firestore.collection('utilisateurs').doc(idUtilisateur).get();
              clientNom = userDoc.data()?['nom'] ?? 'Client';
            }
          } catch (e) {
            debugPrint('Error resolving client name for review: $e');
          }
        }

        return {
          'clientNom': clientNom,
          'note': (data['note'] ?? 0.0).toDouble(),
          'commentaire': data['commentaire'] ?? data['comment'] ?? '',
          'date': data['createdAt'],
        };
      }).toList());

      debugPrint('✅ getExpertReviews: found ${results.length} reviews for expert $expertId');
      return results;
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      return [];
    }
  }

  // ─── Portfolio images depuis imagesExemplaires ─────────────

  /// Récupère toutes les images de portfolio d'un expert.
  Future<List<String>> getExpertPortfolioImages(String expertId) async {
    try {
      final List<String> images = [];

      // 1. Essayer via idExpert direct dans imagesExemplaires
      final directExpSnap = await _firestore
          .collection('imagesExemplaires')
          .where('idExpert', isEqualTo: expertId)
          .get();
      for (final doc in directExpSnap.docs) {
        final data = doc.data();
        final img = (data['image'] ?? data['URLimage']) as String?;
        if (img != null && img.isNotEmpty) images.add(img);
      }

      // 2. Toujours essayer via serviceExperts
      final seSnapshot = await _firestore
          .collection('serviceExperts')
          .where('idExpert', isEqualTo: expertId)
          .get();


      for (final seDoc in seSnapshot.docs) {
        final queries = [
          _firestore
              .collection('imagesExemplaires')
              .where('idServiceExpert', isEqualTo: seDoc.id)
              .get(),
          _firestore
              .collection('imagesExemplaires')
              .where('serviceExpertId', isEqualTo: seDoc.id)
              .get(),
        ];

        for (var q in queries) {
          final snap = await q;
          for (final doc in snap.docs) {
            final data = doc.data();
            final img = (data['image'] ?? data['URLimage']) as String?;
            if (img != null && img.isNotEmpty) images.add(img);
          }
        }
      }

      return images.toSet().toList(); // dédoublonnage
    } catch (e) {
      debugPrint('Error fetching portfolio images: $e');
      return [];
    }
  }

  // ─── Utilisateurs (Shared) ─────────────────────────────────

  /// Checks if a user already exists with the given phone or email.
  /// Returns 'phone' or 'email' if duplicate found, null otherwise.
  Future<String?> checkUserExists({
    required String phone,
    required String email,
  }) async {
    if (phone.isNotEmpty) {
      String localPhone = phone;
      String normalizedPhone = phone;
      if (phone.startsWith('+212')) {
        localPhone = '0${phone.substring(4)}';
      } else if (phone.startsWith('0')) {
        normalizedPhone = '+212${phone.substring(1)}';
      } else if (!phone.startsWith('+')) {
        normalizedPhone = '+212$phone';
        localPhone = '0$phone';
      }

      final phoneQuery = await _firestore
          .collection('utilisateurs')
          .where('telephone', whereIn: {phone, localPhone, normalizedPhone}.toList())
          .limit(1)
          .get();
      if (phoneQuery.docs.isNotEmpty) return 'phone';
    }

    if (email.isNotEmpty) {
      final emailQuery = await _firestore
          .collection('utilisateurs')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (emailQuery.docs.isNotEmpty) return 'email';
    }

    return null;
  }

  // ─── Clients ───────────────────────────────────────────────

  /// Registers a new client in Firestore using the current Firebase Auth UID.
  /// No password is stored — Firebase Auth handles that.
  Future<String> registerClient({
    required String name,
    required String phone,
    required String email,
  }) async {
    final uid = _auth.currentUser!.uid;

    await _firestore.collection('utilisateurs').doc(uid).set({
      'created_At': FieldValue.serverTimestamp(),
      'updated_At': FieldValue.serverTimestamp(),
      'email': email,
      'image_profile': null,
      'location': null,
      'nom': name,
      'telephone': phone,
      'token': '',
    });

    final clientDoc = await _firestore.collection('clients').add({
      'etatCompte': 'ACTIVE',
      'idUtilisateur': uid,
    });

    return clientDoc.id;
  }

  /// Fetches client data by Firebase Auth UID. Returns user data + role info, or null.
  Future<Map<String, dynamic>?> getClientByUid(String uid) async {
    final userDoc = await _firestore.collection('utilisateurs').doc(uid).get();
    if (!userDoc.exists) return null;

    final clientQuery = await _firestore
        .collection('clients')
        .where('idUtilisateur', isEqualTo: uid)
        .limit(1)
        .get();

    if (clientQuery.docs.isEmpty) return null;

    final data = userDoc.data()!;
    data['id'] = uid; // This remains the 'utilisateurs' UID for backwards compatibility
    data['clientId'] = clientQuery.docs.first.id; // Correct clients collection document ID
    return data;
  }

  // ─── Provider Services & Tasks ─────────────────────────────

  Future<List<ServiceModel>> getServiceCategories() async {
    try {
      final snapshot = await _firestore.collection('services').get();
      return snapshot.docs.map((doc) => ServiceModel.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TaskModel>> getTasksForCategory(String serviceId, {String? expertId}) async {
    try {
      // Fetch standard tasks (idExpert == "")
      final standardSnapshot = await _firestore
          .collection('taches')
          .where('idService', isEqualTo: serviceId)
          .where('idExpert', isEqualTo: "")
          .get();
      
      List<TaskModel> tasks = standardSnapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList();

      // Fetch expert's specific tasks if id is provided
      if (expertId != null) {
        final expertSnapshot = await _firestore
            .collection('taches')
            .where('idService', isEqualTo: serviceId)
            .where('idExpert', isEqualTo: expertId)
            .get();
        tasks.addAll(expertSnapshot.docs.map((doc) => TaskModel.fromFirestore(doc)));
      }

      return tasks;
    } catch (e) {
      print("Error fetching tasks for category: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExpertServicesDetailed(String expertId) async {
    try {
      final seSnapshot = await _firestore
          .collection('serviceExperts')
          .where('idExpert', isEqualTo: expertId)
          .get();

      List<Map<String, dynamic>> expertServices = [];

      for (var seDoc in seSnapshot.docs) {
        final seData = seDoc.data();
        final serviceId = seData['idService'];
        
        // Get service category details
        final serviceDoc = await _firestore.collection('services').doc(serviceId).get();
        final serviceData = serviceDoc.data();
        final serviceName = serviceData != null ? (serviceData['nom'] ?? 'Unknown Service') : 'Unknown Service';

        // Get images for the service expert
        final imgSnapshot = await _firestore
            .collection('imagesExemplaires')
            .where('idServiceExpert', isEqualTo: seDoc.id)
            .get();
        List<String> serviceImages = imgSnapshot.docs
            .map((d) => (d.data()['image'] ?? d.data()['URLimage']) as String?)
            .whereType<String>()
            .toList();

        // Get linked tasks for the expert instances
        final tasksSnapshot = await _firestore
            .collection('tacheExperts')
            .where('idExpert', isEqualTo: expertId)
            .where('idService', isEqualTo: serviceId)
            .get();
        
        List<Map<String, dynamic>> tasksData = [];
        for (var tDoc in tasksSnapshot.docs) {
          final task = TaskExpertModel.fromFirestore(tDoc);
          final tid = tDoc.id;

          // Fallback context: In older versions, images were saved per idTacheExpert
          if (serviceImages.isEmpty) {
            final oldImgSnapshot = await _firestore
                .collection('imagesExemplaires')
                .where('idTacheExpert', isEqualTo: tid)
                .get();
            serviceImages.addAll(oldImgSnapshot.docs
                .map((d) => (d.data()['image'] ?? d.data()['URLimage']) as String?)
                .whereType<String>());
          }

          tasksData.add({
            ...task.toMap(),
            'id': tid,
            'idTache': task.idTache,
          });
        }
        
        // Ensure no duplicate images from fallback
        serviceImages = serviceImages.toSet().toList();

        expertServices.add({
          'id': seDoc.id,
          'idService': serviceId,
          'serviceName': serviceName,
          'description': seData['description'] ?? '',
          'estActive': seData['estActive'] ?? true,
          'anneeExperience': seData['anneeExperience'] ?? 0,
          'images': serviceImages,
          'tasks': tasksData,
        });
      }
      return expertServices;
    } catch (e) {
      print("Error fetching expert services: $e");
      return [];
    }
  }

  /// Fetches images for a serviceExpert document, each labeled with its associated task name.
  Future<List<Map<String, dynamic>>> getImagesWithTasks(String serviceExpertId) async {
    try {
      final imgSnapshot = await _firestore
          .collection('imagesExemplaires')
          .where('idServiceExpert', isEqualTo: serviceExpertId)
          .get();

      final List<Map<String, dynamic>> result = [];

      for (var doc in imgSnapshot.docs) {
        final data = doc.data();
        final image = (data['image'] ?? data['URLimage'] ?? '') as String;
        final taskId = (data['idTacheExpert'] ?? '') as String;

        String taskName = '';
        String catalogId = '';
        if (taskId.isNotEmpty) {
          final taskDoc = await _firestore.collection('tacheExperts').doc(taskId).get();
          if (taskDoc.exists) {
            taskName = taskDoc.data()?['nom'] ?? '';
            catalogId = (taskDoc.data()?['idTache'] ?? '') as String;
          } else {
            // Fallback for legacy data where idTacheExpert might be a template ID
            final templateDoc = await _firestore.collection('taches').doc(taskId).get();
            if (templateDoc.exists) {
              taskName = templateDoc.data()?['nom'] ?? '';
              catalogId = taskId; // In this case, the ID stored was already the template ID
            }
          }
        }

        result.add({
          'image': image,
          'taskId': catalogId, // Use catalog ID for mapping in save operations
          'taskName': taskName,
          'instanceId': taskId, // Keep instance ID for reference if needed
        });
      }

      return result;
    } catch (e) {
      print('Error fetching images with tasks: $e');
      return [];
    }
  }

  Future<void> addExpertService({
    required String expertId,
    required String serviceId,
    required String description,
    required List<TaskModel> selectedTasks,
    required List<String> customTasks,
    required List<Map<String, String>> base64ImagesWithTasks,
  }) async {
    final batch = _firestore.batch();

    // 1. Add to serviceExperts
    final seRef = _firestore.collection('serviceExperts').doc();
    batch.set(seRef, {
      'idExpert': expertId,
      'idService': serviceId,
      'description': description,
      'estActive': true,
      'estCertifie': false,
      'anneeExperience': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Add instances of predefined tasks to 'tacheExperts'
    final Map<String, String> taskIdMap = {};
    for (var task in selectedTasks) {
      final taskExpertRef = _firestore.collection('tacheExperts').doc();
      batch.set(taskExpertRef, {
        'idExpert': expertId,
        'idService': serviceId,
        'idTache': task.id,
        'nom': task.nom,
        'description': description,
        'estActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      taskIdMap[task.id!] = taskExpertRef.id;
    }

    // 3. Add custom tasks to BOTH 'taches' (as definition) AND 'tacheExperts' (as instance)
    for (var taskName in customTasks) {
      final taskDefRef = _firestore.collection('taches').doc();
      batch.set(taskDefRef, {
        'idExpert': expertId,
        'idService': serviceId,
        'nom': taskName,
        'description': description,
        'estActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final taskExpertRef = _firestore.collection('tacheExperts').doc();
      batch.set(taskExpertRef, {
        'idExpert': expertId,
        'idService': serviceId,
        'idTache': taskDefRef.id,
        'nom': taskName,
        'description': description,
        'estActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      taskIdMap[taskName] = taskExpertRef.id;
    }

    // 4. Add all images linked to the service expert instance
    for (var imageData in base64ImagesWithTasks) {
      final imgRef = _firestore.collection('imagesExemplaires').doc();
      String? linkedId;
      if (imageData['taskId'] != null && imageData['taskId']!.isNotEmpty) {
        linkedId = taskIdMap[imageData['taskId']];
      } else {
        linkedId = taskIdMap[imageData['taskName']];
      }
      
      if (linkedId == null || linkedId.isEmpty) {
        print("[FirestoreService] Warning: Could not find taskId link for image associated with ${imageData['taskName'] ?? imageData['taskId']}. Check taskIdMap: $taskIdMap");
      }

      batch.set(imgRef, {
        'image': imageData['image'],
        'idServiceExpert': seRef.id,
        'idTacheExpert': linkedId ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Increment service count in utilisateurs
    final userQuery = await _firestore.collection('utilisateurs').where('idExpert', isEqualTo: expertId).limit(1).get();
    if(userQuery.docs.isEmpty) {
        // Find user by id directly if idExpert lookup failed
        final userDoc = await _firestore.collection('utilisateurs').doc(expertId).get();
        if(userDoc.exists) {
            batch.update(userDoc.reference, {
                'servicesCount': FieldValue.increment(1)
            });
        }
    } else {
        batch.update(userQuery.docs.first.reference, {
            'servicesCount': FieldValue.increment(1)
        });
    }


    await batch.commit();
  }

  Future<void> toggleServiceExpertsActive(String docId, bool status) async {
    await _firestore.collection('serviceExperts').doc(docId).update({
      'estActive': status,
    });
  }

  Future<void> deleteExpertService(String expertId, String serviceId) async {
    final batch = _firestore.batch();

    // Delete from serviceExperts
    final seQuery = await _firestore
        .collection('serviceExperts')
        .where('idExpert', isEqualTo: expertId)
        .where('idService', isEqualTo: serviceId)
        .get();
    for (var doc in seQuery.docs) batch.delete(doc.reference);

    // Delete task instances from 'tacheExperts'
    final tQuery = await _firestore
        .collection('tacheExperts')
        .where('idExpert', isEqualTo: expertId)
        .where('idService', isEqualTo: serviceId)
        .get();
    
    for (var doc in tQuery.docs) {
      // Delete images linked via legacy idTacheExpert
      final imgQuery = await _firestore
          .collection('imagesExemplaires')
          .where('idTacheExpert', isEqualTo: doc.id)
          .get();
      for (var imgDoc in imgQuery.docs) batch.delete(imgDoc.reference);
      
      batch.delete(doc.reference);
    }
    
    // Delete images linked via idServiceExpert
    final seList = seQuery.docs;
    if (seList.isNotEmpty) {
      final seImgQuery = await _firestore
          .collection('imagesExemplaires')
          .where('idServiceExpert', isEqualTo: seList.first.id)
          .get();
      for (var doc in seImgQuery.docs) batch.delete(doc.reference);
    }

    // Delete custom task definitions from 'taches'
    final customTQuery = await _firestore
        .collection('taches')
        .where('idExpert', isEqualTo: expertId)
        .where('idService', isEqualTo: serviceId)
        .get();
    for (var doc in customTQuery.docs) batch.delete(doc.reference);

    // Decrement service count in utilisateurs
    final userQuery = await _firestore.collection('utilisateurs').where('idExpert', isEqualTo: expertId).limit(1).get();
    if(userQuery.docs.isEmpty) {
        final userDoc = await _firestore.collection('utilisateurs').doc(expertId).get();
        if(userDoc.exists) {
            batch.update(userDoc.reference, {
                'servicesCount': FieldValue.increment(-1)
            });
        }
    } else {
        batch.update(userQuery.docs.first.reference, {
            'servicesCount': FieldValue.increment(-1)
        });
    }

    await batch.commit();
  }

  Future<void> updateExpertService({
    required String expertId,
    required String serviceExpertDocId,
    required String serviceId,
    required String description,
    required List<TaskModel> selectedTasks,
    required List<String> customTasks,
    required List<Map<String, String>> base64ImagesWithTasks,
    required List<String> existingImagesToDelete,
  }) async {
    final batch = _firestore.batch();
    
    // 0. Update serviceExpert description
    batch.update(_firestore.collection('serviceExperts').doc(serviceExpertDocId), {
      'description': description,
    });
    
    // 1. Delete tasks currently linked to this service
    final existingTasksQuery = await _firestore
        .collection('tacheExperts')
        .where('idExpert', isEqualTo: expertId)
        .where('idService', isEqualTo: serviceId)
        .get();
        
    for (var doc in existingTasksQuery.docs) {
        batch.delete(doc.reference);
        // Clear out legacy images
        final imgQuery = await _firestore
          .collection('imagesExemplaires')
          .where('idTacheExpert', isEqualTo: doc.id)
          .get();
        for (var imgDoc in imgQuery.docs) batch.delete(imgDoc.reference);
    }
    
    // Clear out service-level images
    final currentServiceImages = await _firestore
        .collection('imagesExemplaires')
        .where('idServiceExpert', isEqualTo: serviceExpertDocId)
        .get();
    for (var imgDoc in currentServiceImages.docs) batch.delete(imgDoc.reference);

    // 2. Add predefined tasks
    final Map<String, String> taskIdMap = {};
    for (var task in selectedTasks) {
      final taskExpertRef = _firestore.collection('tacheExperts').doc();
      batch.set(taskExpertRef, {
        'idExpert': expertId,
        'idService': serviceId,
        'idTache': task.id,
        'nom': task.nom,
        'description': description,
        'estActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      taskIdMap[task.id!] = taskExpertRef.id;
    }

    // 3. Add custom tasks
    for (var taskName in customTasks) {
      final taskDefRef = _firestore.collection('taches').doc();
      batch.set(taskDefRef, {
        'idExpert': expertId,
        'idService': serviceId,
        'nom': taskName,
        'description': description,
        'estActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final taskExpertRef = _firestore.collection('tacheExperts').doc();
      batch.set(taskExpertRef, {
        'idExpert': expertId,
        'idService': serviceId,
        'idTache': taskDefRef.id,
        'nom': taskName,
        'description': description,
        'estActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      taskIdMap[taskName] = taskExpertRef.id;
    }
    
    // 4. Add all images linked to the service expert instance
    for (var imageData in base64ImagesWithTasks) {
      final imgRef = _firestore.collection('imagesExemplaires').doc();
      String? linkedId;
      if (imageData['taskId'] != null && imageData['taskId']!.isNotEmpty) {
        linkedId = taskIdMap[imageData['taskId']];
      } else {
        linkedId = taskIdMap[imageData['taskName']];
      }
      
      if (linkedId == null || linkedId.isEmpty) {
        print("[FirestoreService] Warning: Could not find taskId link for image (update) associated with ${imageData['taskName'] ?? imageData['taskId']}. Check taskIdMap: $taskIdMap");
      }

      batch.set(imgRef, {
        'image': imageData['image'],
        'idServiceExpert': serviceExpertDocId,
        'idTacheExpert': linkedId ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<Map<String, dynamic>?> getExpertById(String expertId) async {
    try {
      final doc = await _firestore.collection('experts').doc(expertId).get();
      if (doc.exists) {
        return {...doc.data()!, 'id': doc.id};
      }
    } catch (e) {
      print("Error getting expert: $e");
    }
    return null;
  }

  // ─── Providers / Experts ───────────────────────────────────

  /// Returns a list of all services from the `services` collection.
  Future<List<Map<String, dynamic>>> getServices() async {
    final query = await _firestore.collection('services').get();
    return query.docs.map((doc) => {
      'id': doc.id,
      'nom': doc.data()['nom'] ?? '',
      'description': doc.data()['description'] ?? '',
    }).toList();
  }

  /// Registers a new provider in Firestore using the current Firebase Auth UID.
  Future<void> registerProvider({
    required String name,
    required String phone,
    required String email,
    required List<String> serviceIds,
    required String description,
    required String zone,
    required String? cinFrontBase64,
    required String? cinBackBase64,
    required String? certificateBase64,
  }) async {
    final uid = _auth.currentUser!.uid;

    await _firestore.collection('utilisateurs').doc(uid).set({
      'created_At': FieldValue.serverTimestamp(),
      'updated_At': FieldValue.serverTimestamp(),
      'email': email,
      'image_profile': null,
      'location': null,
      'nom': name,
      'telephone': phone,
      'token': '',
    });

    final expertRef = await _firestore.collection('experts').add({
      'CarteNationale': cinFrontBase64 ?? '',
      'CarteNationaleVerso': cinBackBase64 ?? '',
      'CasierJudiciaire':
          certificateBase64 != null && certificateBase64.isNotEmpty,
      'CertificatDocs': certificateBase64 ?? '',
      'Experience': description,
      'etatCompte': 'PENDING',
      'idUtilisateur': uid,
      'rayonTravaille': int.tryParse(zone) ?? 30,
      'zoneTexte': zone,
      'estDisponible': false,
      'profileViews': 0,
    });

    for (final serviceId in serviceIds.take(3)) {
      await _firestore.collection('serviceExperts').add({
        'idExpert': expertRef.id,
        'idService': serviceId,
        'anneeExperience': 0,
        'estActive': true,
        'estCertifie': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Fetches provider data by Firebase Auth UID.
  /// Returns user data + 'etatCompte' and 'expertId', or null if not a provider.
  Future<Map<String, dynamic>?> getProviderByUid(String uid) async {
    final userDoc = await _firestore.collection('utilisateurs').doc(uid).get();
    if (!userDoc.exists) return null;

    final expertQuery = await _firestore
        .collection('experts')
        .where('idUtilisateur', isEqualTo: uid)
        .limit(1)
        .get();

    if (expertQuery.docs.isEmpty) return null;

    final data = userDoc.data()!;
    data['id'] = uid;
    data['etatCompte'] = expertQuery.docs.first.data()['etatCompte'] ?? 'PENDING';
    data['expertId'] = expertQuery.docs.first.id;
    return data;
  }

  // ─── Admins ────────────────────────────────────────────────

  /// Fetches admin data by Firebase Auth UID.
  Future<Map<String, dynamic>?> getAdminByUid(String uid) async {
    final userDoc = await _firestore.collection('utilisateurs').doc(uid).get();
    if (!userDoc.exists) return null;

    final adminQuery = await _firestore
        .collection('admins')
        .where('idUtilisateur', isEqualTo: uid)
        .limit(1)
        .get();

    if (adminQuery.docs.isEmpty) return null;

    final data = userDoc.data()!;
    data['id'] = uid;
    return data;
  }
}