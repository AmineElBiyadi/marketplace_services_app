import 'package:cloud_firestore/cloud_firestore.dart';

class TaskExpertModel {
  final String? id;
  final String idExpert;
  final String idService;
  final String idTache;
  final String nom; // Keep nom for convenience if joined, but the source of truth is idTache
  final String description;
  final bool estActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskExpertModel({
    this.id,
    required this.idExpert,
    required this.idService,
    required this.idTache,
    required this.nom,
    this.description = '',
    this.estActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskExpertModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaskExpertModel(
      id: doc.id,
      idExpert: data['idExpert'] ?? '',
      idService: data['idService'] ?? '',
      idTache: data['idTache'] ?? '',
      nom: data['nom'] ?? '',
      description: data['description'] ?? '',
      estActive: data['estActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idExpert': idExpert,
      'idService': idService,
      'idTache': idTache,
      'nom': nom,
      'description': description,
      'estActive': estActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
