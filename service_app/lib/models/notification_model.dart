import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  booking,      // Intervention status changes, new requests
  review,       // New client review
  claim,        // Admin response to a complaint
  account,      // Account status change (Expert)
  adminAction,  // New provider to validate, new complaint
}

class NotificationModel {
  final String id;
  final String idUtilisateur;
  final String titre;
  final String corps;
  final String type; // For easy Firestore storage
  final String? relatedId; // ID of the intervention, claim, etc.
  final bool estLue;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.idUtilisateur,
    required this.titre,
    required this.corps,
    required this.type,
    this.relatedId,
    this.estLue = false,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      idUtilisateur: data['idUtilisateur'] ?? '',
      titre: data['titre'] ?? '',
      corps: data['corps'] ?? '',
      type: data['type'] ?? 'booking',
      relatedId: data['relatedId'],
      estLue: data['estLue'] ?? false,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
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
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
