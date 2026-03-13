import 'package:cloud_firestore/cloud_firestore.dart';

class ExpertServiceModel {
  final String? id;
  final String idExpert;
  final String idService;
  final String description;
  final bool estActive;
  final bool estCertifie;
  final int anneeExperience;
  final DateTime? createdAt;

  ExpertServiceModel({
    this.id,
    required this.idExpert,
    required this.idService,
    this.description = '',
    this.estActive = true,
    this.estCertifie = false,
    this.anneeExperience = 0,
    this.createdAt,
  });

  factory ExpertServiceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ExpertServiceModel(
      id: doc.id,
      idExpert: data['idExpert'] ?? '',
      idService: data['idService'] ?? '',
      description: data['description'] ?? '',
      estActive: data['estActive'] ?? true,
      estCertifie: data['estCertifie'] ?? false,
      anneeExperience: data['anneeExperience'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idExpert': idExpert,
      'idService': idService,
      'description': description,
      'estActive': estActive,
      'estCertifie': estCertifie,
      'anneeExperience': anneeExperience,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
