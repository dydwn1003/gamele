import React, { useEffect, useRef, useState } from 'react';
import { LayoutChangeEvent, PanResponder, StyleSheet, Text, View } from 'react-native';

import { PixelGrid } from '../pixel/PixelGrid';
import { ITEM_SPRITE, SPECIES_SPRITE } from '../pixel/spriteMaps';
import { colors } from '../theme/colors';
import { createInitialState, setPlayerTarget, stepGame } from '../game/engine';
import { useGameLoop } from '../game/useGameLoop';
import { GameState, Species } from '../game/types';

interface Props {
  species: Species;
  onGameOver: (score: number) => void;
  onQuit: () => void;
}

export function GameScreen({ species, onGameOver, onQuit }: Props) {
  const [area, setArea] = useState<{ width: number; height: number } | null>(null);
  const [state, setState] = useState<GameState | null>(null);
  const targetXRef = useRef(0);

  const handleLayout = (event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    if (!area) {
      setArea({ width, height });
      targetXRef.current = width / 2;
      setState(createInitialState(species, width, height));
    }
  };

  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderGrant: (evt) => {
        targetXRef.current = evt.nativeEvent.locationX;
      },
      onPanResponderMove: (evt) => {
        targetXRef.current = evt.nativeEvent.locationX;
      },
    }),
  ).current;

  useGameLoop(
    (dt) => {
      setState((prev) => {
        if (!prev || prev.status !== 'playing') return prev;
        const withTarget = setPlayerTarget(prev, targetXRef.current);
        return stepGame(withTarget, dt);
      });
    },
    Boolean(state && state.status === 'playing'),
  );

  useEffect(() => {
    if (state?.status === 'gameover') {
      onGameOver(state.score);
    }
  }, [state?.status]);

  return (
    <View style={styles.container}>
      <View style={styles.hud}>
        <Text style={styles.hudText}>점수 {state?.score ?? 0}</Text>
        <Text style={styles.hudHearts}>{'❤️'.repeat(state?.lives ?? 0)}</Text>
        <Text style={styles.quitButton} onPress={onQuit}>
          나가기
        </Text>
      </View>

      <View style={styles.field} onLayout={handleLayout} {...panResponder.panHandlers}>
        {state &&
          state.items.map((item) => (
            <View
              key={item.id}
              style={{
                position: 'absolute',
                left: item.x - item.size / 2,
                top: item.y,
              }}
            >
              <PixelGrid sprite={ITEM_SPRITE[item.kind]} pixelSize={item.size / 9} />
            </View>
          ))}

        {state && (
          <View
            style={{
              position: 'absolute',
              left: state.playerX - state.playerSize / 2,
              top: state.areaHeight - 24 - state.playerSize,
            }}
          >
            <PixelGrid sprite={SPECIES_SPRITE[species]} pixelSize={state.playerSize / 13} />
          </View>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  hud: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    paddingVertical: 12,
  },
  hudText: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '800',
  },
  hudHearts: {
    fontSize: 16,
  },
  quitButton: {
    color: colors.textDim,
    fontSize: 14,
    fontWeight: '600',
  },
  field: {
    flex: 1,
    marginHorizontal: 12,
    marginBottom: 12,
    borderRadius: 20,
    backgroundColor: colors.panel,
    overflow: 'hidden',
  },
});
