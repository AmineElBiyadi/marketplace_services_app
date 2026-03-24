import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import 'notification_service.dart';

/// Service that handles the full chat + intervention creation flow triggered
/// when a client contacts an expert (from the search list or expert profile).
class InterventionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // ─── Step 0: Check for existing open chat ──────────────────────────────────

  /// Returns a list of existing open [ChatModel]s between [clientId] and [expertId],
  /// or an empty list if none exists.
  Future<List<ChatModel>> checkOpenChat(String clientId, String expertId) async {
    try {
      final snap = await _db
          .collection('chats')
          .where('idClient', isEqualTo: clientId)
          .where('idExpert', isEqualTo: expertId)
          .where('estOuvert', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) return [];
      return snap.docs.map((doc) => ChatModel.fromDoc(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Step 1: Load expert's services ────────────────────────────────────────

  /// Returns the list of services offered by the given expert.
  /// Each entry: { 'id': serviceId, 'nom': 'Plomberie', 'description': '...' }
  Future<List<Map<String, dynamic>>> getExpertServices(String expertId) async {
    try {
      // 1. Get all serviceExperts entries for this expert
      final seSnap = await _db
      
          .collection('serviceExperts')
          .where('idExpert', isEqualTo: expertId)
          .get();

      if (seSnap.docs.isEmpty) return [];

      // 2. Fetch the service docs in parallel
      final serviceIds = seSnap.docs.map((d) => d.data()['idService'] as String).toList();
      final serviceDocs = await Future.wait(
        serviceIds.map((id) => _db.collection('services').doc(id).get()),
      );

      final List<Map<String, dynamic>> result = [];
      for (int i = 0; i < serviceDocs.length; i++) {
        final doc = serviceDocs[i];
        if (doc.exists) {
          result.add({
            'id': doc.id,
            'nom': doc.data()?['nom'] ?? '',
            'description': doc.data()?['description'] ?? '',
          });
        }
      }
      return result;
    } catch (e) {
      return [];
    }
  }

  // ─── Step 2: Load tasks for a specific service + expert ────────────────────

  /// Returns the tasks that this expert offers for the given [serviceId].
  /// Each entry: { 'id': tacheExpertId, 'nom': '...', 'description': '...' }
  Future<List<Map<String, dynamic>>> getExpertTasksForService(
    String expertId,
    String serviceId,
  ) async {
    try {
      final snap = await _db
          .collection('tacheExperts')
          .where('idExpert', isEqualTo: expertId)
          .where('idService', isEqualTo: serviceId)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,          // This is the idTacheExpert used in intervention
          'nom': data['nom'] ?? '',
          'description': data['description'] ?? '',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Step 3: Load client's addresses ───────────────────────────────────────

  /// Returns the client's saved addresses from the `adresses` collection.
  /// Uses Firebase Auth UID directly since `adresses.idUtilisateur` = UID.
  Future<List<Map<String, dynamic>>> getClientAddresses(String clientUserId) async {
    try {
      final snap = await _db
          .collection('adresses')
          .where('idUtilisateur', isEqualTo: clientUserId)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'Rue': data['Rue'] ?? '',
          'NumBatiment': data['NumBatiment'] ?? '',
          'Quartier': data['Quartier'] ?? '',
          'Ville': data['Ville'] ?? '',
          'CodePostal': data['CodePostal'] ?? '',
          'Pays': data['Pays'] ?? '',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Step 3b: Create a new address ─────────────────────────────────────────

  /// Saves a new address document and returns its Firestore ID.
  Future<String> createAddress({
    required String clientUserId,
    required String rue,
    required String numBatiment,
    required String quartier,
    required String ville,
    required String codePostal,
    required String pays,
    GeoPoint? location,
  }) async {
    final ref = await _db.collection('adresses').add({
      'idUtilisateur': clientUserId,
      'Rue': rue,
      'NumBatiment': numBatiment,
      'Quartier': quartier,
      'Ville': ville,
      'CodePostal': codePostal,
      'Pays': pays,
      if (location != null) 'location': location,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ─── Final step: Create intervention + chat atomically ─────────────────────

  /// Creates an [interventions] document (statut=EN_ATTENTE) and a linked
  /// [chats] document. Returns the chatId and interventionId so the UI can open ChatScreen.
  Future<Map<String, String>> createInterventionAndChat({
    required String clientId,       // Firebase Auth UID
    required String expertId,       // experts doc ID
    required String idTacheExpert,  // tachesExperts doc ID
    required String idAdresse,      // adresses doc ID
    required String serviceNom,
    required String taskNom,
    required Map<String, String> clientSnapshot,  // {nom, photo}
    required Map<String, String> expertSnapshot,  // {nom, photo}
    required Map<String, dynamic> adresseSnapshot,
  }) async {
    // 1. Create the intervention doc
    final interventionRef = _db.collection('interventions').doc();
    await interventionRef.set({
      'idClient': clientId,           // ← Standardizing to Firebase Auth UID
      'idExpert': expertId,
      'idTacheExpert': idTacheExpert,
      'idAdresse': idAdresse,
      'statut': 'EN_ATTENTE',
      'isUrgent': false,
      'prixNegocie': 0.0,
      'clientSnapshot': clientSnapshot,
      'expertSnapshot': expertSnapshot,
      'tacheSnapshot': {
        'nom': taskNom,
        'serviceNom': serviceNom,
      },
      'adresseSnapshot': adresseSnapshot,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Create the chat doc linked to this intervention
    // NOTE: chats.idClient intentionally keeps the Firebase Auth UID (clientId)
    // because chat_service.dart queries .where('idClient', isEqualTo: uid).
    final chatRef = _db.collection('chats').doc();
    await chatRef.set({
      'idClient': clientId,          // ← Auth UID (chat service queries by UID)
      'idExpert': expertId,
      'idIntervention': interventionRef.id,
      'estOuvert': true,
      'DateFin': null,
      'nbMessagesNonLus': 0,
      'clientSnapshot': clientSnapshot,
      'expertSnapshot': expertSnapshot,
      'tacheSnapshot': {
        'nom': taskNom,
        'serviceNom': serviceNom,
      },
      'dernierMessage': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3. Update intervention with the chatId for cross-reference
    await interventionRef.update({'idChat': chatRef.id});

    // 4. Send Notification to Expert
    await _notificationService.sendNotification(
      idUtilisateur: expertId,
      titre: "Nouvelle Demande",
      corps: "${clientSnapshot['nom']} vous a envoyé une demande pour : $serviceNom ($taskNom).",
      type: 'booking',
      relatedId: interventionRef.id,
    );

    return {
      'chatId': chatRef.id,
      'interventionId': interventionRef.id,
    };
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  /// Fetches the client's name and photo from `utilisateurs` using their UID.
  Future<Map<String, String>> getClientSnapshot(String uid) async {
    try {
      final doc = await _db.collection('utilisateurs').doc(uid).get();
      final data = doc.data() ?? {};
      return {
        'nom': data['nom'] ?? 'Client',
        'photo': data['image_profile'] ?? '',
      };
    } catch (_) {
      return {'nom': 'Client', 'photo': ''};
    }
  }

  /// Formats an address map into a readable single-line string.
  static String formatAddress(Map<String, dynamic> addr) {
    final parts = [
      addr['NumBatiment'],
      addr['Rue'],
      addr['Quartier'],
      addr['Ville'],
    ].where((p) => p != null && p.toString().isNotEmpty).toList();
    return parts.join(', ');
  }

  /// Returns the current Firebase Auth UID, or empty string if not logged in.
  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
}
