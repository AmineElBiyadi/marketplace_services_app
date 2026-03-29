import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';

class ChatService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  // ─── Send a message ──────────────────────────────────────────
  Future<void> sendMessage({
    required String chatId,
    required String contenu,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Vous devez être connecté.');

    final messagesRef = _db
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    final chatRef = _db.collection('chats').doc(chatId);

    await messagesRef.add({
      'SenderId':  uid,
      'contenu':   contenu,
      'idChat':    chatId,
      'type':      'TEXT',
      'statut':    'NON_LU',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await chatRef.update({
      'dernierMessage': {
        'contenu':   contenu,
        'senderId':  uid,
        'type':      'TEXT',
        'createdAt': FieldValue.serverTimestamp(),
      },
      'nbMessagesNonLus': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Real-time stream of messages ────────────────────────────
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(MessageModel.fromDoc).toList());
  }

  // ─── Stream of chats for the current user ────────────────────
  Stream<List<ChatModel>> getUserChats(String userRole, {String? expertId}) async* {
    if (userRole == 'client') {
      final uid = currentUserId;
      if (uid.isEmpty) {
        yield [];
        return;
      }
      yield* _db
          .collection('chats')
          .where('idClient', isEqualTo: uid)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(ChatModel.fromDoc).toList());
    } else {
      final resolvedExpertId = expertId ?? await _getExpertIdForCurrentUser();
      print(">>> ChatService.getUserChats: resolvedExpertId = $resolvedExpertId");
      if (resolvedExpertId == null) {
        yield [];
        return;
      }
      yield* _db
          .collection('chats')
          .where('idExpert', isEqualTo: resolvedExpertId)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snap) {
            print(">>> ChatService.getUserChats: Founded ${snap.docs.length} chats for expertId $resolvedExpertId");
            return snap.docs.map(ChatModel.fromDoc).toList();
          });
    }
  }

  Future<String?> _getExpertIdForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    final email = user.email!;
    QuerySnapshot userQuery;

    if (email.endsWith('@proxy.marketplace.app')) {
      final phoneString = email.replaceAll('@proxy.marketplace.app', '');

      // Prepare variations: 212xxxx, +212xxxx, 0xxxx
      String localFormat = phoneString;
      if (phoneString.startsWith('212')) {
        localFormat = '0${phoneString.substring(3)}';
      }
      
      final variations = {phoneString, '+$phoneString', localFormat}.toList();

      userQuery = await _db
          .collection('utilisateurs')
          .where('telephone', whereIn: variations)
          .limit(1)
          .get();
    } else {
      userQuery = await _db
          .collection('utilisateurs')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
    }

    if (userQuery.docs.isEmpty) return null;
    final userId = userQuery.docs.first.id;

    final expertQuery = await _db
        .collection('experts')
        .where('idUtilisateur', isEqualTo: userId)
        .limit(1)
        .get();

    if (expertQuery.docs.isEmpty) return null;
    return expertQuery.docs.first.id;
  }

  // ─── Mark all unread messages as LU ──────────────────────────
  Future<void> markMessagesAsRead(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'nbMessagesNonLus': 0,
    });

    final unread = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('statut', isEqualTo: 'NON_LU')
        .where('SenderId', isNotEqualTo: currentUserId)
        .get();

    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {
        'statut':    'LU',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ─── Create a new chat document ──────────────────────────────
  Future<String> createChat({
    required String idClient,
    required String idExpert,
    required String idIntervention,
    required Map<String, String> clientSnapshot,
    required Map<String, String> expertSnapshot,
  }) async {
    // Check if a chat already exists for this intervention to avoid duplicates
    final existing = await _db
        .collection('chats')
        .where('idClient', isEqualTo: idClient)
        .where('idExpert', isEqualTo: idExpert)
        .where('idIntervention', isEqualTo: idIntervention)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final chatRef = _db.collection('chats').doc();
    await chatRef.set({
      'idClient':          idClient,
      'idExpert':          idExpert,
      'idIntervention':    idIntervention,
      'estOuvert':         true,
      'DateFin':           null,
      'nbMessagesNonLus':  0,
      'clientSnapshot':    clientSnapshot,
      'expertSnapshot':    expertSnapshot,
      'dernierMessage':    null,
      'createdAt':         FieldValue.serverTimestamp(),
      'updatedAt':         FieldValue.serverTimestamp(),
    });

    return chatRef.id;
  }

  // ─── Close a chat (set estOuvert = false) ────────────────────
  Future<void> closeChat(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'estOuvert': false,
      'DateFin':   FieldValue.serverTimestamp(),
    });
  }

  // ─── Fetch a single chat by ID ────────────────────────────────
  Future<ChatModel?> getChatById(String chatId) async {
    final doc = await _db.collection('chats').doc(chatId).get();
    if (!doc.exists) return null;
    return ChatModel.fromDoc(doc);
  }
}
