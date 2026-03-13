import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'hash_service.dart';
import '../models/booking.dart';
import '../models/expert.dart';
import '../models/user.dart';


class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

      final expertDoc =
          await _firestore.collection('experts').doc(expertId).get();
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
      'etatCompte': isOnline ? 'ACTIVE' : 'DESACTIVE',
    });
  }

  // ─── Search Experts ────────────────────────────────────────

  Future<List<Expert>> getExperts() async {
    try {
      final expertsSnapshot = await _firestore.collection('experts').get();
      List<Expert> experts = [];

      for (var expertDoc in expertsSnapshot.docs) {
        final expertData = expertDoc.data();
        final expertId = expertDoc.id;
        final userId = expertData['idUtilisateur'];

        final userDoc =
            await _firestore.collection('utilisateurs').doc(userId).get();
        final userData = userDoc.data() ?? {};

        final adresseSnapshot = await _firestore
            .collection('adresses')
            .where('idUtilisateur', isEqualTo: userId)
            .get();

        String ville = '';
        if (adresseSnapshot.docs.isNotEmpty) {
          final adresse = adresseSnapshot.docs.first.data();
          ville = '${adresse['Ville'] ?? ''}, ${adresse['Quartier'] ?? ''}';
        }

        final abonnementSnapshot = await _firestore
            .collection('abonnements')
            .where('idExpert', isEqualTo: expertId)
            .where('statut', isEqualTo: 'ACTIVE')
            .get();
        final isPremium = abonnementSnapshot.docs.isNotEmpty;

        final serviceExpertsSnapshot = await _firestore
            .collection('serviceExperts')
            .where('idExpert', isEqualTo: expertId)
            .get();

        List<String> services = [];
        for (var se in serviceExpertsSnapshot.docs) {
          final serviceDoc = await _firestore
              .collection('services')
              .doc(se.data()['idService'])
              .get();
          if (serviceDoc.exists) {
            services.add(serviceDoc.data()?['nom'] ?? '');
          }
        }

        final interventionsSnapshot = await _firestore
            .collection('interventions')
            .where('idExpert', isEqualTo: expertId)
            .get();

        double noteMoyenne = 0.0;
        if (interventionsSnapshot.docs.isNotEmpty) {
          final firstIntervention = interventionsSnapshot.docs.first.data();
          noteMoyenne =
              (firstIntervention['expertSnapshot']?['note_moyenne'] ?? 0.0)
                  .toDouble();
        }

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

      experts.sort((a, b) {
        if (a.isPremium && !b.isPremium) return -1;
        if (!a.isPremium && b.isPremium) return 1;
        return b.noteMoyenne.compareTo(a.noteMoyenne);
      });

      return experts;
    } catch (e) {
      return [];
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

  // ─── Utilisateurs (Shared) ─────────────────────────────────

  /// Checks if a user already exists with the given phone or email.
  /// Returns 'phone' or 'email' if duplicate found, null otherwise.
  Future<String?> checkUserExists({
    required String phone,
    required String email,
  }) async {
    if (phone.isNotEmpty) {
      final phoneQuery = await _firestore
          .collection('utilisateurs')
          .where('telephone', isEqualTo: phone)
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

  Future<void> registerClient({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final hashedPassword = HashService.hashPassword(password);
    
    // Create a shadow Firebase Auth user for chat functionality
    final authEmail = email.isNotEmpty ? email : '${phone.replaceAll('+', '')}@proxy.app.com';
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );
    } catch (e) {
      // Ignore if user already exists in Auth, or handle separately
    }

    final userRef = await _firestore.collection('utilisateurs').add({
      'created_At': FieldValue.serverTimestamp(),
      'updated_At': FieldValue.serverTimestamp(),
      'email': email,
      'image_profile': null,
      'location': null,
      'motDePasse': hashedPassword,
      'nom': name,
      'telephone': phone,
      'token': '',
    });

    await _firestore.collection('clients').add({
      'etatCompte': 'ACTIVE',
      'idUtilisateur': userRef.id,
    });
  }

  /// Returns user data map on success, null on failure.
  Future<Map<String, dynamic>?> loginClient({
    required String phone,
    required String password,
  }) async {
    final hashedPassword = HashService.hashPassword(password);
    final isEmail = phone.contains('@');

    final query = await _firestore
        .collection('utilisateurs')
        .where(isEmail ? 'email' : 'telephone', isEqualTo: phone)
        .where('motDePasse', isEqualTo: hashedPassword)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;

      final clientQuery = await _firestore
          .collection('clients')
          .where('idUtilisateur', isEqualTo: data['id'])
          .limit(1)
          .get();

      if (clientQuery.docs.isNotEmpty) {
        final authEmail = (data['email'] != null && data['email'].toString().isNotEmpty) 
            ? data['email'] 
            : '${phone.replaceAll('+', '')}@proxy.app.com';
            
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: authEmail,
            password: password,
          );
        } catch (_) {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: authEmail,
              password: '${password}Proxy123!',
            );
          } catch (_) {
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: authEmail,
                password: password,
              );
            } catch (_) {
              try {
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: authEmail,
                  password: '${password}Proxy123!',
                );
              } catch (_) {}
            }
          }
        }
        return data;
      }
    }
    return null;
  }

  // ─── Providers / Experts ───────────────────────────────────

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

    final userRef = await _firestore.collection('utilisateurs').add({
      'created_At': FieldValue.serverTimestamp(),
      'updated_At': FieldValue.serverTimestamp(),
      'email': email,
      'image_profile': null,
      'location': null,
      'motDePasse': hashedPassword,
      'nom': name,
      'telephone': phone,
      'token': '',
    });

    await _firestore.collection('experts').add({
      'CarteNationale': cinFrontBase64 ?? '',
      'CarteNationaleVerso': cinBackBase64 ?? '',
      'CasierJudiciaire':
          certificateBase64 != null && certificateBase64.isNotEmpty,
      'CertificatDocs': certificateBase64 ?? '',
      'Experience': description,
      'etatCompte': 'PENDING',
      'idUtilisateur': userRef.id,
      'rayonTravaille': int.tryParse(zone) ?? 30,
      'zoneTexte': zone,
      'categorie': category,
      'views': 0,
    });
  }

  /// Returns user data + 'etatCompte' from experts collection on success.
  /// etatCompte can be 'PENDING', 'ACTIVE', 'DESACTIVE'.
  Future<Map<String, dynamic>?> loginProvider({
    required String phone,
    required String password,
  }) async {
    final hashedPassword = HashService.hashPassword(password);
    final isEmail = phone.contains('@');

    final query = await _firestore
        .collection('utilisateurs')
        .where(isEmail ? 'email' : 'telephone', isEqualTo: phone)
        .where('motDePasse', isEqualTo: hashedPassword)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;

      final expertQuery = await _firestore
          .collection('experts')
          .where('idUtilisateur', isEqualTo: data['id'])
          .limit(1)
          .get();

      if (expertQuery.docs.isNotEmpty) {
        final authEmail = (data['email'] != null && data['email'].toString().isNotEmpty) 
            ? data['email'] 
            : '${phone.replaceAll('+', '')}@proxy.app.com';
            
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: authEmail,
            password: password,
          );
        } catch (_) {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: authEmail,
              password: '${password}Proxy123!',
            );
          } catch (_) {
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: authEmail,
                password: password,
              );
            } catch (_) {
              try {
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: authEmail,
                  password: '${password}Proxy123!',
                );
              } catch (_) {}
            }
          }
        }
        
        data['etatCompte'] = expertQuery.docs.first.data()['etatCompte'] ?? 'PENDING';
        data['expertId'] = expertQuery.docs.first.id;
        return data;
      }
    }
    return null;
  }

  // ─── Admins ────────────────────────────────────────────────

  Future<Map<String, dynamic>?> loginAdmin({
    required String email,
    required String password,
  }) async {
    final hashedPassword = HashService.hashPassword(password);

    final query = await _firestore
        .collection('utilisateurs')
        .where('email', isEqualTo: email)
        .where('motDePasse', isEqualTo: hashedPassword)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final data = query.docs.first.data();
      data['id'] = query.docs.first.id;

      final adminQuery = await _firestore
          .collection('admins')
          .where('idUtilisateur', isEqualTo: data['id'])
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        return data;
      }
    }
    return null;
  }
}