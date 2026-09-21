import Constants from 'expo-constants';
import { initializeApp, getApps, FirebaseOptions } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = (Constants.expoConfig?.extra?.firebase ?? {}) as FirebaseOptions;

export const isFirebaseConfigured = firebaseConfig.apiKey !== 'REPLACE_ME' && !!firebaseConfig.apiKey;

const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
