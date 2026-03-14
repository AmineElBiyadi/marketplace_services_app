import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
        List<String> serviceImages = imgSnapshot.docs.map((d) => d.data()['image'] as String).toList();

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
            serviceImages.addAll(oldImgSnapshot.docs.map((d) => d.data()['image'] as String));
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

  Future<void> addExpertService({
    required String expertId,
    required String serviceId,
    required String description,
    required List<TaskModel> selectedTasks,
    required List<String> customTasks,
    required List<String> base64Images,
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
    }

    // 4. Add all images linked to the service expert instance
    for (var base64 in base64Images) {
      final imgRef = _firestore.collection('imagesExemplaires').doc();
      batch.set(imgRef, {
        'image': base64,
        'idServiceExpert': seRef.id,
        'idTacheExpert': '', // Fallback empty
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
    required List<String> base64Images,
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
    }
    
    // 4. Add all images linked to the service expert instance
    for (var base64 in base64Images) {
      final imgRef = _firestore.collection('imagesExemplaires').doc();
      batch.set(imgRef, {
        'image': base64,
        'idServiceExpert': serviceExpertDocId,
        'idTacheExpert': '', // Fallback empty
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