const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function fixDuplicate() {
  try {
    const docRef = db.collection('config').doc('waste_collection_schedule');
    const docSnap = await docRef.get();
    if (!docSnap.exists) return;
    
    const data = docSnap.data();
    let updated = false;
    
    if (data.provinces && data.provinces.Western && data.provinces.Western.Colombo) {
      const colombo = data.provinces.Western.Colombo;
      if (colombo['Maharagama'] && colombo['Maharagama MC']) {
        console.log("Found both Maharagama and Maharagama MC. Merging and cleaning up...");
        if (colombo['Maharagama'].entries && colombo['Maharagama'].entries.length > 0) {
          colombo['Maharagama MC'].entries = colombo['Maharagama'].entries;
        }
        delete colombo['Maharagama'];
        updated = true;
      }
    }
    
    // Also check hierarchy if used
    if (data.hierarchy && data.hierarchy.Western && data.hierarchy.Western.Colombo) {
      const colombo = data.hierarchy.Western.Colombo;
      if (colombo['Maharagama'] && colombo['Maharagama MC']) {
        console.log("Found both Maharagama and Maharagama MC. Merging and cleaning up...");
        if (colombo['Maharagama'].entries && colombo['Maharagama'].entries.length > 0) {
          colombo['Maharagama MC'].entries = colombo['Maharagama'].entries;
        }
        delete colombo['Maharagama'];
        updated = true;
      }
    }
    
    if (updated) {
      await docRef.set(data);
      console.log("Cleanup successful!");
    } else {
      console.log("No duplicate needed fixing.");
    }
  } catch (e) {
    console.error(e);
  }
}
fixDuplicate();
