import { create } from 'zustand';
import { onAuthStateChanged, signOut, User } from 'firebase/auth';

import { auth } from '../services/firebase';

interface AuthState {
  user: User | null;
  initializing: boolean;
  signOutUser: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  initializing: true,
  signOutUser: async () => {
    await signOut(auth);
  },
}));

onAuthStateChanged(auth, (user) => {
  useAuthStore.setState({ user, initializing: false });
});
