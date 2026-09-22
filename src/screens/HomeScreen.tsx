import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { PixelGrid } from '../pixel/PixelGrid';
import { CAT_IDLE } from '../pixel/sprites';
import { colors } from '../theme/colors';

interface Props {
  bondLevel: number;
  onStart: () => void;
}

export function HomeScreen({ bondLevel, onStart }: Props) {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>고양이 마당</Text>
      <Text style={styles.subtitle}>자유롭게 돌아다니는 고양이를 밥도 주고 쓰다듬으며 키워보세요</Text>

      <View style={styles.catPreview}>
        <PixelGrid sprite={CAT_IDLE} pixelSize={7} />
      </View>

      <Pressable style={styles.startButton} onPress={onStart}>
        <Text style={styles.startButtonText}>마당으로 가기</Text>
      </Pressable>

      <Text style={styles.bondText}>친밀도 Lv.{bondLevel + 1}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 24,
  },
  title: {
    fontSize: 32,
    fontWeight: '800',
    color: colors.text,
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 14,
    color: colors.textDim,
    marginBottom: 24,
    textAlign: 'center',
  },
  catPreview: {
    marginBottom: 32,
  },
  startButton: {
    backgroundColor: colors.accent,
    paddingHorizontal: 40,
    paddingVertical: 14,
    borderRadius: 999,
  },
  startButtonText: {
    fontSize: 18,
    fontWeight: '800',
    color: '#3a2a1d',
  },
  bondText: {
    marginTop: 20,
    color: colors.textDim,
    fontSize: 14,
  },
});
