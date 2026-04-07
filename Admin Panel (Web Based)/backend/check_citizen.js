const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();
db.collection('citizens').limit(1).get().then(snapshot => {
  snapshot.forEach(doc => console.log(doc.id, doc.data()));
}).catch(console.error);
