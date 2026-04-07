const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();
db.collection('config').doc('waste_collection_schedule').get().then(doc => {
  console.log(JSON.stringify(doc.data(), null, 2));
}).catch(console.error);
