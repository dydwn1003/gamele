import React, { useEffect, useRef, useState } from 'react';
import { LayoutChangeEvent, Pressable, StyleSheet, Text, View } from 'react-native';

import { Joystick } from '../components/Joystick';
import { PixelGrid } from '../pixel/PixelGrid';
import { BUSH_SPRITE, CAT_WALK_1, CAT_WALK_2, FISH_SPRITE, FLOWER_PINK, FLOWER_PURPLE, FLOWER_WHITE } from '../pixel/sprites';
import { CatSave, saveCatSave } from '../game/save';
import { CAT_SPRITE_SIZE, TREAT_SIZE, createInitialFieldState, petCat, stepField } from '../game/fieldEngine';
import { useGameLoop } from '../game/useGameLoop';
import { FieldState, Vec2 } from '../game/types';
import { DECORATIONS, DecorationKind, TERRAIN_PATCHES, WORLD_HEIGHT, WORLD_WIDTH } from '../game/world';
import { colors } from '../theme/colors';

interface Props {
  initialSave: CatSave;
  onExit: () => void;
}

const DECORATION_SPRITE: Record<DecorationKind, typeof BUSH_SPRITE> = {
  'flower-pink': FLOWER_PINK,
  'flower-white': FLOWER_WHITE,
  'flower-purple': FLOWER_PURPLE,
  bush: BUSH_SPRITE,
};

const DECORATION_PIXEL_SIZE: Record<DecorationKind, number> = {
  'flower-pink': 6,
  'flower-white': 6,
  'flower-purple': 6,
  bush: 6,
};

export function FieldScreen({ initialSave, onExit }: Props) {
  const [viewport, setViewport] = useState({ width: 0, height: 0 });
  const [state, setState] = useState<FieldState>(() =>
    createInitialFieldState(initialSave.bondLevel, initialSave.affection, initialSave.fullness),
  );
  const [lastPetAt, setLastPetAt] = useState(0);
  const joystickRef = useRef<Vec2>({ x: 0, y: 0 });
  const stateRef = useRef(state);
  stateRef.current = state;

  const handleLayout = (event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    setViewport({ width, height });
  };

  useGameLoop((dt) => {
    setState((prev) => stepField(prev, dt, joystickRef.current));
  }, true);

  useEffect(() => {
    const interval = setInterval(() => {
      const s = stateRef.current;
      saveCatSave({ bondLevel: s.bondLevel, affection: s.affection, fullness: s.fullness });
    }, 5000);
    return () => {
      clearInterval(interval);
      const s = stateRef.current;
      saveCatSave({ bondLevel: s.bondLevel, affection: s.affection, fullness: s.fullness });
    };
  }, []);

  const handlePet = () => {
    setState((prev) => petCat(prev));
    setLastPetAt(Date.now());
  };

  const handleExit = () => {
    saveCatSave({ bondLevel: state.bondLevel, affection: state.affection, fullness: state.fullness });
    onExit();
  };

  const cameraX = Math.max(0, Math.min(WORLD_WIDTH - viewport.width, state.cat.x - viewport.width / 2));
  const cameraY = Math.max(0, Math.min(WORLD_HEIGHT - viewport.height, state.cat.y - viewport.height / 2));

  const catSprite = state.cat.animFrame === 0 ? CAT_WALK_1 : CAT_WALK_2;
  const catPixelSize = CAT_SPRITE_SIZE / catSprite.rows[0].length;
  const showHeart = Date.now() - lastPetAt < 700;

  return (
    <View style={styles.container}>
      <View style={styles.hud}>
        <View style={styles.statRow}>
          <Text style={styles.statLabel}>포만감</Text>
          <View style={styles.barTrack}>
            <View style={[styles.barFill, { width: `${state.fullness}%`, backgroundColor: '#7ee787' }]} />
          </View>
        </View>
        <View style={styles.statRow}>
          <Text style={styles.statLabel}>애정도</Text>
          <View style={styles.barTrack}>
            <View style={[styles.barFill, { width: `${state.affection}%`, backgroundColor: '#ff9db0' }]} />
          </View>
        </View>
        <Text style={styles.bondText}>친밀도 Lv.{state.bondLevel + 1}</Text>
        <Text style={styles.exitButton} onPress={handleExit}>
          나가기
        </Text>
      </View>

      <View style={styles.field} onLayout={handleLayout}>
        {viewport.width > 0 && (
          <View
            style={{
              position: 'absolute',
              width: WORLD_WIDTH,
              height: WORLD_HEIGHT,
              left: -cameraX,
              top: -cameraY,
              backgroundColor: '#4a9c4a',
            }}
          >
            {TERRAIN_PATCHES.map((patch, i) => (
              <View
                key={i}
                style={{
                  position: 'absolute',
                  left: patch.x - patch.size / 2,
                  top: patch.y - patch.size / 2,
                  width: patch.size,
                  height: patch.size,
                  borderRadius: patch.size / 2,
                  backgroundColor: 'rgba(255,255,255,0.06)',
                }}
              />
            ))}

            {DECORATIONS.map((deco, i) => {
              const sprite = DECORATION_SPRITE[deco.kind];
              const pixelSize = DECORATION_PIXEL_SIZE[deco.kind];
              const w = sprite.rows[0].length * pixelSize;
              const h = sprite.rows.length * pixelSize;
              return (
                <View key={i} style={{ position: 'absolute', left: deco.x - w / 2, top: deco.y - h / 2 }}>
                  <PixelGrid sprite={sprite} pixelSize={pixelSize} />
                </View>
              );
            })}

            {state.treats.map((treat) => (
              <View
                key={treat.id}
                style={{
                  position: 'absolute',
                  left: treat.x - TREAT_SIZE / 2,
                  top: treat.y - TREAT_SIZE / 2,
                }}
              >
                <PixelGrid sprite={FISH_SPRITE} pixelSize={TREAT_SIZE / FISH_SPRITE.rows[0].length} />
              </View>
            ))}

            <Pressable
              onPress={handlePet}
              style={{
                position: 'absolute',
                left: state.cat.x - CAT_SPRITE_SIZE / 2,
                top: state.cat.y - CAT_SPRITE_SIZE / 2,
                width: CAT_SPRITE_SIZE,
                height: CAT_SPRITE_SIZE,
                alignItems: 'center',
                justifyContent: 'center',
              }}
            >
              <View style={{ transform: [{ scaleX: state.cat.facing === 'left' ? -1 : 1 }] }}>
                <PixelGrid sprite={catSprite} pixelSize={catPixelSize} />
              </View>
              {showHeart && <Text style={styles.heart}>💕</Text>}
            </Pressable>
          </View>
        )}
      </View>

      <View style={styles.joystickWrap}>
        <Joystick onChange={(v) => (joystickRef.current = v)} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  hud: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    gap: 6,
  },
  statRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  statLabel: {
    color: colors.text,
    fontSize: 13,
    fontWeight: '700',
    width: 48,
  },
  barTrack: {
    flex: 1,
    height: 10,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.15)',
    overflow: 'hidden',
  },
  barFill: {
    height: '100%',
    borderRadius: 999,
  },
  bondText: {
    color: colors.accent,
    fontSize: 13,
    fontWeight: '700',
  },
  exitButton: {
    position: 'absolute',
    right: 0,
    top: 0,
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
  heart: {
    position: 'absolute',
    top: -18,
    fontSize: 22,
  },
  joystickWrap: {
    position: 'absolute',
    left: 24,
    bottom: 24,
  },
});
