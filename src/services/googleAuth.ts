import Constants from 'expo-constants';
import * as Google from 'expo-auth-session/providers/google';
import * as WebBrowser from 'expo-web-browser';
import { GoogleAuthProvider, signInWithCredential } from 'firebase/auth';
import { useEffect } from 'react';

import { auth } from './firebase';

WebBrowser.maybeCompleteAuthSession();

const googleConfig = (Constants.expoConfig?.extra?.googleAuth ?? {}) as {
  expoClientId?: string;
  iosClientId?: string;
  androidClientId?: string;
  webClientId?: string;
};

export function useGoogleSignIn() {
  const [request, response, promptAsync] = Google.useIdTokenAuthRequest({
    clientId: googleConfig.expoClientId,
    iosClientId: googleConfig.iosClientId,
    androidClientId: googleConfig.androidClientId,
    webClientId: googleConfig.webClientId,
  });

  useEffect(() => {
    if (response?.type === 'success' && response.params.id_token) {
      const credential = GoogleAuthProvider.credential(response.params.id_token);
      signInWithCredential(auth, credential).catch((err) => {
        console.warn('Firebase Google sign-in failed', err);
      });
    }
  }, [response]);

  return { request, response, promptAsync };
}
