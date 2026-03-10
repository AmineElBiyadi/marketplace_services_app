import 'package:cloud_firestore/cloud_firestore.dart';
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
