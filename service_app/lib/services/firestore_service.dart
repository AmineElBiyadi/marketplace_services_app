import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expert.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Expert>> getExperts() async {
    try {
      final expertsSnapshot = await _db.collection('experts').get();
      List<Expert> experts = [];

      for (var expertDoc in expertsSnapshot.docs) {
        final expertData = expertDoc.data();
        final expertId = expertDoc.id;
        final userId = expertData['idUtilisateur'];

        // 1 — Récupérer l'utilisateur lié
        final userDoc = await _db
            .collection('utilisateurs')
            .doc(userId)
            .get();
        final userData = userDoc.data() ?? {};

        // 2 — Récupérer la ville depuis adresses
        final adresseSnapshot = await _db
            .collection('adresses')
            .where('idUtilisateur', isEqualTo: userId)
            .get();

        String ville = '';
        if (adresseSnapshot.docs.isNotEmpty) {
          final adresse = adresseSnapshot.docs.first.data();
          ville =
          '${adresse['Ville'] ?? ''}, ${adresse['Quartier'] ?? ''}';
        }

        // 3 — Vérifier si Premium
        final abonnementSnapshot = await _db
            .collection('abonnements')
            .where('idExpert', isEqualTo: expertId)
            .where('statut', isEqualTo: 'ACTIVE')
            .get();
        final isPremium = abonnementSnapshot.docs.isNotEmpty;

        // 4 — Récupérer les services
        final serviceExpertsSnapshot = await _db
            .collection('serviceExperts')
            .where('idExpert', isEqualTo: expertId)
            .get();

        List<String> services = [];
        for (var se in serviceExpertsSnapshot.docs) {
          final serviceDoc = await _db
              .collection('services')
              .doc(se.data()['idService'])
              .get();
          if (serviceDoc.exists) {
            services.add(serviceDoc.data()?['nom'] ?? '');
          }
        }

        // 5 — Récupérer note moyenne
        final interventionsSnapshot = await _db
            .collection('interventions')
            .where('idExpert', isEqualTo: expertId)
            .get();

        double noteMoyenne = 0.0;
        if (interventionsSnapshot.docs.isNotEmpty) {
          final firstIntervention =
          interventionsSnapshot.docs.first.data();
          noteMoyenne = (firstIntervention['expertSnapshot']
          ?['note_moyenne'] ??
              0.0)
              .toDouble();
        }

        // 6 — Construire Expert
        experts.add(Expert(
          id: expertId,
          nom: userData['nom'] ?? userData['email'] ?? 'Expert',
          photo: userData['image_profile'] ?? '',
          telephone: userData['telephone'] ?? '',
          noteMoyenne: noteMoyenne,
          isPremium: isPremium,
          services: services,
          ville: ville,
        ));
      }

      // 7 — Trier : Premium en premier, ensuite par note
      experts.sort((a, b) {
        if (a.isPremium && !b.isPremium) return -1;
        if (!a.isPremium && b.isPremium) return 1;
        return b.noteMoyenne.compareTo(a.noteMoyenne);
      });

      return experts;
    } catch (e) {
      print('Erreur getExperts: $e');
      return [];
    }
  }

  // Récupérer toutes les villes des experts
  Future<List<String>> getVillesExperts() async {
    try {
      final expertsSnapshot = await _db.collection('experts').get();
      Set<String> villes = {};

      for (var expertDoc in expertsSnapshot.docs) {
        final userId = expertDoc.data()['idUtilisateur'];

        final adresseSnapshot = await _db
            .collection('adresses')
            .where('idUtilisateur', isEqualTo: userId)
            .get();

        if (adresseSnapshot.docs.isNotEmpty) {
          final adresse = adresseSnapshot.docs.first.data();
          final ville =
              '${adresse['Ville'] ?? ''}, ${adresse['Quartier'] ?? ''}';
          if (ville.trim() != ',') villes.add(ville);
        }
      }

      return villes.toList();
    } catch (e) {
      print('Erreur getVillesExperts: $e');
      return [];
    }
  }
}