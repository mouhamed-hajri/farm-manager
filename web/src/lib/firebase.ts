import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore, collection, doc } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyB13P8kU7nB5tPALwZ_NeSbF13kFuWaMQE',
  authDomain: 'farm-manager-free.firebaseapp.com',
  projectId: 'farm-manager-free',
  storageBucket: 'farm-manager-free.firebasestorage.app',
  messagingSenderId: '75905104639',
  appId: '1:75905104639:web:14230fcf705838a1072aca',
};

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

// Shorthand: users/{uid}/{name}
export const userColl = (uid: string, name: string) =>
  collection(db, 'users', uid, name);

export const userDoc = (uid: string) => doc(db, 'users', uid);
