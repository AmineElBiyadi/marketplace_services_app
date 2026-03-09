import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expert.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Récupérer tous les experts avec leur statut Premium
  Future<List<Expert>> getExperts() async {
    try {
      // 1 — Récupérer tous les experts
      final expertsSnapshot = await _db.collection('experts').get();

      List<Expert> experts = [];

      for (var expertDoc in expertsSnapshot.docs) {
        final expertData = expertDoc.data();
        final expertId = expertDoc.id;

        // 2 — Récupérer l'utilisateur lié
        final userId = expertData['idUtilisateur'];
        final userDoc = await _db.collection('utilisateurs').doc(userId).get();
        final userData = userDoc.data() ?? {};

        // 3 — Vérifier si Premium (abonnement ACTIVE)
        final abonnementSnapshot = await _db
            .collection('abonnements')
            .where('idExpert', isEqualTo: expertId)
            .where('statut', isEqualTo: 'ACTIVE')
            .get();
        final isPremium = abonnementSnapshot.docs.isNotEmpty;

        // 4 — Récupérer les services de l'expert
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
        // Après avoir récupéré les services
        print('✅ Services récupérés pour $expertId: $services');

        // 5 — Récupérer note moyenne depuis expertSnapshot
        final interventionsSnapshot = await _db
            .collection('interventions')
            .where('idExpert', isEqualTo: expertId)
            .get();

        double noteMoyenne = 0.0;
        if (interventionsSnapshot.docs.isNotEmpty) {
          final firstIntervention = interventionsSnapshot.docs.first.data();
          noteMoyenne = (firstIntervention['expertSnapshot']
          ?['note_moyenne'] ?? 0.0)
              .toDouble();
        }

        // 6 — Construire l'objet Expert
        experts.add(Expert(
          id: expertId,
          nom: userData['email'] ?? 'Expert',
          photo: userData['image_profile'] ?? '',
          telephone: userData['telephone'] ?? '',
          noteMoyenne: noteMoyenne,
          isPremium: isPremium,
          services: services,
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
}