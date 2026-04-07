const fs = require('fs');

const API_KEY = "AIzaSyDe50SY2mD3wnKlFehdVyckhN3_HC3MmJs";
const PROJECT_ID = "govease-keshara";

const SRI_LANKA_DATA = {
  'Western': {
    'Colombo': ['Colombo', 'Dehiwala', 'Maharagama', 'Nugegoda', 'Homagama', 'Kesbewa', 'Kolonnawa', 'Kaduwela', 'Thimbirigasyaya', 'Ratmalana'],
    'Gampaha': ['Gampaha', 'Negombo', 'Ja-Ela', 'Ragama', 'Attanagalla', 'Minuwangoda', 'Katana', 'Mahara', 'Wattala', 'Dompe'],
    'Kalutara': ['Kalutara', 'Panadura', 'Horana', 'Beruwala', 'Aluthgama', 'Matugama', 'Bandaragama', 'Agalawatta', 'Bulathsinhala']
  },
  'Central': {
    'Kandy': ['Kandy', 'Kundasale', 'Gampola', 'Nawalapitiya', 'Harispattuwa', 'Udunuwara', 'Yatinuwara', 'Pasbage Korale', 'Poojapitiya'],
    'Matale': ['Matale', 'Rattota', 'Ukuwela', 'Yatawatta', 'Ambanganga Korale', 'Naula', 'Pallepola', 'Wilgamuwa'],
    'Nuwara Eliya': ['Nuwara Eliya', 'Kotmale', 'Hanguranketha', 'Walapane', 'Ambagamuwa']
  },
  'Southern': {
    'Galle': ['Galle', 'Hikkaduwa', 'Baddegama', 'Ambalangoda', 'Elpitiya', 'Habaraduwa', 'Imaduwa', 'Akmeemana'],
    'Matara': ['Matara', 'Weligama', 'Dickwella', 'Hakmana', 'Mulatiyana', 'Athuraliya', 'Devinuwara'],
    'Hambantota': ['Hambantota', 'Tangalle', 'Tissamaharama', 'Beliatta', 'Okewela', 'Lunugamvehera']
  },
  'North Western': {
    'Kurunegala': ['Kurunegala', 'Kuliyapitiya', 'Nikaweratiya', 'Maho', 'Wariyapola', 'Galgamuwa', 'Ibbagamuwa', 'Pannala', 'Alawwa', 'Doramadala'],
    'Puttalam': ['Puttalam', 'Chilaw', 'Wennappuwa', 'Nattandiya', 'Dankotuwa', 'Nawagattegama', 'Anamaduwa']
  },
  'Sabaragamuwa': {
    'Ratnapura': ['Ratnapura', 'Embilipitiya', 'Balangoda', 'Pelmadulla', 'Eheliyagoda', 'Kuruvita', 'Kiriella', 'Imbulpe', 'Kalawana'],
    'Kegalle': ['Kegalle', 'Mawanella', 'Rambukkana', 'Aranayaka', 'Warakapola', 'Galigamuwa','Yatiyanthota']
  },
  'North Central': {
    'Anuradhapura': ['Anuradhapura', 'Kekirawa', 'Medawachchiya', 'Mihintale', 'Palagala', 'Horowpothana', 'Eppawala', 'Nochchiyagama'],
    'Polonnaruwa': ['Polonnaruwa', 'Hingurakgoda', 'Medirigiriya', 'Thamankaduwa', 'Welikanda']
  },
  'Uva': {
    'Badulla': ['Badulla', 'Bandarawela', 'Welimada', 'Hali-Ela', 'Ella', 'Mahiyanganaya', 'Passara', 'Soranathota'],
    'Monaragala': ['Monaragala', 'Bibile', 'Buttala', 'Siyambalanduwa', 'Wellawaya', 'Medagama']
  },
  'Northern': {
    'Jaffna': ['Jaffna', 'Nallur', 'Chavakacheri', 'Point Pedro', 'Chavakachcheri', 'Valikamam North'],
    'Kilinochchi': ['Kilinochchi', 'Kandavalai', 'Pachchilaipalli'],
    'Mannar': ['Mannar', 'Musali', 'Madhu'],
    'Vavuniya': ['Vavuniya', 'Vavuniya North', 'Vavuniya South'],
    'Mullaitivu': ['Mullaitivu', 'Maritimepattu', 'Oddusuddan']
  },
  'Eastern': {
    'Trincomalee': ['Trincomalee', 'Kinniya', 'Seruvila', 'Mutur', 'Padavi Sripura'],
    'Batticaloa': ['Batticaloa', 'Eravur Pattu', 'Koralai Pattu', 'Manmunai South'],
    'Ampara': ['Ampara', 'Kalmunai', 'Sammanthurai', 'Pottuvil', 'Akkaraipattu']
  }
};

const sanitizeStr = (str) => {
  return str.toLowerCase().replace(/[^a-z0-9]/g, '');
};

async function createAccount(email, password) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true })
  });
  
  const data = await response.json();
  if (!response.ok) {
    if (data.error && data.error.message === 'EMAIL_EXISTS') {
      console.log(`Email ${email} already exists. Logging in instead...`);
      return loginAccount(email, password);
    }
    throw new Error(data.error ? data.error.message : 'Unknown auth error');
  }
  return data; // contains localId (uid) and idToken
}

async function loginAccount(email, password) {
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true })
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error ? data.error.message : 'Unknown auth error during login');
  }
  return data;
}

async function createFirestoreDoc(uid, idToken, name, email, province, district, dsDivision) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/ds_admins?documentId=${uid}`;
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${idToken}`
    },
    body: JSON.stringify({
      fields: {
        name: { stringValue: name },
        email: { stringValue: email },
        role: { stringValue: 'admin' },
        province: { stringValue: province },
        district: { stringValue: district },
        dsDivision: { stringValue: dsDivision },
        createdAt: { timestampValue: new Date().toISOString() }
      }
    })
  });
  
  if (!response.ok && response.status !== 409) { // Ignore 409 already exists
     const data = await response.json();
     throw new Error(`Firestore error: ${JSON.stringify(data)}`);
  }
}

async function main() {
  let report = "GovEase DS Admin Credentials\n================================\n\n";
  let count = 0;

  for (const province in SRI_LANKA_DATA) {
    for (const district in SRI_LANKA_DATA[province]) {
      for (const dsDivision of SRI_LANKA_DATA[province][district]) {
        try {
          const sanitizedDiv = sanitizeStr(dsDivision);
          const email = `${sanitizedDiv}.ds@govease.com`;
          const password = `Admin@${sanitizedDiv}123`;
          const name = `${dsDivision} DS Admin`;

          console.log(`Processing ${dsDivision} (${email})...`);
          
          const authData = await createAccount(email, password);
          await createFirestoreDoc(authData.localId, authData.idToken, name, email, province, district, dsDivision);
          
          report += `Location: ${province} > ${district} > ${dsDivision}\n`;
          report += `Name: ${name}\n`;
          report += `Email: ${email}\n`;
          report += `Password: ${password}\n`;
          report += `-------------------------------------------\n`;
          count++;
          
          // Minimal delay to prevent rate limits
          await new Promise(r => setTimeout(r, 200));

        } catch (e) {
          console.error(`Error processing ${dsDivision}: ${e.message}`);
          report += `Failed to process ${dsDivision}: ${e.message}\n-------------------------------------------\n`;
        }
      }
    }
  }

  report = `Generated ${count} DS Admin accounts successfully.\n\n` + report;
  fs.writeFileSync('../../../DS_Admin_Credentials.txt', report);
  console.log('Finished generating DS Admins!');
}

main();
