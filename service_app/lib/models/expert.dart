import 'package:cloud_firestore/cloud_firestore.dart';
import 'user.dart';

class ExpertModel {
  final String? id;
  final String idUtilisateur;
  final String etatCompte; // ACTIVE | DESACTIVE | SUSPENDUE
  final String experience;
  final int rayonTravaille;
  final bool casierJudiciaire;
  final String? carteNationale;
  final int profileViews;
  final bool estDisponible;
  
  // Potential joined data
  final UserModel? user;
  final GeoPoint? location;

  ExpertModel({
    this.id,
    required this.idUtilisateur,
    required this.etatCompte,
    required this.experience,
    required this.rayonTravaille,
    required this.casierJudiciaire,
    this.carteNationale,
    this.profileViews = 0,
    this.estDisponible = true,
    this.user,
    this.location,
  });

  factory ExpertModel.fromFirestore(DocumentSnapshot doc,
      {UserModel? user}) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ExpertModel(
      id: doc.id,
      idUtilisateur: data['idUtilisateur'] ?? '',
      etatCompte: data['etatCompte'] ?? 'ACTIVE',
      experience: data['Experience'] ?? '',
      rayonTravaille: data['rayonTravaille'] ?? 0,
      casierJudiciaire: data['CasierJudiciaire'] ?? false,
      carteNationale: data['CarteNationale'],
      profileViews: data['profileViews'] ?? 0,
      estDisponible: data['estDisponible'] ?? data['estdisponible'] ?? true,
      user: user,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idUtilisateur': idUtilisateur,
      'etatCompte': etatCompte,
      'Experience': experience,
      'rayonTravaille': rayonTravaille,
      'CasierJudiciaire': casierJudiciaire,
      'CarteNationale': carteNationale,
      'profileViews': profileViews,
      'estDisponible': estDisponible,
    };
  }
}

/// Flat model used for listing/search results (built from joined Firestore data).
class Expert {
  final String id;
  final String nom;
  final String photo;
  final String telephone;
  final double noteMoyenne;
  final bool isPremium;
  final List<String> services;
  final String ville;
  final bool estDisponible;


  /// Prix minimum affiché (ex: champ [prixMin] dans Firestore ou calculé
  /// depuis les tâches de l'expert). Null si non renseigné.
  final double? prixMin;

  /// Position GPS de l'expert (null si non renseignée).
  final GeoPoint? location;

  Expert({
    required this.id,
    required this.nom,
    required this.photo,
    required this.telephone,
    required this.noteMoyenne,
    required this.isPremium,
    required this.services,
    required this.ville,
    this.estDisponible = true,
    this.prixMin,
    this.location,
  });


  factory Expert.fromFirestore(Map<String, dynamic> data, String id) {
    return Expert(
      id: id,
      nom: data['nom'] ?? '',
      photo: data['photo'] ?? '',
      telephone: data['telephone'] ?? '',
      noteMoyenne: (data['noteMoyenne'] ?? 0.0).toDouble(),
      isPremium: data['isPremium'] ?? false,
      services: List<String>.from(data['services'] ?? []),
      ville: data['ville'] ?? '',
      estDisponible: data['estDisponible'] ?? data['estdisponible'] ?? true,
      prixMin: data['prixMin'] != null
          ? (data['prixMin'] as num).toDouble()
          : null,
      location: data['location'] as GeoPoint?,
    );
  }


  Expert copyWith({
    String? id,
    String? nom,
    String? photo,
    String? telephone,
    double? noteMoyenne,
    bool? isPremium,
    List<String>? services,
    String? ville,
    bool? estDisponible,
    double? prixMin,
    GeoPoint? location,
  }) {
    return Expert(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      photo: photo ?? this.photo,
      telephone: telephone ?? this.telephone,
      noteMoyenne: noteMoyenne ?? this.noteMoyenne,
      isPremium: isPremium ?? this.isPremium,
      services: services ?? this.services,
      ville: ville ?? this.ville,
      estDisponible: estDisponible ?? this.estDisponible,
      prixMin: prixMin ?? this.prixMin,
      location: location ?? this.location,
    );
  }

}