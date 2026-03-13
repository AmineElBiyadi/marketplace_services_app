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
  });

  factory ExpertModel.fromFirestore(DocumentSnapshot doc, {UserModel? user}) {
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
      estDisponible: data['estDisponible'] ?? true,
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

/// Flat model used for listing/search results (built from joined Firestore data)
class Expert {
  final String id;
  final String nom;
  final String photo;
  final String telephone;
  final double noteMoyenne;
  final bool isPremium;
  final List<String> services;
  final String ville;

  Expert({
    required this.id,
    required this.nom,
    required this.photo,
    required this.telephone,
    required this.noteMoyenne,
    required this.isPremium,
    required this.services,
    required this.ville,
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
    );
  }
}
