import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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