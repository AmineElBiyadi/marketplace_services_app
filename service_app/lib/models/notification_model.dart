import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String idUtilisateur;
  final String titre;
  final String corps;
  final String type;
  final String? relatedId;
  final bool estLue;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.idUtilisateur,
    required this.titre,
    required this.corps,
    required this.type,
    this.relatedId,
    required this.estLue,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      idUtilisateur: data['idUtilisateur'] ?? '',
      titre: data['titre'] ?? '',
      corps: data['corps'] ?? '',
      type: data['type'] ?? 'info',
      relatedId: data['relatedId'],
      estLue: data['estLue'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idUtilisateur': idUtilisateur,
      'titre': titre,
      'corps': corps,
      'type': type,
      'relatedId': relatedId,
      'estLue': estLue,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
