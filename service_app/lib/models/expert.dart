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