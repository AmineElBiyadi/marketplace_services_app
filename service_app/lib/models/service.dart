import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String? id;
  final String nom;
  final String description;
  final String? image;
  final bool estActive;
  final DateTime? createdAt;

  ServiceModel({
    this.id,
    required this.nom,
    required this.description,
    this.image,
    this.estActive = true,
    this.createdAt,
  });

  factory ServiceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ServiceModel(
      id: doc.id,
      nom: data['nom'] ?? '',
      description: data['description'] ?? '',
      image: data['image'],
      estActive: data['estActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'description': description,
      'image': image,
      'estActive': estActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
