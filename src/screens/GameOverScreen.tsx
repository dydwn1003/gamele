import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { colors } from '../theme/colors';

interface Props {
  score: number;
  highScore: number;
  isNewHighScore: boolean;
  onRetry: () => void;
  onHome: () => void;
}

export function GameOverScreen({ score, highScore, isNewHighScore, onRetry, onHome }: Props) {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>게임 종료</Text>
      {isNewHighScore && <Text style={styles.newRecord}>🎉 신기록 달성!</Text>}
      <Text style={styles.score}>{score}점</Text>
      <Text style={styles.highScore}>최고 점수: {highScore}</Text>

      <Pressable style={styles.primaryButton} onPress={onRetry}>
        <Text style={styles.primaryButtonText}>다시 하기</Text>
      </Pressable>
      <Pressable style={styles.secondaryButton} onPress={onHome}>
        <Text style={styles.secondaryButtonText}>홈으로</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
    gap: 8,
  },
  title: {
    fontSize: 28,
    fontWeight: '800',
    color: colors.text,
    marginBottom: 4,
  },
  newRecord: {
    color: colors.accent,
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 8,
  },
  score: {
    fontSize: 48,
    fontWeight: '900',
    color: colors.accent,
  },
  highScore: {
    color: colors.textDim,
    fontSize: 14,
    marginBottom: 24,
  },
  primaryButton: {
    backgroundColor: colors.accent,
    paddingHorizontal: 40,
    paddingVertical: 14,
    borderRadius: 999,
    marginBottom: 12,
  },
  primaryButtonText: {
    fontSize: 18,
    fontWeight: '800',
    color: '#3a2a1d',
  },
  secondaryButton: {
    paddingHorizontal: 40,
    paddingVertical: 10,
  },
  secondaryButtonText: {
    fontSize: 15,
    fontWeight: '600',
    color: colors.textDim,
  },
});
