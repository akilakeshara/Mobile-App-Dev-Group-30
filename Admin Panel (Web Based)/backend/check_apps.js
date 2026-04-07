const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore();

async function check() {
  const snapshot = await db.collection('applications').orderBy('createdAt', 'desc').limit(5).get();
  snapshot.forEach(doc => {
    console.log("App ID:", doc.id);
    const data = doc.data();
    console.log("pradeshiyaSabha:", data.pradeshiyaSabha);
    console.log("divisionalSecretariat:", data.divisionalSecretariat);
    console.log("status:", data.status);
    console.log("fee:", data.fee);
    console.log("paymentAmount:", data.paymentAmount);
    console.log("formData:", data.formData);
    console.log("---");
  });
}

check().catch(console.error);
