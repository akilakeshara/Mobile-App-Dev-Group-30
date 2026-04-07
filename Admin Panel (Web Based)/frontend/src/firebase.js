import { initializeApp } from "firebase/app";
import { getFirestore } from "firebase/firestore";
import { getAuth } from "firebase/auth";

const firebaseConfig = {
  apiKey: "AIzaSyDe50SY2mD3wnKlFehdVyckhN3_HC3MmJs", 
  authDomain: "govease-keshara.firebaseapp.com",
  projectId: "govease-keshara",
  storageBucket: "govease-keshara.firebasestorage.app",
  messagingSenderId: "712998131650",
  appId: "1:712998131650:android:3b603c0f834ee795dd685b"
};

export const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
