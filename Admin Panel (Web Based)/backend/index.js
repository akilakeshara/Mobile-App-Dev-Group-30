const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const admin = require('firebase-admin');

// Load environment variables
dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin (Assuming you provide service account keys in production)
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount)
// });

app.get('/', (req, res) => {
  res.json({ message: 'GovEase Admin API is running' });
});

// Route to create a new Grama Niladhari Officer securely via backend
app.post('/api/officers/create', async (req, res) => {
  try {
    const { email, password, name, division, pradeshiyaSabha } = req.body;
    
    // Create the user in Firebase Auth
    /*
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: name,
    });

    // Save additional officer details to Firestore
    await admin.firestore().collection('users').doc(userRecord.uid).set({
      name,
      email,
      role: 'officer',
      division,
      pradeshiyaSabha,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    */

    res.status(201).json({ message: 'GN Officer created successfully (Mock)', data: { email, name, division } });
  } catch (error) {
    console.error('Error creating officer:', error);
    res.status(500).json({ error: error.message });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Backend server running on port ${PORT}`);
});
