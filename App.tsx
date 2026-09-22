import { LinearGradient } from 'expo-linear-gradient';
import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { StyleSheet } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';

import { FieldScreen } from './src/screens/FieldScreen';
import { HomeScreen } from './src/screens/HomeScreen';
import { CatSave, loadCatSave } from './src/game/save';
import { colors } from './src/theme/colors';

type Screen = 'home' | 'field';

export default function App() {
  const [screen, setScreen] = useState<Screen>('home');
  const [save, setSave] = useState<CatSave | null>(null);

  useEffect(() => {
    if (screen === 'home') {
      loadCatSave().then(setSave);
    }
  }, [screen]);

  return (
    <SafeAreaProvider>
      <StatusBar style="light" />
      <LinearGradient colors={[colors.bgTop, colors.bgBottom]} style={styles.fill}>
        <SafeAreaView style={styles.fill}>
          {screen === 'home' && <HomeScreen bondLevel={save?.bondLevel ?? 0} onStart={() => setScreen('field')} />}
          {screen === 'field' && save && (
            <FieldScreen initialSave={save} onExit={() => setScreen('home')} />
          )}
        </SafeAreaView>
      </LinearGradient>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  fill: {
    flex: 1,
  },
});
