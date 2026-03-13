import 'package:cloud_firestore/cloud_firestore.dart';

class InterventionModel {
  final String? id;
  final String idClient;
  final String idExpert;
  final String idTacheExpert;
  final String idAdresse;
  final String statut; // EN_ATTENTE | ACCEPTEE | REFUSEE | TERMINEE | ANNULEE
  final bool isUrgent;
  final double prixNegocie;
  final String? codeValidationExpert;
  final DateTime? dateDebutIntervention;
  final DateTime? dateFinIntervention;
  final String? motifeAnnulation;
  
  // Snapshots
  final Map<String, dynamic>? clientSnapshot;
  final Map<String, dynamic>? expertSnapshot;
  final Map<String, dynamic>? tacheSnapshot;
  final Map<String, dynamic>? adresseSnapshot;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  InterventionModel({
    this.id,
    required this.idClient,
    required this.idExpert,
    required this.idTacheExpert,
    required this.idAdresse,
    required this.statut,
    required this.isUrgent,
    required this.prixNegocie,
    this.codeValidationExpert,
    this.dateDebutIntervention,
    this.dateFinIntervention,
    this.motifeAnnulation,
    this.clientSnapshot,
    this.expertSnapshot,
    this.tacheSnapshot,
    this.adresseSnapshot,
    this.createdAt,
    this.updatedAt,
  });

  factory InterventionModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return InterventionModel(
      id: doc.id,
      idClient: data['idClient'] ?? '',
      idExpert: data['idExpert'] ?? '',
      idTacheExpert: data['idTacheExpert'] ?? '',
      idAdresse: data['idAdresse'] ?? '',
      statut: data['statut'] ?? 'EN_ATTENTE',
      isUrgent: data['isUrgent'] ?? false,
      prixNegocie: (data['prixNegocie'] as num?)?.toDouble() ?? 0.0,
      codeValidationExpert: data['codeValidationExpert'],
      dateDebutIntervention: (data['dateDebutIntervention'] as Timestamp?)?.toDate(),
      dateFinIntervention: (data['dateFinIntervention'] as Timestamp?)?.toDate(),
      motifeAnnulation: data['motifeAnnulation'],
      clientSnapshot: data['clientSnapshot'],
      expertSnapshot: data['expertSnapshot'],
      tacheSnapshot: data['tacheSnapshot'],
      adresseSnapshot: data['adresseSnapshot'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idClient': idClient,
      'idExpert': idExpert,
      'idTacheExpert': idTacheExpert,
      'idAdresse': idAdresse,
      'statut': statut,
      'isUrgent': isUrgent,
      'prixNegocie': prixNegocie,
      if (codeValidationExpert != null) 'codeValidationExpert': codeValidationExpert,
      if (dateDebutIntervention != null) 'dateDebutIntervention': Timestamp.fromDate(dateDebutIntervention!),
      if (dateFinIntervention != null) 'dateFinIntervention': Timestamp.fromDate(dateFinIntervention!),
      if (motifeAnnulation != null) 'motifeAnnulation': motifeAnnulation,
      if (clientSnapshot != null) 'clientSnapshot': clientSnapshot,
      'expertSnapshot': expertSnapshot,
      'tacheSnapshot': tacheSnapshot,
      'adresseSnapshot': adresseSnapshot,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
