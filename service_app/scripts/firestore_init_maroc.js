/**
 * ============================================================
 *  FIRESTORE INITIALIZER — Marketplace App (Flutter + Firebase)
 *  2 Experts Marocains pour test
 * ============================================================
 */

const admin = require("firebase-admin");
const serviceAccount = require("./services-app-70555-firebase-adminsdk-fbsvc-3d42f1831d.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const seedData = {

  // ----------------------------------------------------------
  // UTILISATEURS
  // ----------------------------------------------------------
  utilisateurs: [
    // Client
    {
      id: "user_001",
      email: "alice@example.com",
      nom: "Alice Bennani",
      motDePasse: "hashed_password",
      telephone: "+212612345678",
      image_profile: "https://randomuser.me/api/portraits/women/44.jpg",
      token: "fcm_token_abc123",
      location: new admin.firestore.GeoPoint(33.5731, -7.5898),
      updated_At: admin.firestore.FieldValue.serverTimestamp(),
      created_At: admin.firestore.FieldValue.serverTimestamp(),
    },
    // Admin
    {
      id: "user_admin_001",
      email: "admin@example.com",
      nom: "Admin",
      motDePasse: "hashed_password",
      telephone: null,
      image_profile: null,
      token: "fcm_token_admin",
      location: null,
      updated_At: null,
      created_At: null,
    },
    // Expert 1 — Plombier (Casablanca, Ain Diab) — Premium
    {
      id: "user_exp_001",
      email: "youssef.alami@gmail.com",
      nom: "Youssef Alami",
      motDePasse: "hashed_password",
      telephone: "+212661234501",
      image_profile: "https://randomuser.me/api/portraits/men/32.jpg",
      token: "fcm_exp_001",
      location: new admin.firestore.GeoPoint(33.5950, -7.6192),
      updated_At: admin.firestore.FieldValue.serverTimestamp(),
      created_At: admin.firestore.FieldValue.serverTimestamp(),
    },
    // Expert 2 — Jardinage (Rabat, Agdal)
    {
      id: "user_exp_002",
      email: "fatima.idrissi@gmail.com",
      nom: "Fatima Zahra Idrissi",
      motDePasse: "hashed_password",
      telephone: "+212661234502",
      image_profile: "https://randomuser.me/api/portraits/women/65.jpg",
      token: "fcm_exp_002",
      location: new admin.firestore.GeoPoint(34.0209, -6.8416),
      updated_At: admin.firestore.FieldValue.serverTimestamp(),
      created_At: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // ADRESSES
  // ----------------------------------------------------------
  adresses: [
    // Client — Casablanca, Maarif
    {
      id: "addr_001",
      idUtilisateur: "user_001",
      NumBatiment: "12",
      Rue: "Rue Moulay Youssef",
      Quartier: "Maarif",
      Ville: "Casablanca",
      CodePostal: "20100",
      Pays: "Maroc",
    },
    // Expert 1 — Casablanca, Ain Diab
    {
      id: "addr_exp_001",
      idUtilisateur: "user_exp_001",
      NumBatiment: "5",
      Rue: "Rue Ibn Battouta",
      Quartier: "Ain Diab",
      Ville: "Casablanca",
      CodePostal: "20050",
      Pays: "Maroc",
    },
    // Expert 2 — Rabat, Agdal
    {
      id: "addr_exp_002",
      idUtilisateur: "user_exp_002",
      NumBatiment: "8",
      Rue: "Avenue Hassan II",
      Quartier: "Agdal",
      Ville: "Rabat",
      CodePostal: "10000",
      Pays: "Maroc",
    },
  ],

  // ----------------------------------------------------------
  // CLIENTS
  // ----------------------------------------------------------
  clients: [
    {
      id: "client_001",
      idUtilisateur: "user_001",
      etatCompte: "ACTIVE",
    },
  ],

  // ----------------------------------------------------------
  // EXPERTS
  // ----------------------------------------------------------
  experts: [
    // Expert 1 — Plombier Premium
    {
      id: "expert_001",
      idUtilisateur: "user_exp_001",
      etatCompte: "ACTIVE",
      Experience: "Plomberie résidentielle et industrielle, 8 ans d'expérience",
      rayonTravaille: 30,
      CasierJudiciaire: false,
      CarteNationale: "https://storage.example.com/docs/carte_youssef.pdf",
    },
    // Expert 2 — Jardinage
    {
      id: "expert_002",
      idUtilisateur: "user_exp_002",
      etatCompte: "ACTIVE",
      Experience: "Entretien jardins et espaces verts, 5 ans d'expérience",
      rayonTravaille: 20,
      CasierJudiciaire: false,
      CarteNationale: "https://storage.example.com/docs/carte_fatima.pdf",
    },
  ],

  // ----------------------------------------------------------
  // ADMINS
  // ----------------------------------------------------------
  admins: [
    {
      id: "admin_001",
      idUtilisateur: "user_admin_001",
    },
  ],

  // ----------------------------------------------------------
  // ABONNEMENTS
  // ----------------------------------------------------------
  abonnements: [
    // Expert 1 — Premium ACTIVE 👑
    {
      id: "abon_001",
      idExpert: "expert_001",
      statut: "ACTIVE",
      dateDebut: admin.firestore.Timestamp.fromDate(new Date("2025-01-01")),
      dateFin: admin.firestore.Timestamp.fromDate(new Date("2026-01-01")),
      montant: 99.00,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    // Expert 2 — Pas Premium
    {
      id: "abon_002",
      idExpert: "expert_002",
      statut: "EXPIRE",
      dateDebut: admin.firestore.Timestamp.fromDate(new Date("2024-01-01")),
      dateFin: admin.firestore.Timestamp.fromDate(new Date("2025-01-01")),
      montant: 99.00,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // SERVICES
  // ----------------------------------------------------------
  services: [
    {
      id: "service_001",
      nom: "Plomberie",
      description: "Réparation et installation de plomberie",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "service_002",
      nom: "Électricité",
      description: "Travaux électriques certifiés",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "service_003",
      nom: "Nettoyage",
      description: "Nettoyage résidentiel et professionnel",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "service_004",
      nom: "Jardinage",
      description: "Entretien jardins et espaces verts",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "service_005",
      nom: "Coiffure",
      description: "Coiffure à domicile homme et femme",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // SERVICE EXPERTS
  // ----------------------------------------------------------
  serviceExperts: [
    // Expert 1 → Plomberie
    {
      id: "se_001",
      idExpert: "expert_001",
      idService: "service_001",
      anneeExperience: 8,
      estCertifie: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    // Expert 2 → Jardinage
    {
      id: "se_002",
      idExpert: "expert_002",
      idService: "service_004",
      anneeExperience: 5,
      estCertifie: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // TACHES
  // ----------------------------------------------------------
  taches: [
    {
      id: "tache_001",
      idService: "service_001",
      nom: "Réparer une fuite",
      description: "Réparer une fuite d'eau sous l'évier",
      estActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "tache_002",
      idService: "service_001",
      nom: "Installation robinetterie",
      description: "Installation de robinets et mitigeurs",
      estActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "tache_003",
      idService: "service_004",
      nom: "Taille de haies",
      description: "Taille et entretien de haies et arbustes",
      estActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "tache_004",
      idService: "service_004",
      nom: "Tonte de pelouse",
      description: "Tonte et entretien de pelouse",
      estActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // TACHE EXPERTS
  // ----------------------------------------------------------
  tacheExperts: [
    {
      id: "te_001",
      idExpert: "expert_001",
      idTache: "tache_001",
      status: "ACTIVE",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "te_002",
      idExpert: "expert_001",
      idTache: "tache_002",
      status: "ACTIVE",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "te_003",
      idExpert: "expert_002",
      idTache: "tache_003",
      status: "ACTIVE",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "te_004",
      idExpert: "expert_002",
      idTache: "tache_004",
      status: "ACTIVE",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // INTERVENTIONS (pour les notes moyennes)
  // ----------------------------------------------------------
  interventions: [
    {
      id: "interv_001",
      idClient: "client_001",
      idExpert: "expert_001",
      idTacheExpert: "te_001",
      idAdresse: "addr_001",
      statut: "TERMINEE",
      isUrgent: false,
      prixNegocie: 150.00,
      codeValidationExpert: "VAL-1001",
      dateDebutIntervention: admin.firestore.Timestamp.fromDate(new Date("2025-03-01T09:00:00")),
      dateFinIntervention: admin.firestore.Timestamp.fromDate(new Date("2025-03-01T11:00:00")),
      clientSnapshot: {
        nom: "Alice Bennani",
        photo: "https://randomuser.me/api/portraits/women/44.jpg",
        telephone: "+212612345678",
      },
      expertSnapshot: {
        nom: "Youssef Alami",
        photo: "https://randomuser.me/api/portraits/men/32.jpg",
        telephone: "+212661234501",
        note_moyenne: 4.8,
      },
      tacheSnapshot: {
        nom: "Réparer une fuite",
        serviceNom: "Plomberie",
      },
      adresseSnapshot: {
        Rue: "Rue Moulay Youssef",
        Ville: "Casablanca",
        CodePostal: "20100",
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "interv_002",
      idClient: "client_001",
      idExpert: "expert_002",
      idTacheExpert: "te_003",
      idAdresse: "addr_001",
      statut: "TERMINEE",
      isUrgent: false,
      prixNegocie: 200.00,
      codeValidationExpert: "VAL-1002",
      dateDebutIntervention: admin.firestore.Timestamp.fromDate(new Date("2025-03-05T09:00:00")),
      dateFinIntervention: admin.firestore.Timestamp.fromDate(new Date("2025-03-05T12:00:00")),
      clientSnapshot: {
        nom: "Alice Bennani",
        photo: "https://randomuser.me/api/portraits/women/44.jpg",
        telephone: "+212612345678",
      },
      expertSnapshot: {
        nom: "Fatima Zahra Idrissi",
        photo: "https://randomuser.me/api/portraits/women/65.jpg",
        telephone: "+212661234502",
        note_moyenne: 4.5,
      },
      tacheSnapshot: {
        nom: "Taille de haies",
        serviceNom: "Jardinage",
      },
      adresseSnapshot: {
        Rue: "Rue Moulay Youssef",
        Ville: "Casablanca",
        CodePostal: "20100",
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // EVALUATIONS
  // ----------------------------------------------------------
  evaluations: [
    {
      id: "eval_001",
      idIntervention: "interv_001",
      idClient: "client_001",
      idExpert: "expert_001",
      note: 4.8,
      commentaire: "Excellent travail, très professionnel et ponctuel !",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "eval_002",
      idIntervention: "interv_002",
      idClient: "client_001",
      idExpert: "expert_002",
      note: 4.5,
      commentaire: "Très bon travail, jardin impeccable !",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // NOTIFICATIONS
  // ----------------------------------------------------------
  notifications: [
    {
      id: "notif_001",
      idUtilisateur: "user_001",
      titre: "Intervention confirmée",
      message: "Votre intervention avec Youssef Alami est confirmée.",
      estLue: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],
};

// ============================================================
//  FONCTION D'INSERTION
// ============================================================
async function seedFirestore() {
  const batch = db.batch();
  let opCount = 0;
  const MAX_BATCH = 499;
  const batches = [batch];
  let currentBatch = batch;

  for (const [collectionName, documents] of Object.entries(seedData)) {
    console.log(`📁 Collection : ${collectionName} (${documents.length} doc(s))`);
    for (const doc of documents) {
      const { id, ...data } = doc;
      const ref = db.collection(collectionName).doc(id);
      if (opCount >= MAX_BATCH) {
        const newBatch = db.batch();
        batches.push(newBatch);
        currentBatch = newBatch;
        opCount = 0;
      }
      currentBatch.set(ref, data, { merge: true });
      opCount++;
    }
  }

  for (let i = 0; i < batches.length; i++) {
    await batches[i].commit();
    console.log(`✅ Batch ${i + 1}/${batches.length} commité`);
  }
  console.log("\n🎉 2 experts marocains créés avec succès !");
}

seedFirestore().catch((err) => {
  console.error("❌ Erreur :", err);
  process.exit(1);
});
