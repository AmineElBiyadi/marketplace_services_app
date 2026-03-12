import 'package:cloud_firestore/cloud_firestore.dart';

class UserSnapshot {
  final String nom;
  final String photo;

  UserSnapshot({required this.nom, required this.photo});

  factory UserSnapshot.fromMap(Map<String, dynamic> map) => UserSnapshot(
        nom:   map['nom'] ?? '',
        photo: map['photo'] ?? '',
      );
}

class DernierMessage {
  final String contenu;
  final String senderId;
  final String type;
  final Timestamp? createdAt;

  DernierMessage({
    required this.contenu,
    required this.senderId,
    required this.type,
    this.createdAt,
  });

  factory DernierMessage.fromMap(Map<String, dynamic> map) => DernierMessage(
        contenu:  map['contenu'] ?? '',
        senderId: map['senderId'] ?? '',
        type:     map['type'] ?? 'TEXT',
        createdAt: map['createdAt'],
      );

  Map<String, dynamic> toMap() => {
        'contenu':   contenu,
        'senderId':  senderId,
        'type':      type,
        'createdAt': FieldValue.serverTimestamp(),
      };
}

class ChatModel {
  final String chatId;
  final String idClient;
  final String idExpert;
  final String idIntervention;
  final bool estOuvert;
  final Timestamp? dateFin;
  final int nbMessagesNonLus;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final UserSnapshot clientSnapshot;
  final UserSnapshot expertSnapshot;
  final DernierMessage? dernierMessage;

  ChatModel({
    required this.chatId,
    required this.idClient,
    required this.idExpert,
    required this.idIntervention,
    required this.estOuvert,
    this.dateFin,
    required this.nbMessagesNonLus,
    required this.createdAt,
    required this.updatedAt,
    required this.clientSnapshot,
    required this.expertSnapshot,
    this.dernierMessage,
  });

  factory ChatModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      chatId:           doc.id,
      idClient:         data['idClient'] ?? '',
      idExpert:         data['idExpert'] ?? '',
      idIntervention:   data['idIntervention'] ?? '',
      estOuvert:        data['estOuvert'] ?? true,
      dateFin:          data['DateFin'],
      nbMessagesNonLus: data['nbMessagesNonLus'] ?? 0,
      createdAt:        data['createdAt'] ?? Timestamp.now(),
      updatedAt:        data['updatedAt'] ?? Timestamp.now(),
      clientSnapshot:   UserSnapshot.fromMap(
                            data['clientSnapshot'] as Map<String, dynamic>? ?? {}),
      expertSnapshot:   UserSnapshot.fromMap(
                            data['expertSnapshot'] as Map<String, dynamic>? ?? {}),
      dernierMessage:   data['dernierMessage'] != null
                            ? DernierMessage.fromMap(
                                data['dernierMessage'] as Map<String, dynamic>)
                            : null,
    );
  }
}
