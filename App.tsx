import { LinearGradient } from 'expo-linear-gradient';
import React, { useEffect, useState } from 'react';
import { StatusBar } from 'expo-status-bar';
import { StyleSheet } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';

import { GameOverScreen } from './src/screens/GameOverScreen';
import { GameScreen } from './src/screens/GameScreen';
import { HomeScreen } from './src/screens/HomeScreen';
import { loadHighScore, saveHighScore } from './src/game/highScore';
import { Species } from './src/game/types';
import { colors } from './src/theme/colors';

type Screen = { name: 'home' } | { name: 'playing'; species: Species } | { name: 'gameover'; species: Species; score: number };

export default function App() {
  const [screen, setScreen] = useState<Screen>({ name: 'home' });
  const [highScore, setHighScore] = useState(0);
  const [isNewHighScore, setIsNewHighScore] = useState(false);

  useEffect(() => {
    loadHighScore().then(setHighScore);
  }, []);

  const handleGameOver = async (species: Species, score: number) => {
    const isNew = score > highScore;
    if (isNew) {
      setHighScore(score);
      await saveHighScore(score);
    }
    setIsNewHighScore(isNew);
    setScreen({ name: 'gameover', species, score });
  };

  return (
    <SafeAreaProvider>
      <StatusBar style="light" />
      <LinearGradient colors={[colors.bgTop, colors.bgBottom]} style={styles.fill}>
        <SafeAreaView style={styles.fill}>
          {screen.name === 'home' && (
            <HomeScreen highScore={highScore} onStart={(species) => setScreen({ name: 'playing', species })} />
          )}
          {screen.name === 'playing' && (
            <GameScreen
              species={screen.species}
              onGameOver={(score) => handleGameOver(screen.species, score)}
              onQuit={() => setScreen({ name: 'home' })}
            />
          )}
          {screen.name === 'gameover' && (
            <GameOverScreen
              score={screen.score}
              highScore={highScore}
              isNewHighScore={isNewHighScore}
              onRetry={() => setScreen({ name: 'playing', species: screen.species })}
              onHome={() => setScreen({ name: 'home' })}
            />
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
