import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId; // field name is "SenderId" in Firestore (capital S)
  final String contenu;
  final String idChat;
  final String type;   // "TEXT"
  final String statut; // "LU" or "NON_LU"
  final Timestamp createdAt;
  final Timestamp updatedAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.contenu,
    required this.idChat,
    required this.type,
    required this.statut,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MessageModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id:        doc.id,
      senderId:  data['SenderId'] ?? '',
      contenu:   data['contenu'] ?? '',
      idChat:    data['idChat'] ?? '',
      type:      data['type'] ?? 'TEXT',
      statut:    data['statut'] ?? 'NON_LU',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap(String chatId) => {
    'SenderId':  senderId,
    'contenu':   contenu,
    'idChat':    chatId,
    'type':      type,
    'statut':    'NON_LU',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  bool get isRead => statut == 'LU';
}
