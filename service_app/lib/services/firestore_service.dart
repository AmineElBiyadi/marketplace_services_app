import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hash_service.dart';
import '../models/booking.dart';
import '../models/expert.dart';
import '../models/user.dart';
import '../models/service.dart';
import '../models/task_model.dart';
import '../models/task_expert_model.dart';


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

        final evaluationsSnapshot = await _firestore
            .collection('evaluations')
            .where('idExpert', isEqualTo: expertId)
            .get();

        double noteMoyenne = 0.0;
        if (evaluationsSnapshot.docs.isNotEmpty) {
          double totalNote = 0.0;
          for (final eDoc in evaluationsSnapshot.docs) {
            totalNote += (eDoc.data()['note'] ?? 0.0).toDouble();
          }
          noteMoyenne = totalNote / evaluationsSnapshot.docs.length;
        } else {
          // Fallback : check stored rating in expert/user document
          noteMoyenne = (expertData['noteMoyenne'] ??
                  expertData['note'] ??
                  expertData['rating'] ??
                  userData['note'] ??
                  0.0)
              .toDouble();
        }

        experts.add(Expert(
          id: expertId,
          nom: userData['nom'] ?? userData['email'] ?? 'Expert',
          photo: userData['image_profile'] ?? userData['photo'] ?? expertData['photo'] ?? '',
          telephone: userData['telephone'] ?? expertData['telephone'] ?? '',
          noteMoyenne: noteMoyenne,
          isPremium: isPremium,
          services: services,
          ville: ville,
          location: (expertData['location'] ?? userData['location']) as GeoPoint?,
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

  Future<String> registerClient({
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
    
    return userRef.id;
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
        // Sign in shadow Firebase Auth user for chat
        final authEmail = (data['email'] != null && data['email'].toString().isNotEmpty) 
            ? data['email'] 
            : '${phone.replaceAll('+', '')}@proxy.app.com';
            
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: authEmail,
            password: password,
          );
        } catch (e) {
          // If login fails (e.g., legacy user who doesn't have an Auth record yet), 
          // attempt to create the record seamlessly
          print(">>> Failed to sync Firebase Auth user: $e");
          try {
            // First attempt to signIn with the padded password in case it was created previously
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: authEmail,
              password: '${password}Proxy123!',
            );
          } catch (e) {
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: authEmail,
                password: password,
              );
            } on FirebaseAuthException catch (e) {
            if (e.code == 'weak-password') {
              // Firebase Auth requires at least 6 characters. If the user's custom password 
              // is shorter, we pad it just for the background Firebase Auth sign-in.
              try {
                final paddedPassword = '${password}Proxy123!';
                await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: authEmail,
                  password: paddedPassword,
                );
              } catch (_) {}
            } else {
              print(">>> Failed to CREATE Firebase Auth user during loginClient: $e");
            }
          } catch (e) {
            print(">>> Failed to CREATE Firebase Auth user during loginClient: $e");
          }
        }
      }
        
        return data;
      }
    }
    return null;
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
      debugPrint("Error getting expert: $e");
    }
    return null;
  }

  Future<Expert?> getExpertDetailed(String expertId) async {
    try {
      final doc = await _firestore.collection('experts').doc(expertId).get();
      if (!doc.exists) return null;
      
      final expertData = doc.data()!;
      final userId = expertData['idUtilisateur'];
      
      final userDoc = await _firestore.collection('utilisateurs').doc(userId).get();
      final userData = userDoc.data() ?? {};
      
      final evaluationsSnapshot = await _firestore
          .collection('evaluations')
          .where('idExpert', isEqualTo: expertId)
          .get();

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

      final adresseSnapshot = await _firestore
          .collection('adresses')
          .where('idUtilisateur', isEqualTo: userId)
          .get();

      String ville = '';
      if (adresseSnapshot.docs.isNotEmpty) {
        final adresse = adresseSnapshot.docs.first.data();
        ville = '${adresse['Ville'] ?? ''}, ${adresse['Quartier'] ?? ''}';
      }

      return Expert(
        id: expertId,
        nom: userData['nom'] ?? userData['email'] ?? 'Expert',
        photo: userData['image_profile'] ?? userData['photo'] ?? expertData['photo'] ?? '',
        telephone: userData['telephone'] ?? expertData['telephone'] ?? '',
        noteMoyenne: noteMoyenne,
        isPremium: isPremium,
        services: services,
        ville: ville,
        location: (expertData['location'] ?? userData['location']) as GeoPoint?,
      );
    } catch (e) {
      debugPrint("Error getting detailed expert: $e");
      return null;
    }
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
      'estDisponible': true,
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
        // Sign in shadow Firebase Auth user for chat
        final authEmail = (data['email'] != null && data['email'].toString().isNotEmpty) 
            ? data['email'] 
            : '${phone.replaceAll('+', '')}@proxy.app.com';
            
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: authEmail,
            password: password,
          );
        } catch (e) {
          print(">>> Failed to sync Firebase Auth user in loginProvider: $e");
          try {
            // First attempt to signIn with the padded password in case it was created previously
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: authEmail,
              password: '${password}Proxy123!',
            );
          } catch (e) {
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: authEmail,
                password: password,
              );
            } on FirebaseAuthException catch (e) {
               if (e.code == 'weak-password') {
                  try {
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                      email: authEmail,
                      password: '${password}Proxy123!',
                    );
                  } catch (_) {}
               } else {
                  print(">>> Failed to CREATE Firebase Auth user during loginProvider: $e");
               }
            } catch (e) {
              print(">>> Failed to CREATE Firebase Auth user during loginProvider: $e");
            }
          }
        }
        
        // Attach etatCompte so the UI can decide where to redirect
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

  // ─── Reviews (Avis) depuis evaluations ──────────────────

  /// Récupère les reviews réelles d'un expert depuis la collection [evaluations].
  Future<List<Map<String, dynamic>>> getExpertReviews(String expertId) async {
    try {
      final snapshot = await _firestore
          .collection('evaluations')
          .where('idExpert', isEqualTo: expertId)
          .orderBy('createdAt', descending: true)
          .get();

      final List<Map<String, dynamic>> reviews = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        // Récupérer le nom du client
        String clientNom = 'Client';
        final idClient = data['idClient'] as String?;
        if (idClient != null && idClient.isNotEmpty) {
          try {
            final clientDoc = await _firestore
                .collection('utilisateurs')
                .doc(idClient)
                .get();
            if (clientDoc.exists) {
              clientNom = clientDoc.data()?['nom'] ?? 'Client';
            }
          } catch (_) {}
        }

        reviews.add({
          'clientNom': clientNom,
          'note': (data['note'] ?? 0.0).toDouble(),
          'commentaire': data['commentaire'] ?? data['comment'] ?? '',
          'date': data['createdAt'],
        });
      }
      return reviews;
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
        final img = doc.data()['image'] as String?;
        if (img != null && img.isNotEmpty) images.add(img);
      }

      // 2. Toujours essayer via serviceExperts
      final seSnapshot = await _firestore
          .collection('serviceExperts')
          .where('idExpert', isEqualTo: expertId)
          .get();


      for (final seDoc in seSnapshot.docs) {
        // Essayer plusieurs noms de champs possibles pour la liaison
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
            final img = doc.data()['image'] as String?;
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
}