import {
  collection,
  doc,
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  serverTimestamp,
} from 'firebase/firestore';

import { db } from './firebase';

export interface LeaderboardEntry {
  uid: string;
  displayName: string;
  power: number;
  highestStageCleared: number;
}

const LEADERBOARD_COLLECTION = 'leaderboard';

export async function submitScore(entry: LeaderboardEntry): Promise<void> {
  await setDoc(doc(db, LEADERBOARD_COLLECTION, entry.uid), {
    ...entry,
    updatedAt: serverTimestamp(),
  });
}

export async function fetchTopScores(topN = 50): Promise<LeaderboardEntry[]> {
  const q = query(
    collection(db, LEADERBOARD_COLLECTION),
    orderBy('power', 'desc'),
    limit(topN)
  );
  const snapshot = await getDocs(q);
  return snapshot.docs.map((d) => d.data() as LeaderboardEntry);
}
