import React, { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { PixelGrid } from '../pixel/PixelGrid';
import { SPECIES_SPRITE } from '../pixel/spriteMaps';
import { colors } from '../theme/colors';
import { SPECIES_LABEL, Species } from '../game/types';

const SPECIES_LIST: Species[] = ['cat', 'dog', 'hamster'];

interface Props {
  highScore: number;
  onStart: (species: Species) => void;
}

export function HomeScreen({ highScore, onStart }: Props) {
  const [selected, setSelected] = useState<Species>('cat');

  return (
    <View style={styles.container}>
      <Text style={styles.title}>도트 펫 캐치</Text>
      <Text style={styles.subtitle}>좋아하는 간식을 떨어뜨려 받아주세요!</Text>

      <View style={styles.cardRow}>
        {SPECIES_LIST.map((species) => {
          const isSelected = species === selected;
          return (
            <Pressable
              key={species}
              onPress={() => setSelected(species)}
              style={[styles.card, isSelected && styles.cardSelected]}
            >
              <PixelGrid sprite={SPECIES_SPRITE[species]} pixelSize={5} />
              <Text style={[styles.cardLabel, isSelected && styles.cardLabelSelected]}>
                {SPECIES_LABEL[species]}
              </Text>
            </Pressable>
          );
        })}
      </View>

      <Pressable style={styles.startButton} onPress={() => onStart(selected)}>
        <Text style={styles.startButtonText}>게임 시작</Text>
      </Pressable>

      <Text style={styles.highScore}>최고 점수: {highScore}</Text>
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
    marginBottom: 32,
    textAlign: 'center',
  },
  cardRow: {
    flexDirection: 'row',
    gap: 12,
    marginBottom: 32,
  },
  card: {
    width: 96,
    height: 120,
    borderRadius: 16,
    backgroundColor: colors.panel,
    borderWidth: 2,
    borderColor: 'transparent',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  cardSelected: {
    borderColor: colors.accent,
  },
  cardLabel: {
    color: colors.textDim,
    fontSize: 14,
    fontWeight: '600',
  },
  cardLabelSelected: {
    color: colors.accent,
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
  highScore: {
    marginTop: 20,
    color: colors.textDim,
    fontSize: 14,
  },
});
