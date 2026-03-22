/**
 * ============================================================
 *  FIRESTORE — Ajout collection profileViews (par mois)
 *  Presto Marketplace
 *
 *  USAGE :
 *    node firestore_add_profile_views.js
 * ============================================================
 */

const admin = require("firebase-admin");
const serviceAccount = require("./services-app-70555-firebase-adminsdk-fbsvc-6e97cfe8e0.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addProfileViews() {

  const experts = ["expert_001", "expert_002"];
  const batch = db.batch();

  // Générer 6 mois de données de test
  const now = new Date();

  for (const expertId of experts) {
    for (let m = 5; m >= 0; m--) {
      const date = new Date(now.getFullYear(), now.getMonth() - m, 1);
      const month = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
      const docId = `${expertId}_${month}`;

      // Générer dailyCounts aléatoires
      const daysInMonth = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
      const dailyCounts = {};
      let totalCount = 0;

      for (let d = 1; d <= daysInMonth; d++) {
        const views = Math.floor(Math.random() * 15) + 5; // 5 à 20 vues/jour
        dailyCounts[String(d)] = views;
        totalCount += views;
      }

      const ref = db.collection("profileViews").doc(docId);
      batch.set(ref, {
        idExpert: expertId,
        month: month,
        count: totalCount,
        dailyCounts: dailyCounts,
      });

      console.log(`📅 ${docId} → ${totalCount} vues`);
    }
  }

  await batch.commit();
  console.log("\n✅ Collection profileViews créée !");
  console.log("🎉 Terminé !");
}

addProfileViews().catch((err) => {
  console.error("❌ Erreur :", err);
  process.exit(1);
});
