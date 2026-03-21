/**
 * ============================================================
 *  FIRESTORE — Ajout CGU Expert uniquement
 *  Presto Marketplace
 *
 *  USAGE :
 *    node firestore_add_cgu_expert.js
 * ============================================================
 */

const admin = require("firebase-admin");
const serviceAccount = require("./services-app-70555-firebase-adminsdk-fbsvc-6e97cfe8e0.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function addCGUExpert() {

  const cguExpert = db.collection("cgu").doc("cgu_expert_001");

  await cguExpert.set({
    type: "EXPERT",
    version: "1.0",
    content: `Article 1 — Purpose and Platform Overview
Presto is an online marketplace connecting Experts with individuals seeking qualified local services. As an Expert on Presto, you act as an independent service provider. The platform acts solely as an intermediary and cannot be held responsible for the execution of services you provide to clients.

Article 2 — Registration and Account Creation
As an Expert, you must create an account by providing accurate, complete and up-to-date information. You are required to provide valid documents justifying your professional skills and qualifications. Any false declaration will result in the immediate and permanent deletion of your Expert account without prior notice.

Article 3 — Conduct and Communication
As an Expert, you are required to maintain a professional, courteous and respectful attitude towards all clients at all times. Any disrespectful, discriminatory or inappropriate language directed at clients is strictly prohibited and will result in immediate sanctions. Your quality of client relationship is a key evaluation criterion that directly affects your visibility on Presto.

Article 4 — Commitment to Interventions and Schedules
As an Expert, you are strictly required to adhere to the dates, times and conditions of every intervention agreed upon with the client. In the event of an unavoidable conflict, you must notify both the client and the Presto platform as soon as possible with a valid justification. Unjustified or repeated cancellations on your part will negatively impact your Expert profile score and reduce your visibility on the platform.

Article 5 — Rating System and Reputation
Upon completion of each intervention, the client will rate your service through the platform's rating system. These reviews are public and directly contribute to your Expert reputation on Presto. As an Expert, you are strictly prohibited from manipulating reviews or pressuring clients into providing favorable ratings. Any such behavior will result in immediate suspension of your Expert account.

Article 6 — Premium Subscription
Under the Premium offer, you as an Expert benefit from exclusive advantages such as profile highlighting, priority access to service requests, and advanced management tools. In return, as a Premium Expert you agree to:
- Pay your subscription fees by the agreed due dates
- Maintain a valid and up-to-date payment method at all times
- Report any changes related to your payment situation to Presto promptly
Any delay or failure on your part to pay will result in the immediate suspension of your Premium Expert benefits until full regularization of your account.

Article 7 — Sanctions and Account Deactivation
Presto's administration reserves the right to take any disciplinary action deemed necessary against your Expert account in the event of a breach of these Terms, depending on the level of severity:
- Warning: for any first minor breach on your part
- Temporary suspension: in case of repeated offenses or serious misconduct
- Permanent deactivation: in case of serious violations, repeated abusive cancellations, fraudulent behavior, or damage to Presto's reputation
You will be notified of any deactivation decision made regarding your Expert account.

Article 8 — Personal Data Protection and Privacy
Presto is committed to protecting your personal data as an Expert in accordance with applicable regulations. The data collected from your Expert account is used exclusively for the proper functioning of the platform and is never shared with third parties without your prior consent. As an Expert, you can update your personal information directly from your profile settings within the app. For any additional requests regarding your data, including deletion or further inquiries, please contact our support team at: admin@example.com.`,
    is_active: true,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log("✅ CGU Expert v1.0 ajoutée avec succès !");
  console.log("📄 Document : cgu/cgu_expert_001");
  console.log("🎉 Terminé !");
}

addCGUExpert().catch((err) => {
  console.error("❌ Erreur :", err);
  process.exit(1);
});
