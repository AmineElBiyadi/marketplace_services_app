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
import 'location_service.dart';
import 'notification_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  FirebaseFirestore getFirestoreInstance() => _firestore;

  // ─── Expert Profile ────────────────────────────────────────

  Future<void> recordProfileView(String expertId) async {
    final now = DateTime.now();
    final monthKey = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    final dayKey = now.day.toString();
    final docId = "${expertId}_$monthKey";

    try {
      final docRef = _firestore.collection('profileViews').doc(docId);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        await docRef.set({
          'idExpert': expertId,
          'month': monthKey,
          'count': 1,
          'dailyCounts': {dayKey: 1},
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({
          'count': FieldValue.increment(1),
          'dailyCounts.$dayKey': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update total views on expert document
      await _firestore.collection('experts').doc(expertId).update({
        'profileViews': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint("Error recording profile view: $e");
    }
  }

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

  Future<Map<String, dynamic>?> getAddressForUser(String userId) async {
    try {
      final snap = await _firestore.collection('adresses')
          .where('idUtilisateur', isEqualTo: userId)
          .limit(1).get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─── Interventions / Bookings ──────────────────────────────

  Stream<List<InterventionModel>> getPendingInterventions(String expertId) {
    return _firestore
        .collection('interventions')
        .where('idExpert', isEqualTo: expertId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => InterventionModel.fromFirestore(doc)).where((interv) => interv.statut == 'EN_ATTENTE').toList();
          list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          return list;
        });
  }

  Stream<List<InterventionModel>> getUpcomingInterventions(String expertId) {
    final now = DateTime.now();
    return _firestore
        .collection('interventions')
        .where('idExpert', isEqualTo: expertId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => InterventionModel.fromFirestore(doc))
              .where((interv) => interv.statut == 'ACCEPTEE' && 
                                interv.dateDebutIntervention != null && 
                                interv.dateDebutIntervention!.isAfter(now))
              .toList();
        });
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

      final evaluations = await _firestore
          .collection('evaluations')
          .where('idExpert', isEqualTo: expertId)
          .get();

      final today = DateTime.now();
      int reservationsToday = 0;
      double totalRating = 0;
      int ratedCount = 0;
      double revenue = 0;

      for (var doc in interventions.docs) {
        final data = doc.data();
        final dateDebut = (data['dateDebutIntervention'] as dynamic)?.toDate();
        final dateFin = (data['dateFinIntervention'] as dynamic)?.toDate();
        
        if (dateDebut != null && dateDebut.year == today.year && dateDebut.month == today.month && dateDebut.day == today.day) {
          reservationsToday++;
        }
        
        if (dateFin != null && dateFin.year == today.year && dateFin.month == today.month) {
          if (data['statut'] == 'TERMINEE') {
            final price = data['prixNegocie'] ?? data['prix'];
            if (price != null) {
              revenue += (price as num).toDouble();
            }
          }
        }
      }

      for (var doc in evaluations.docs) {
        final data = doc.data();
        if (data['note'] != null) {
          totalRating += (data['note'] as num).toDouble();
          ratedCount++;
        }
      }

      final expertDoc = await _firestore.collection('experts').doc(expertId).get();
      final views = expertDoc.data()?['profileViews'] ?? 0;

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

  /// Returns true if expert has ACTIVE or GRACE subscription (both grant access).
  Stream<bool> isExpertPremium(String expertId) async* {
    final qRaw = await _firestore
        .collection('abonnements')
        .where('idExpert', isEqualTo: expertId)
        .get();
        
    final docs = qRaw.docs.where((doc) {
      final statut = doc.data()['statut'];
      return statut == 'ACTIVE' || statut == 'GRACE';
    }).toList();
    
    yield docs.isNotEmpty;
  }

  /// Returns the full active/grace subscription document, or null if not premium.
  Stream<Map<String, dynamic>?> getActiveSubscription(String expertId) {
    return _firestore
        .collection('abonnements')
        .where('idExpert', isEqualTo: expertId)
        .where('statut', whereIn: ['ACTIVE', 'GRACE'])
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return {'id': doc.id, ...doc.data()};
        });
  }

  /// Checks whether this expert already has a stored card in cartesBancaires.
  Future<bool> hasStoredCard(String expertId) async {
    try {
      final snap = await _firestore
          .collection('cartesBancaires')
          .where('idExpert', isEqualTo: expertId)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getExpertPortfolioImagesWithDetails(String expertId) async {
    try {
      final List<Map<String, dynamic>> images = [];

      final directExpSnap = await _firestore
          .collection('imagesExemplaires')
          .where('idExpert', isEqualTo: expertId)
          .get();
      
      for (final doc in directExpSnap.docs) {
        final data = doc.data();
        final img = (data['image'] ?? data['URLimage']) as String?;
        if (img != null && img.isNotEmpty) {
          String serviceName = 'Autre';
          String taskName = '';
          
          final serviceExpertId = data['idServiceExpert'] as String?;
          if (serviceExpertId != null && serviceExpertId.isNotEmpty) {
            final seDoc = await _firestore.collection('serviceExperts').doc(serviceExpertId).get();
            if (seDoc.exists) {
              final serviceId = seDoc.data()?['idService'] as String?;
              if (serviceId != null) {
                final sDoc = await _firestore.collection('services').doc(serviceId).get();
                serviceName = sDoc.data()?['nom'] ?? 'Service Inconnu';
              }
            }
          }

          final taskId = data['idTacheExpert'] as String?;
          if (taskId != null && taskId.isNotEmpty) {
            final tDoc = await _firestore.collection('tacheExperts').doc(taskId).get();
            taskName = tDoc.data()?['nom'] ?? '';
          }

          images.add({
            'id': doc.id,
            'image': img,
            'idServiceExpert': serviceExpertId ?? '',
            'serviceName': serviceName,
            'taskName': taskName,
            'isVisibleByPlan': data['isVisibleByPlan'] ?? true,
          });
        }
      }
      return images;
    } catch (e) {
      debugPrint('Error fetching expert portfolio images with details: $e');
      return [];
    }
  }

  /// Reactivates a SUSPENDU subscription by setting its statut back to ACTIVE.
  Future<void> reactivateSubscription(String subscriptionId, String expertId) async {
    final batch = _firestore.batch();
    
    final subRef = _firestore.collection('abonnements').doc(subscriptionId);
    batch.update(subRef, {
      'statut': 'ACTIVE',
      'suspendedAt': null,
      'graceStartedAt': null,
      'retryCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final seQ = await _firestore.collection('serviceExperts').where('idExpert', isEqualTo: expertId).get();
    for (var doc in seQ.docs) {
      batch.update(doc.reference, {'isVisibleByPlan': true});
    }

    final imgQ = await _firestore.collection('imagesExemplaires').where('idExpert', isEqualTo: expertId).get();
    for (var doc in imgQ.docs) {
      batch.update(doc.reference, {'isVisibleByPlan': true});
    }

    await batch.commit();
  }

  /// Cancels (expert-initiated) → sets statut to SUSPENDU. Data is preserved.
  Future<void> cancelSubscription(String subscriptionId) async {
    await _firestore.collection('abonnements').doc(subscriptionId).update({
      'statut': 'SUSPENDU',
      'suspendedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancels subscription and hides unselected services and photos
  Future<void> cancelSubscriptionAndSetVisibility(String subscriptionId, String expertId, List<String> keptServiceIds, {List<String>? keptImageIds}) async {
    final batch = _firestore.batch();
    
    final subRef = _firestore.collection('abonnements').doc(subscriptionId);
    batch.update(subRef, {
      'statut': 'SUSPENDU',
      'suspendedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 1. Set service visibility
    final seQ = await _firestore.collection('serviceExperts').where('idExpert', isEqualTo: expertId).get();
    for (var doc in seQ.docs) {
      bool keep = keptServiceIds.contains(doc.id);
      batch.update(doc.reference, {'isVisibleByPlan': keep});
    }

    // 2. Set image visibility
    final imgQ = await _firestore.collection('imagesExemplaires').where('idExpert', isEqualTo: expertId).get();
    if (keptImageIds != null) {
      for (var doc in imgQ.docs) {
        bool keep = keptImageIds.contains(doc.id);
        batch.update(doc.reference, {'isVisibleByPlan': keep});
      }
    } else {
      // Default: only allow it for first X photos belonging to visible services
      final dynamicLimit = await getFreePortfolioLimit();
      int visibleCount = 0;
      for (var doc in imgQ.docs) {
        final serviceId = doc.data()['idServiceExpert'];
        bool isServiceVisible = keptServiceIds.contains(serviceId);
        bool shouldBeVisible = isServiceVisible && visibleCount < dynamicLimit;
        if (shouldBeVisible) visibleCount++;
        batch.update(doc.reference, {'isVisibleByPlan': shouldBeVisible});
      }
    }

    await batch.commit();
  }

  /// Updates visibility for images based on provider's choice during downgrade
  Future<void> updateImagesPlanVisibility(String expertId, List<String> keptImageIds) async {
    final batch = _firestore.batch();
    
    // Fetch all images for this expert
    final imgQ = await _firestore.collection('imagesExemplaires').where('idExpert', isEqualTo: expertId).get();
    
    for (var doc in imgQ.docs) {
      bool keep = keptImageIds.contains(doc.id);
      batch.update(doc.reference, {'isVisibleByPlan': keep});
    }

    await batch.commit();
  }

  /// Automatically unlocks the next hidden photos for each service of an expert until the dynamic photo-per-service limit is reached.
  Future<void> autoUnlockNextPhotosGlobal(String expertId) async {
    final snap = await _firestore
        .collection('imagesExemplaires')
        .where('idExpert', isEqualTo: expertId)
        .get();

    final images = snap.docs;
    // Sort in Dart to avoid index requirement
    images.sort((a, b) {
      final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
      return aTime.compareTo(bTime);
    });
    
    // Group images by serviceExpertId
    final Map<String, List<DocumentSnapshot<Map<String, dynamic>>>> groupedImages = {};
    for (var doc in images) {
      final data = doc.data()!;
      final seId = (data['idServiceExpert'] ?? 'Other') as String;
      groupedImages.putIfAbsent(seId, () => []).add(doc);
    }

    final dynamicLimit = await getFreePortfolioLimit();

    // For each service, ensure at least X photos are visible (if available)
    for (var seId in groupedImages.keys) {
      final serviceImages = groupedImages[seId]!;
      int visibleCount = serviceImages.where((d) => (d.data()?['isVisibleByPlan'] ?? true) == true).length;

      if (visibleCount < dynamicLimit) {
        int needed = dynamicLimit - visibleCount;
        final hiddenImages = serviceImages.where((d) => (d.data()?['isVisibleByPlan'] ?? true) == false).toList();
        for (int i = 0; i < hiddenImages.length && i < needed; i++) {
          await hiddenImages[i].reference.update({'isVisibleByPlan': true});
        }
      }
    }
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
      
      if (email.endsWith('@proxy.marketplace.app')) {
        final phonePart = email.split('@')[0];
        debugPrint("[FirestoreService] Phone-based proxy detected: $phonePart");

        // Prepare variations: 212xxxx, +212xxxx, 0xxxx
        String localFormat = phonePart;
        if (phonePart.startsWith('212')) {
          localFormat = '0${phonePart.substring(3)}';
        }
        
        final variations = {phonePart, '+$phonePart', localFormat}.toList();

        userQuery = await _firestore
            .collection('utilisateurs')
            .where('telephone', whereIn: variations)
            .limit(1)
            .get();
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
    final batch = _firestore.batch();
    
    // 1. Create premium subscription
    final subRef = _firestore.collection('abonnements').doc();
    batch.set(subRef, {
      'idExpert': expertId,
      'statut': 'ACTIVE',
      'dateDebut': FieldValue.serverTimestamp(),
      'type': 'PREMIUM',
      'montant': 99,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Make all services visible
    final seQ = await _firestore.collection('serviceExperts').where('idExpert', isEqualTo: expertId).get();
    for (var doc in seQ.docs) {
      batch.update(doc.reference, {'isVisibleByPlan': true});
    }

    await batch.commit();
  }

  Future<void> saveCardInfo({
    required String expertId,
    required String cardNumber,
    required String expiryDate,
    required String cvv,
  }) async {
    // 1. Delete old cards
    final oldCards = await _firestore
        .collection('cartesBancaires')
        .where('idExpert', isEqualTo: expertId)
        .get();
        
    final batch = _firestore.batch();
    for (var doc in oldCards.docs) {
      batch.delete(doc.reference);
    }

    // 2. Format new card
    final last4 = cardNumber.replaceAll(' ', '').length >= 4
        ? cardNumber.replaceAll(' ', '').substring(cardNumber.replaceAll(' ', '').length - 4)
        : '????';
    final maskedNumber = '**** **** **** $last4';

    // 3. Add new card
    final newDoc = _firestore.collection('cartesBancaires').doc();
    batch.set(newDoc, {
      'idExpert': expertId,
      'CardNumber': maskedNumber,
      'CVV': '***',
      'ExpirationDate': expiryDate,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }

  /// Retrieves the masked card information for the expert (if any).
  Future<Map<String, dynamic>?> getStoredCard(String expertId) async {
    try {
      final snap = await _firestore
          .collection('cartesBancaires')
          .where('idExpert', isEqualTo: expertId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (e) {
      return null;
    }
  }

  /// Returns list of subscription payment records derived from the active subscription.
  /// Generates one entry per month elapsed since subscription start.
  Future<List<Map<String, dynamic>>> getPaymentHistory(String expertId) async {
    try {
      final snapRaw = await _firestore
          .collection('abonnements')
          .where('idExpert', isEqualTo: expertId)
          .get();

      if (snapRaw.docs.isEmpty) return [];

      // Sort in Dart
      final docs = snapRaw.docs.toList();
      docs.sort((a, b) {
        final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        return bTime.compareTo(aTime); // descending
      });

      final data = docs.first.data();
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
  /// Fetch client snapshot data from Firestore using the clientId from an intervention.
  Future<Map<String, dynamic>?> getClientSnapshot(String clientId) async {
    try {
      // 1. Check if clientId is a direct Auth UID (standardized way)
      final directUserDoc = await _firestore.collection('utilisateurs').doc(clientId).get();
      if (directUserDoc.exists) {
        return directUserDoc.data();
      }

      // 2. Fallback: Check if clientId belongs to the 'clients' collection (old way)
      final clientDoc = await _firestore.collection('clients').doc(clientId).get();
      if (clientDoc.exists) {
        final idUtilisateur = clientDoc.data()?['idUtilisateur'];
        if (idUtilisateur != null) {
          final userDoc = await _firestore.collection('utilisateurs').doc(idUtilisateur).get();
          return userDoc.data();
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching client snapshot: $e");
      return null;
    }
  }

  // ─── Availability toggle ───────────────────────────────────

  Future<void> updateExpertAvailability(String expertId, bool isOnline) async {
    await _firestore.collection('experts').doc(expertId).update({
      'estDisponible': isOnline,
    });
  }

  Future<void> updateExpertProfileInfo(String expertId, String userId, {
    required String prenom,
    required String nom,
    required String telephone,
    required String email,
    required String ville,
    required String pays,
    required String numBatiment,
    required String rue,
    required String quartier,
    required String codePostal,
    GeoPoint? location,
    required double rayonTravaille,
    required String experience,
  }) async {
    final batch = _firestore.batch();
    
    // 1. Update user
    final fullName = '$prenom $nom'.trim();
    final userRef = _firestore.collection('utilisateurs').doc(userId);
    
    final Map<String, dynamic> userUpdates = {
      'nom': fullName,
      'telephone': telephone,
      'email': email,
      'updated_At': FieldValue.serverTimestamp(),
    };
    if (location != null) {
      userUpdates['location'] = location;
    }
    batch.update(userRef, userUpdates);

    // 2. Update address
    final adressesSnap = await _firestore.collection('adresses').where('idUtilisateur', isEqualTo: userId).limit(1).get();
    
    final Map<String, dynamic> addrData = {
      'Ville': ville,
      'Pays': pays,
      'NumBatiment': numBatiment,
      'Rue': rue,
      'Quartier': quartier,
      'CodePostal': codePostal,
    };
    if (location != null) {
      addrData['location'] = location;
    }

    if (adressesSnap.docs.isNotEmpty) {
      final addrRef = _firestore.collection('adresses').doc(adressesSnap.docs.first.id);
      batch.update(addrRef, addrData);
    } else {
      final addrRef = _firestore.collection('adresses').doc();
      addrData['idUtilisateur'] = userId;
      addrData['createdAt'] = FieldValue.serverTimestamp();
      batch.set(addrRef, addrData);
    }

    // 3. Update expert
    final expertRef = _firestore.collection('experts').doc(expertId);
    batch.update(expertRef, {
      'rayonTravaille': rayonTravaille.toInt(),
      'Experience': experience,
    });

    await batch.commit();
  }

  // ─── Search Experts ────────────────────────────────────────

    Future<List<ServiceModel>> getServices() async {
    try {
      // Fetch all, then filter in Dart so legacy docs without 'estActive' field are treated as active
      final snapshot = await _firestore
          .collection('services')
          .orderBy('nom')
          .get();
      return snapshot.docs
          .map((doc) => ServiceModel.fromFirestore(doc))
          .where((s) => s.estActive)
          .toList();
    } catch (e) {
      debugPrint("Error fetching services: $e");
      return [];
    }
  }

  Future<int> getFreeServiceLimit() async {
    try {
      final doc = await _firestore.collection('settings').doc('global_config').get();
      if (doc.exists) {
        return doc.data()?['free_service_limit'] ?? 3;
      }
      return 3;
    } catch (e) {
      debugPrint("Error fetching free service limit: $e");
      return 3;
    }
  }

  Future<int> getFreePortfolioLimit() async {
    try {
      final doc = await _firestore.collection('settings').doc('global_config').get();
      if (doc.exists) {
        return doc.data()?['free_portfolio_limit'] ?? 3;
      }
      return 3;
    } catch (e) {
      debugPrint("Error fetching free portfolio limit: $e");
      return 3;
    }
  }

  Future<Map<String, dynamic>?> getLatestExpertCGU() async {
    try {
      final snap = await _firestore.collection('cgu')
          .where('type', isEqualTo: 'EXPERT')
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error fetching CGU: $e');
      return null;
    }
  }


  Future<List<Expert>> getExperts({bool onlyAvailable = false}) async {
    try {
      final expertsSnapshot = await _firestore.collection('experts')
          .where('etatCompte', isEqualTo: 'ACTIVE')
          .get();
      
      // Fetch all experts' data in parallel
      List<Expert> experts = await Future.wait(expertsSnapshot.docs.map((expertDoc) async {
        final expertData = expertDoc.data() as Map<String, dynamic>;
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
          final visibleServicesDocs = serviceExpertsSnapshot.docs.where((se) =>
              (se.data()['estActive'] ?? true) == true &&
              (isPremium || (se.data()['isVisibleByPlan'] ?? true) == true)
          ).toList();

          final serviceDocs = await Future.wait(visibleServicesDocs.map(
            (se) => _firestore.collection('services').doc(se.data()['idService']).get()
          ));
          for (var sDoc in serviceDocs) {
            if (sDoc.exists && (sDoc.data()?['estActive'] ?? true) == true) {
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
          estDisponible: expertData['estDisponible'] ?? expertData['estdisponible'] ?? true,
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

  /// Returns only experts that have a non-null GeoPoint location stored (or falls back to city geocoding).
  Future<List<Expert>> getExpertsWithLocation({bool onlyAvailable = false}) async {
    final all = await getExperts(onlyAvailable: onlyAvailable);
    final locationService = LocationService();
    
    List<Expert> result = [];
    for (var e in all) {
      if (e.location != null) {
        result.add(e);
      } else if (e.ville.isNotEmpty) {
        // Fallback to geocoding the expert's city
        final geopoint = await locationService.getCoordinatesFromCity(e.ville);
        if (geopoint != null) {
          result.add(e.copyWith(location: geopoint));
        }
      }
    }
    return result;
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
        final visibleServicesDocs = serviceExpertsSnapshot.docs.where((se) =>
            (se.data()['estActive'] ?? true) == true &&
            (isPremium || (se.data()['isVisibleByPlan'] ?? true) == true)
        ).toList();

        final serviceDocs = await Future.wait(visibleServicesDocs.map(
          (se) => _firestore.collection('services').doc(se.data()['idService']).get()
        ));
        for (var sDoc in serviceDocs) {
          if (sDoc.exists && (sDoc.data()?['estActive'] ?? true) == true) {
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
        estDisponible: expertData['estDisponible'] ?? expertData['estdisponible'] ?? true,
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
            // Standardized way: direct lookup
            final userDoc = await _firestore.collection('utilisateurs').doc(idClient).get();
            if (userDoc.exists) {
              clientNom = userDoc.data()?['nom'] ?? 'Client';
            } else {
              // Fallback: check clients collection
              final clientDoc = await _firestore.collection('clients').doc(idClient).get();
              final idU = clientDoc.data()?['idUtilisateur'];
              if (idU != null) {
                final userDoc2 = await _firestore.collection('utilisateurs').doc(idU).get();
                clientNom = userDoc2.data()?['nom'] ?? 'Client';
              }
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

  /// Fetches all reviews (evaluations) left BY a client with expert names resolved.
  Future<List<Map<String, dynamic>>> getClientReviews(String clientId, {String? authUid}) async {
    try {
      final List<String> clientIds = [clientId];
      if (authUid != null && authUid != clientId) {
        clientIds.add(authUid);
      }

      final snapshot = await _firestore
          .collection('evaluations')
          .where('idClient', whereIn: clientIds)
          .get();

      final results = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        String expertNom = 'Expert';
        String expertPhoto = '';
        String tacheNom = '';
        final idExpert = data['idExpert'] as String?;

        if (idExpert != null && idExpert.isNotEmpty) {
          try {
            final expertDoc = await _firestore.collection('experts').doc(idExpert).get();
            final idUtilisateur = expertDoc.data()?['idUtilisateur'];
            if (idUtilisateur != null) {
              final userDoc = await _firestore.collection('utilisateurs').doc(idUtilisateur).get();
              expertNom = userDoc.data()?['nom'] ?? 'Expert';
              expertPhoto = userDoc.data()?['image_profile'] ?? '';
            }
          } catch (e) {
            debugPrint('Error resolving expert name for client review: $e');
          }
        }

        final idIntervention = data['idIntervention'] as String?;
        if (idIntervention != null && idIntervention.isNotEmpty) {
          try {
            final intDoc = await _firestore.collection('interventions').doc(idIntervention).get();
            tacheNom = intDoc.data()?['tacheSnapshot']?['nom'] ?? '';
          } catch (_) {}
        }

        return {
          'id': doc.id,
          'expertNom': expertNom,
          'expertPhoto': expertPhoto,
          'tacheNom': tacheNom,
          'note': (data['note'] ?? 0.0).toDouble(),
          'commentaire': data['commentaire'] ?? data['comment'] ?? '',
          'date': data['createdAt'],
          'idIntervention': idIntervention ?? '',
        };
      }).toList());

      results.sort((a, b) {
        final aDate = a['date'];
        final bDate = b['date'];
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return results;
    } catch (e) {
      debugPrint('Error fetching client reviews: $e');
      return [];
    }
  }

  /// Fetches all complaints (reclamations) made BY a client, with expert names resolved.
  Future<List<Map<String, dynamic>>> getClientComplaints(String clientId, {String? authUid}) async {
    try {
      final List<String> clientIds = [clientId];
      if (authUid != null && authUid != clientId) {
        clientIds.add(authUid);
      }

      final snapshot = await _firestore
          .collection('reclamations')
          .where('idClient', whereIn: clientIds)
          .get();

      final results = await Future.wait(snapshot.docs.map((doc) async {
        final data = doc.data();
        String expertNom = 'Expert';
        final idExpert = data['idExpert'] as String?;

        if (idExpert != null && idExpert.isNotEmpty) {
          try {
            final expertDoc = await _firestore.collection('experts').doc(idExpert).get();
            final idUtilisateur = expertDoc.data()?['idUtilisateur'];
            if (idUtilisateur != null) {
              final userDoc = await _firestore.collection('utilisateurs').doc(idUtilisateur).get();
              expertNom = userDoc.data()?['nom'] ?? 'Expert';
            }
          } catch (_) {}
        }

        return {
          'id': doc.id,
          'expertNom': expertNom,
          'description': data['description'] ?? '',
          'etat': data['etatReclamation'] ?? 'EN_ATTENTE',
          'adminResponse': data['adminResponse'] ?? '',
          'date': data['createdAt'],
          'idIntervention': data['idIntervention'] ?? '',
        };
      }).toList());

      results.sort((a, b) {
        final aDate = a['date'];
        final bDate = b['date'];
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return results;
    } catch (e) {
      debugPrint('Error fetching client complaints: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getExpertComplaints(String expertId) async {
    try {
      final snapshot = await _firestore
          .collection('reclamations')
          .where('idExpert', isEqualTo: expertId)
          .get();

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
          } catch (_) {}
        }

        return {
          'id': doc.id,
          'clientNom': clientNom,
          'description': data['description'] ?? '',
          'etat': data['etatReclamation'] ?? 'EN_ATTENTE',
          'date': data['createdAt'],
          'idIntervention': data['idIntervention'] ?? '',
          'adminResponse': data['adminResponse'] ?? '',
        };
      }).toList());

      results.sort((a, b) {
        final aDate = a['date'];
        final bDate = b['date'];
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });
      return results;
    } catch (e) {
      debugPrint('Error fetching expert complaints: $e');
      return [];
    }
  }


  /// Récupère toutes les images de portfolio d'un expert.
  Future<List<String>> getExpertPortfolioImages(String expertId) async {
    try {
      final List<String> images = [];

      // 1. Essayer via idExpert direct dans imagesExemplaires
      final directExpSnap = await _firestore
          .collection('imagesExemplaires')
          .where('idExpert', isEqualTo: expertId)
          .get();
      
      // Get expert premium status for filtering
      final isPremium = (await isExpertPremium(expertId).first);

      for (final doc in directExpSnap.docs) {
        final data = doc.data();
        final isVisible = data['isVisibleByPlan'] ?? true;
        if (!isPremium && !isVisible) continue;

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
            final isVisible = data['isVisibleByPlan'] ?? true;
            if (!isPremium && !isVisible) continue;

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
    required String acceptedCguVersion,
    // Optional address fields
    String? rue,
    String? numBatiment,
    String? quartier,
    String? ville,
    String? codePostal,
    String? pays,
    GeoPoint? location,
  }) async {
    final uid = _auth.currentUser!.uid;

    await _firestore.collection('utilisateurs').doc(uid).set({
      'created_At': FieldValue.serverTimestamp(),
      'updated_At': FieldValue.serverTimestamp(),
      'email': email,
      'image_profile': null,
      'location': location,   // GeoPoint or null
      'nom': name,
      'telephone': phone,
      'token': '',
      'acceptedCguVersion': acceptedCguVersion,
    });

    final clientDoc = await _firestore.collection('clients').add({
      'etatCompte': 'ACTIVE',
      'idUtilisateur': uid,
    });

    // Notify Admin of new registration
    await _notificationService.sendNotification(
      idUtilisateur: 'user_admin_001', 
      titre: "New Client",
      corps: "A new client ($name) has registered on the platform.",
      type: 'registration',
      relatedId: clientDoc.id,
    );

    // Save address document if address data was provided
    if (ville != null && ville.isNotEmpty) {
      await _firestore.collection('adresses').add({
        'idUtilisateur': uid,
        'Rue': rue ?? '',
        'NumBatiment': numBatiment ?? '',
        'Quartier': quartier ?? '',
        'Ville': ville,
        'CodePostal': codePostal ?? '',
        'Pays': pays ?? 'Maroc',
        if (location != null) 'location': location,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

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

  /// Updates the client's profile in Firestore using the current Firebase Auth UID.
  Future<bool> isPhoneAlreadyUsed(String phone, String excludeUid) async {
    final snapshot = await _firestore
        .collection('utilisateurs')
        .where('telephone', isEqualTo: phone)
        .where(FieldPath.documentId, isNotEqualTo: excludeUid)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<bool> isEmailAlreadyUsed(String email, String excludeUid) async {
    final snapshot = await _firestore
        .collection('utilisateurs')
        .where('email', isEqualTo: email)
        .where(FieldPath.documentId, isNotEqualTo: excludeUid)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<void> updateClientProfile({
    required String uid,
    required String name,
    required String phone,
    String? email,
    String? imageBase64,
  }) async {
    final updateData = <String, dynamic>{
      'nom': name,
      'telephone': phone,
      'updated_At': FieldValue.serverTimestamp(),
    };
    if (email != null) {
      updateData['email'] = email;
    }
    if (imageBase64 != null) {
      updateData['image_profile'] = imageBase64;
    }
    await _firestore.collection('utilisateurs').doc(uid).update(updateData);
  }

  // ─── Provider Services & Tasks ─────────────────────────────

  Future<List<ServiceModel>> getServiceCategories() async {
    try {
      // Fetch all, then filter in Dart so legacy docs without 'estActive' field are treated as active
      final snapshot = await _firestore.collection('services').get();
      return snapshot.docs
          .map((doc) => ServiceModel.fromFirestore(doc))
          .where((s) => s.estActive)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TaskModel>> getTasksForCategory(String serviceId, {String? expertId}) async {
    try {
      // Fetch ALL tasks for this service with a single where clause (no composite index needed)
      final allSnapshot = await _firestore
          .collection('taches')
          .where('idService', isEqualTo: serviceId)
          .get();

      // Filter in Dart: active standard tasks (idExpert == "" or null)
      final standardTasks = allSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final isActive = data['estActive'] ?? true;
            final docExpertId = data['idExpert'] ?? '';
            return isActive && docExpertId == '';
          })
          .map((doc) => TaskModel.fromFirestore(doc))
          .toList();

      // Filter in Dart: active expert-specific tasks
      final expertTasks = expertId != null
          ? allSnapshot.docs
              .where((doc) {
                final data = doc.data();
                final isActive = data['estActive'] ?? true;
                final docExpertId = data['idExpert'] ?? '';
                return isActive && docExpertId == expertId;
              })
              .map((doc) => TaskModel.fromFirestore(doc))
              .toList()
          : <TaskModel>[];

      return [...standardTasks, ...expertTasks];
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
        
        // Skip services that have been deactivated by admin
        if (serviceData != null && (serviceData['estActive'] ?? true) == false) continue;
        
        final serviceName = serviceData != null ? (serviceData['nom'] ?? 'Unknown Service') : 'Unknown Service';
        final serviceImage = serviceData != null ? serviceData['image'] : null;

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
        final tasksSnapshotRaw = await _firestore
            .collection('tacheExperts')
            .where('idExpert', isEqualTo: expertId)
            .get();
        
        final tasksDocs = tasksSnapshotRaw.docs.where((doc) => doc.data()['idService'] == serviceId).toList();
        
        List<Map<String, dynamic>> tasksData = [];
        for (var tDoc in tasksDocs) {
          final task = TaskExpertModel.fromFirestore(tDoc);
          final tid = tDoc.id;

          // Skip tasks that have been deactivated (cascade from catalog task deactivation)
          if ((tDoc.data()['estActive'] ?? true) == false) continue;

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
          'serviceImage': serviceImage,
          'description': seData['description'] ?? '',
          'estActive': seData['estActive'] ?? true,
          'isVisibleByPlan': seData['isVisibleByPlan'] ?? true,
          'anneeExperience': seData['anneeExperience'] ?? 0,
          'images': imgSnapshot.docs.map((d) => {
            'image': (d.data()['image'] ?? d.data()['URLimage']) as String?,
            'isVisibleByPlan': d.data()['isVisibleByPlan'] ?? true,
            'id': d.id,
          }).toList(),
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
          'isVisibleByPlan': data['isVisibleByPlan'] ?? true,
          'publicId': data['publicId'] ?? '',
          'storageType': data['storageType'] ?? 'base64',
          'docId': doc.id,
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
    required List<Map<String, dynamic>> imagesWithTasks,
  }) async {
    final batch = _firestore.batch();

    // 1. Add to serviceExperts
    final seRef = _firestore.collection('serviceExperts').doc();
    batch.set(seRef, {
      'idExpert': expertId,
      'idService': serviceId,
      'description': description,
      'estActive': true,
      'isVisibleByPlan': true,
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
    for (var imageData in imagesWithTasks) {
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

      // Check if expert is premium to determine initial photo visibility
      final isPremium = (await isExpertPremium(expertId).first);
      final freePortfolioLimit = await getFreePortfolioLimit();

      batch.set(imgRef, {
        'image': imageData['image'],
        'idExpert': expertId,
        'idServiceExpert': seRef.id,
        'idTacheExpert': linkedId ?? '',
        'publicId': imageData['publicId'] ?? '',
        'storageType': imageData['storageType'] ?? 'base64',
        'isVisibleByPlan': isPremium || imagesWithTasks.indexOf(imageData) < freePortfolioLimit,
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
    // Only check for ongoing interventions when deactivating (status = false)
    if (!status) {
      // Get the serviceExpert document to retrieve expertId and serviceId
      final serviceDoc = await _firestore.collection('serviceExperts').doc(docId).get();
      if (!serviceDoc.exists) {
        throw Exception("Service non trouvé.");
      }
      
      final serviceData = serviceDoc.data() as Map<String, dynamic>;
      final expertId = serviceData['idExpert'] as String;
      final serviceId = serviceData['idService'] as String;
      
      // Check for ongoing interventions
      final hasOngoing = await hasOngoingInterventionsForService(expertId, serviceId);
      if (hasOngoing) {
        throw Exception("Ce service ne peut pas être désactivé car il a des interventions en cours ou en attente.");
      }
    }

    await _firestore.collection('serviceExperts').doc(docId).update({
      'estActive': status,
    });
  }

  Future<void> deleteExpertService(String expertId, String serviceId) async {
    // Check for ongoing interventions first
    final hasOngoing = await hasOngoingInterventionsForService(expertId, serviceId);
    if (hasOngoing) {
      throw Exception("Ce service ne peut pas être supprimé car il a des interventions en cours ou en attente.");
    }

    final batch = _firestore.batch();

    // Delete from serviceExperts
    final seQueryRaw = await _firestore
        .collection('serviceExperts')
        .where('idExpert', isEqualTo: expertId)
        .get();
    
    final seDocs = seQueryRaw.docs.where((doc) => doc.data()['idService'] == serviceId).toList();
    for (var doc in seDocs) batch.delete(doc.reference);

    // Delete task instances from 'tacheExperts'
    final tQueryRaw = await _firestore
        .collection('tacheExperts')
        .where('idExpert', isEqualTo: expertId)
        .get();
    
    final tDocs = tQueryRaw.docs.where((doc) => doc.data()['idService'] == serviceId).toList();
    
    for (var doc in tDocs) {
      // Delete images linked via legacy idTacheExpert
      final imgQuery = await _firestore
          .collection('imagesExemplaires')
          .where('idTacheExpert', isEqualTo: doc.id)
          .get();
      for (var imgDoc in imgQuery.docs) batch.delete(imgDoc.reference);
      
      batch.delete(doc.reference);
    }
    
    // Delete images linked via idServiceExpert
    if (seDocs.isNotEmpty) {
      final seImgQuery = await _firestore
          .collection('imagesExemplaires')
          .where('idServiceExpert', isEqualTo: seDocs.first.id)
          .get();
      for (var doc in seImgQuery.docs) batch.delete(doc.reference);
    }

    // Delete custom task definitions from 'taches'
    final customTQueryRaw = await _firestore
        .collection('taches')
        .where('idExpert', isEqualTo: expertId)
        .get();
    final customTDocs = customTQueryRaw.docs.where((doc) => doc.data()['idService'] == serviceId).toList();
    for (var doc in customTDocs) batch.delete(doc.reference);

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

    // Auto-unlock hidden services if free limit frees up
    final freeLimit = await getFreeServiceLimit();
    final allServicesQuery = await _firestore.collection('serviceExperts').where('idExpert', isEqualTo: expertId).get();
    final remainingServices = allServicesQuery.docs.where((doc) => doc.data()['idService'] != serviceId).toList();
    
    int visibleCount = remainingServices.where((doc) => (doc.data()['isVisibleByPlan'] ?? true) == true).length;
    if (visibleCount < freeLimit) {
      int needed = freeLimit - visibleCount;
      final hiddenServices = remainingServices.where((doc) => (doc.data()['isVisibleByPlan'] ?? true) == false).toList();
      
      // We can sort by createdAt to unlock the oldest hidden service first, or just take the first one
      for (int i = 0; i < hiddenServices.length && i < needed; i++) {
        batch.update(hiddenServices[i].reference, {'isVisibleByPlan': true});
      }
    }

    await batch.commit();

    // 4. Auto-unlock hidden photos globally
    await autoUnlockNextPhotosGlobal(expertId);
  }

  Future<bool> hasOngoingInterventionsForService(String expertId, String serviceId) async {
    try {
      // 1. Get all task IDs associated with this service for this expert
      final tasksQueryRaw = await _firestore.collection('tacheExperts')
          .where('idExpert', isEqualTo: expertId)
          .get();
      
      final tasksDocs = tasksQueryRaw.docs.where((doc) => doc.data()['idService'] == serviceId).toList();
      
      if (tasksDocs.isEmpty) return false;
      
      final taskIds = tasksDocs.map((doc) => doc.id).toList();

      // 2. Check interventions for any of these tasks that are not finished or cancelled
      // We filter by idExpert (which should be indexed) and then check statut/task in Dart
      final ongoingQueryRaw = await _firestore.collection('interventions')
          .where('idExpert', isEqualTo: expertId)
          .get();

      final hasOngoing = ongoingQueryRaw.docs.any((doc) {
        final data = doc.data();
        final statut = data['statut'];
        final taskId = data['idTacheExpert'];
        return taskIds.contains(taskId) && (statut == 'EN_ATTENTE' || statut == 'ACCEPTEE');
      });

      return hasOngoing;
    } catch (e) {
      debugPrint("Error checking ongoing interventions: $e");
      return false;
    }
  }


  Future<void> updateExpertService({
    required String expertId,
    required String serviceExpertDocId,
    required String serviceId,
    required String description,
    required List<TaskModel> selectedTasks,
    required List<String> customTasks,
    required List<Map<String, dynamic>> imagesWithTasks,
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
    final isPremium = (await isExpertPremium(expertId).first);
    final freePortfolioLimit = await getFreePortfolioLimit();
    
    for (var imageData in imagesWithTasks) {
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
        'idExpert': expertId,
        'idServiceExpert': serviceExpertDocId,
        'idTacheExpert': linkedId ?? '',
        'publicId': imageData['publicId'] ?? '',
        'storageType': imageData['storageType'] ?? 'base64',
        'isVisibleByPlan': isPremium || imagesWithTasks.indexOf(imageData) < freePortfolioLimit,
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

  /// Registers a new provider in Firestore using the current Firebase Auth UID.
  Future<void> registerProvider({
    required String name,
    required String phone,
    required String email,
    required List<String> serviceIds,
    required String description,
    required String zone,
    required String? cinFrontUrl,
    required String? cinBackUrl,
    required String? certificateUrl,
    required String acceptedCguVersion,

    // Optional address fields
    String? ville,
    String? pays,
    String? numBatiment,
    String? rue,
    String? quartier,
    String? codePostal,
    GeoPoint? location,
  }) async {
    final uid = _auth.currentUser!.uid;

    await _firestore.collection('utilisateurs').doc(uid).set({
      'created_At': FieldValue.serverTimestamp(),
      'updated_At': FieldValue.serverTimestamp(),
      'email': email,
      'image_profile': null,
      'location': location,
      'nom': name,
      'telephone': phone,
      'token': '',
      'acceptedCguVersion': acceptedCguVersion,
    });

    final expertRef = await _firestore.collection('experts').add({
      'CarteNationale': cinFrontUrl ?? '',
      'CarteNationaleVerso': cinBackUrl ?? '',
      'CasierJudiciaire': certificateUrl ?? '',
      'Experience': description,
      'etatCompte': 'PENDING',
      'idUtilisateur': uid,
      'rayonTravaille': int.tryParse(zone) ?? 30,
      'zoneTexte': zone,
      'estDisponible': false,
      'profileViews': 0,
    });

    // Notify Admin of new registration
    await _notificationService.sendNotification(
      idUtilisateur: 'user_admin_001',
      titre: "New Provider",
      corps: "A new provider ($name) has registered and is awaiting validation.",
      type: 'registration',
      relatedId: expertRef.id,
    );

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

    // Save address document if address data was provided
    if (ville != null && ville.isNotEmpty) {
      await _firestore.collection('adresses').add({
        'idUtilisateur': uid,
        'Rue': rue ?? '',
        'NumBatiment': numBatiment ?? '',
        'Quartier': quartier ?? '',
        'Ville': ville,
        'CodePostal': codePostal ?? '',
        'Pays': pays ?? 'Maroc',
        if (location != null) 'location': location,
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
    data['desactiveParAdmin'] = expertQuery.docs.first.data()['desactiveParAdmin'] ?? false;
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

  // ─── CGU (Terms & Conditions) ───────────────────────────────

  Future<Map<String, String>?> fetchActiveCGU(String type) async {
    try {
      final snapshot = await _firestore
          .collection('cgu')
          .where('type', isEqualTo: type)
          .where('is_active', isEqualTo: true)
          .limit(1)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        return {
          'content': data['content'] as String? ?? '',
          'version': data['version'] as String? ?? '1.0',
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error fetching CGU: $e');
      return null;
    }
  }

  Future<void> updateCguVersion(String uid, String newVersion) async {
    try {
      await _firestore.collection('utilisateurs').doc(uid).update({
        'acceptedCguVersion': newVersion,
      });
    } catch (e) {
      if (kDebugMode) print('Error updating CGU version: $e');
    }
  }

  Future<void> updateExpertRadius(String expertId, int radius) async {
    await _firestore.collection('experts').doc(expertId).update({
      'rayonTravaille': radius,
    });
  }

  Future<void> deactivateExpertSelf(String expertId) async {
    // 1. Check for active interventions
    final activeInterventionQuery = await _firestore.collection('interventions')
        .where('idExpert', isEqualTo: expertId)
        .where('statut', whereIn: ['EN_ATTENTE', 'ACCEPTEE', 'EN_COURS'])
        .limit(1)
        .get();

    if (activeInterventionQuery.docs.isNotEmpty) {
      throw Exception("Vous avez des interventions en cours ou en attente. Vous ne pouvez pas désactiver votre compte pour le moment.");
    }

    final doc = await _firestore.collection('experts').doc(expertId).get();
    if (!doc.exists) return;
    
    final data = doc.data() as Map<String, dynamic>?;
    final idUtilisateur = data?['idUtilisateur'];

    await _firestore.collection('experts').doc(expertId).update({
      'etatCompte': 'DESACTIVE',
      'desactiveParAdmin': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Automatically suspend premium plan if active
    final activeSubs = await _firestore
        .collection('abonnements')
        .where('idExpert', isEqualTo: expertId)
        .where('statut', whereIn: ['ACTIVE', 'GRACE'])
        .get();

    for (var subDoc in activeSubs.docs) {
      await cancelSubscription(subDoc.id);
    }

    if (idUtilisateur != null) {
      await _notificationService.sendNotification(
        idUtilisateur: idUtilisateur,
        titre: "Account Deactivated",
        corps: "You have deactivated your account. Your profile is no longer visible to clients.",
        type: 'account',
        relatedId: expertId,
      );
    }
  }

  Future<void> reactivateExpertSelf(String expertId) async {
    // Only reactivate if not disabled by admin
    final doc = await _firestore.collection('experts').doc(expertId).get();
    final data = doc.data() as Map<String, dynamic>?;
    if (doc.exists && (data?['desactiveParAdmin'] ?? false) == true) {
      throw Exception("Account deactivated by the administrator. Please contact support.");
    }

    await _firestore.collection('experts').doc(expertId).update({
      'etatCompte': 'ACTIVE',
      'desactiveParAdmin': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (data?['idUtilisateur'] != null) {
      await _notificationService.sendNotification(
        idUtilisateur: data!['idUtilisateur'],
        titre: "Account Reactivated",
        corps: "Welcome back! Your account is active and visible again.",
        type: 'account',
        relatedId: expertId,
      );
    }
  }
}