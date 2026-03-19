/**
 * ============================================================
 *  FIRESTORE INITIALIZER — Marketplace App (Flutter + Firebase)
 *  Basé sur le MCD fourni
 *
 *  USAGE :
 *    1. npm install firebase-admin
 *    2. Téléchargez votre serviceAccountKey.json depuis Firebase Console
 *       > Project Settings > Service Accounts > Generate new private key
 *    3. node firestore_init.js
 * ============================================================
 */

const admin = require("firebase-admin");
const serviceAccount = require("./services-app-70555-firebase-adminsdk-fbsvc-3d42f1831d.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ============================================================
//  DONNÉES D'EXEMPLE PAR COLLECTION
// ============================================================

const seedData = {

  // ----------------------------------------------------------
  // UTILISATEUR (utilisateur de base — héritage client/expert/admin)
  // ----------------------------------------------------------
  utilisateurs: [
    {
      id: "user_001",
      email: "alice@example.com",
      motDePasse: "hashed_password",        // stocker le hash, jamais le clair
      telephone: "+33612345678",
      image_profile: "https://storage.example.com/profiles/alice.jpg",
      token: "fcm_token_abc123",
      location: new admin.firestore.GeoPoint(48.8566, 2.3522), // coordonnée GeoPoint
      updated_At: admin.firestore.FieldValue.serverTimestamp(),
      created_At: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "user_002",
      email: "bob.expert@example.com",
      motDePasse: "hashed_password",
      telephone: "+33698765432",
      image_profile: "https://storage.example.com/profiles/bob.jpg",
      token: "fcm_token_def456",
      location: new admin.firestore.GeoPoint(48.8600, 2.3470),
      updated_At: admin.firestore.FieldValue.serverTimestamp(),
      created_At: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: "user_admin_001",
      email: "admin@example.com",
      motDePasse: "hashed_password",
      telephone: null,
      image_profile: null,
      token: "fcm_token_admin",
      location: null,
      updated_At: null,
      created_At: null,
    },
  ],

  // ----------------------------------------------------------
  // ADRESSE
  // ----------------------------------------------------------
  adresses: [
    {
      id: "addr_001",
      idUtilisateur: "user_001",             // référence vers utilisateur
      NumBatiment: "12",
      Rue: "Rue de Rivoli",
      Quartier: "1er Arrondissement",
      Ville: "Paris",
      CodePostal: "75001",
      Pays: "France",
    },
  ],

  // ----------------------------------------------------------
  // CLIENT  (sous-document ou collection séparée)
  // ----------------------------------------------------------
  clients: [
    {
      id: "client_001",
      idUtilisateur: "user_001",
      etatCompte: "ACTIVE",                 // ACTIVE | DESACTIVE | SUSPENDUE
    },
  ],

  // ----------------------------------------------------------
  // EXPERT
  // ----------------------------------------------------------
  experts: [
    {
      id: "expert_001",
      idUtilisateur: "user_002",
      etatCompte: "ACTIVE",                 // ACTIVE | DESACTIVE | SUSPENDUE
      Experience: "Plomberie industrielle",
      rayonTravaille: 25,                   // km
      CasierJudiciaire: false,
      CarteNationale: "https://storage.example.com/docs/carte_bob.pdf",
    },
  ],

  // ----------------------------------------------------------
  // ADMIN
  // ----------------------------------------------------------
  admins: [
    {
      id: "admin_001",
      idUtilisateur: "user_admin_001",
    },
  ],

  // ----------------------------------------------------------
  // ABONNEMENT
  // ----------------------------------------------------------
  abonnements: [
    {
      id: "abon_001",
      idExpert: "expert_001",
      statut: "ACTIVE",                     // ACTIVE | EXPIRE | DESACTIVE
      dateDebut: admin.firestore.Timestamp.fromDate(new Date("2024-01-01")),
      dateFin: admin.firestore.Timestamp.fromDate(new Date("2025-01-01")),
      montant: 29.99,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // CARTE BANCAIRE
  // ----------------------------------------------------------
  cartesBancaires: [
    {
      id: "carte_001",
      idExpert: "expert_001",
      CardNumber: "**** **** **** 4242",    // toujours masqué
      CVV: "***",
      ExpirationDate: "12/26",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // SERVICE
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
  ],

  // ----------------------------------------------------------
  // SERVICE_EXPERT  (table d'association expert ↔ service)
  // ----------------------------------------------------------
  serviceExperts: [
    {
      id: "se_001",
      idExpert: "expert_001",
      idService: "service_001",
      anneeExperience: 8,
      estCertifie: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // TACHE
  // ----------------------------------------------------------
  taches: [
    {
      id: "tache_001",
      idService: "service_001",
      idExpert: "expert_001",
      nom: "Réparer une fuite",
      description: "Réparer une fuite d'eau sous l'évier",
      estActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // TACHE_EXPERT  (tâches proposées par un expert)
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
  ],

  // ----------------------------------------------------------
  // IMAGE EXEMPLAIRE  (images illustrant une tâche/service)
  // ----------------------------------------------------------
  imagesExemplaires: [
    {
      id: "img_001",
      idTacheExpert: "te_001",
      URLimage: "https://storage.example.com/exemples/fuite.jpg",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // INTERVENTION
  // ----------------------------------------------------------
  interventions: [
    {
      id: "interv_001",
      idClient: "client_001",
      idExpert: "expert_001",
      idTacheExpert: "te_001",
      idAdresse: "addr_001",
      statut: "EN_ATTENTE",                 // EN_ATTENTE | ACCEPTEE | REFUSEE | TERMINEE | ANNULEE
      isUrgent: false,
      prixNegocie: 80.00,
      codeValidationExpert: "VAL-4592",
      dateDebutIntervention: admin.firestore.Timestamp.fromDate(new Date("2024-06-10T09:00:00")),
      dateFinIntervention: admin.firestore.Timestamp.fromDate(new Date("2024-06-10T11:00:00")),

      // SNAPSHOT client (évite une requête)
      clientSnapshot: {
        nom: "Alice Martin",
        photo: "https://storage.../alice.jpg",
        telephone: "+33612345678",
      },

      // SNAPSHOT expert (évite une requête)
      expertSnapshot: {
        nom: "Bob Expert",
        photo: "https://storage.../bob.jpg",
        telephone: "+33698765432",
        note_moyenne: 4.7,
      },

      // SNAPSHOT tâche (évite une requête)
      tacheSnapshot: {
        nom: "Réparer une fuite",
        serviceNom: "Plomberie",
      },

      // SNAPSHOT adresse (évite une requête)
      adresseSnapshot: {
        Rue: "Rue de Rivoli",
        Ville: "Paris",
        CodePostal: "75001",
      },

      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // EVALUATION
  // ----------------------------------------------------------
  evaluations: [
    {
      id: "eval_001",
      idIntervention: "interv_001",
      idClient: "client_001",
      idExpert: "expert_001",
      note: 4.5,
      commentaire: "Très bon travail, rapide et propre.",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // RECLAMATION
  // ----------------------------------------------------------
  reclamations: [
    {
      id: "recl_001",
      idIntervention: "interv_001",
      idClient: "client_001",
      idExpert: "expert_001",
      idAdmin: "user_admin_001",
      description: "Le problème n'a pas été résolu complètement.",
      etatReclamation: "EN_ATTENTE",        // TRAITEE | EN_ATTENTE
      typeReclamateur: "CLIENT",            // CLIENT | EXPERT
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // CHAT
  // ----------------------------------------------------------
  chats: [
    {
      id: "chat_001",
      idIntervention: "interv_001",
      idClient: "client_001",
      idExpert: "expert_001",
      estOuvert: true,
      DateFin: null,
      nbMessagesNonLus: 1,   //badge de notification

      // preview sans requête supplémentaire
      dernierMessage: {
        contenu: "Bonjour, pouvez-vous intervenir demain matin ?",
        senderId: "user_001",
        type: "TEXT",
        createdAt: null,
      },

      // Snapshots pour afficher les noms dans la liste
      clientSnapshot: { nom: "Alice Martin", photo: "https://storage.example.com/profiles/alice.jpg" },
      expertSnapshot: { nom: "Bob Expert", photo: "https://storage.example.com/profiles/bob.jpg" },

      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // MESSAGE
  // ----------------------------------------------------------
  messages: [
    {
      id: "msg_001",
      idChat: "chat_001",
      SenderId: "user_001",
      contenu: "Bonjour, pouvez-vous intervenir demain matin ?",
      type: "TEXT",                         // TEXT | IMAGE | VIDEO
      statut: "LU",                         // EN_ATTENTE | LU
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  ],

  // ----------------------------------------------------------
  // NOTIFICATION
  // ----------------------------------------------------------
  notifications: [
    {
      id: "notif_001",
      idUtilisateur: "user_001",
      titre: "Intervention confirmée",
      message: "Votre intervention du 10 juin est confirmée.",
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
  const MAX_BATCH = 499; // Firestore limite à 500 opérations par batch

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

  // Commit tous les batches
  for (let i = 0; i < batches.length; i++) {
    await batches[i].commit();
    console.log(`✅ Batch ${i + 1}/${batches.length} commité`);
  }

  console.log("\n🎉 Toutes les collections ont été créées avec succès !");
}

seedFirestore().catch((err) => {
  console.error("❌ Erreur lors du seed :", err);
  process.exit(1);
});
