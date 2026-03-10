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
    };
  }
}
