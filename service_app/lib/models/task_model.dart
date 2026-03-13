import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String? id;
  final String idService;
  final String? idExpert;
  final String nom;
  final String description;
  final bool estActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TaskModel({
    this.id,
    required this.idService,
    this.idExpert,
    required this.nom,
    this.description = '',
    this.estActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      idService: data['idService'] ?? '',
      idExpert: data['idExpert'],
      nom: data['nom'] ?? '',
      description: data['description'] ?? '',
      estActive: data['estActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idService': idService,
      'idExpert': idExpert,
      'nom': nom,
      'description': description,
      'estActive': estActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
