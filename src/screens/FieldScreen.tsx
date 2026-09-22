import React, { useEffect, useRef, useState } from 'react';
import { LayoutChangeEvent, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { Joystick } from '../components/Joystick';
import { PixelGrid } from '../pixel/PixelGrid';
import {
  BOW_SPRITE,
  BUSH_SPRITE,
  CAT_WALK_1,
  CAT_WALK_2,
  DOG_IDLE,
  FISH_SPRITE,
  FLOWER_PINK,
  FLOWER_PURPLE,
  FLOWER_WHITE,
  HAMSTER_IDLE,
  POND_SPRITE,
  TREASURE_SPRITE,
  TREE_SPRITE,
} from '../pixel/sprites';
import { CatSave, saveCatSave } from '../game/save';
import {
  CAT_SPRITE_SIZE,
  NPC_SPRITE_SIZE,
  TREASURE_SIZE,
  TREAT_SIZE,
  createInitialFieldState,
  petCat,
  stepField,
} from '../game/fieldEngine';
import { useGameLoop } from '../game/useGameLoop';
import { buildStoryLog } from '../game/story';
import { FieldState, Vec2 } from '../game/types';
import { DECORATIONS, DecorationKind, NPCS, TERRAIN_PATCHES, TREASURES, WORLD_HEIGHT, WORLD_WIDTH, ZONES } from '../game/world';
import { colors } from '../theme/colors';

interface Props {
  initialSave: CatSave;
  onExit: () => void;
}

interface Toast {
  id: number;
  text: string;
}

const DECORATION_SPRITE: Record<DecorationKind, typeof BUSH_SPRITE> = {
  'flower-pink': FLOWER_PINK,
  'flower-white': FLOWER_WHITE,
  'flower-purple': FLOWER_PURPLE,
  bush: BUSH_SPRITE,
  tree: TREE_SPRITE,
  pond: POND_SPRITE,
};

const DECORATION_PIXEL_SIZE: Record<DecorationKind, number> = {
  'flower-pink': 6,
  'flower-white': 6,
  'flower-purple': 6,
  bush: 6,
  tree: 8,
  pond: 8,
};

const NPC_SPRITE = { dog: DOG_IDLE, hamster: HAMSTER_IDLE };

let toastId = 0;

export function FieldScreen({ initialSave, onExit }: Props) {
  const [viewport, setViewport] = useState({ width: 0, height: 0 });
  const [state, setState] = useState<FieldState>(() =>
    createInitialFieldState(
      initialSave.bondLevel,
      initialSave.affection,
      initialSave.fullness,
      initialSave.metNpcIds,
      initialSave.collectedTreasureIds,
    ),
  );
  const [lastPetAt, setLastPetAt] = useState(0);
  const [toasts, setToasts] = useState<Toast[]>([]);
  const [showStory, setShowStory] = useState(false);
  const joystickRef = useRef<Vec2>({ x: 0, y: 0 });
  const stateRef = useRef(state);
  stateRef.current = state;

  const pushToasts = (texts: string[]) => {
    const created = texts.map((text) => ({ id: toastId++, text }));
    setToasts((prev) => [...prev, ...created]);
    created.forEach((toast) => {
      setTimeout(() => {
        setToasts((prev) => prev.filter((t) => t.id !== toast.id));
      }, 3200);
    });
  };

  const handleLayout = (event: LayoutChangeEvent) => {
    const { width, height } = event.nativeEvent.layout;
    setViewport({ width, height });
  };

  useGameLoop((dt) => {
    const next = stepField(stateRef.current, dt, joystickRef.current);
    setState(next);
    if (next.events.length > 0) pushToasts(next.events.map((e) => e.text));
  }, true);

  useEffect(() => {
    const interval = setInterval(() => {
      const s = stateRef.current;
      saveCatSave({
        bondLevel: s.bondLevel,
        affection: s.affection,
        fullness: s.fullness,
        metNpcIds: s.metNpcIds,
        collectedTreasureIds: s.collectedTreasureIds,
      });
    }, 5000);
    return () => {
      clearInterval(interval);
      const s = stateRef.current;
      saveCatSave({
        bondLevel: s.bondLevel,
        affection: s.affection,
        fullness: s.fullness,
        metNpcIds: s.metNpcIds,
        collectedTreasureIds: s.collectedTreasureIds,
      });
    };
  }, []);

  const handlePet = () => {
    const next = petCat(stateRef.current);
    setState(next);
    setLastPetAt(Date.now());
    if (next.events.length > 0) pushToasts(next.events.map((e) => e.text));
  };

  const handleExit = () => {
    saveCatSave({
      bondLevel: state.bondLevel,
      affection: state.affection,
      fullness: state.fullness,
      metNpcIds: state.metNpcIds,
      collectedTreasureIds: state.collectedTreasureIds,
    });
    onExit();
  };

  const cameraX = Math.max(0, Math.min(WORLD_WIDTH - viewport.width, state.cat.x - viewport.width / 2));
  const cameraY = Math.max(0, Math.min(WORLD_HEIGHT - viewport.height, state.cat.y - viewport.height / 2));

  const catSprite = state.cat.animFrame === 0 ? CAT_WALK_1 : CAT_WALK_2;
  const catPixelSize = CAT_SPRITE_SIZE / catSprite.rows[0].length;
  const showHeart = Date.now() - lastPetAt < 700;
  const hasBow = state.collectedTreasureIds.length === TREASURES.length;
  const visibleTreasures = TREASURES.filter((t) => !state.collectedTreasureIds.includes(t.id));

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
        <View style={styles.hudBottomRow}>
          <Text style={styles.bondText}>친밀도 Lv.{state.bondLevel + 1}</Text>
          <Text style={styles.storyButton} onPress={() => setShowStory(true)}>
            📖 이야기
          </Text>
        </View>
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
            }}
          >
            {ZONES.map((zone) => (
              <View
                key={zone.id}
                style={{
                  position: 'absolute',
                  left: zone.x0,
                  top: zone.y0,
                  width: zone.x1 - zone.x0,
                  height: zone.y1 - zone.y0,
                  backgroundColor: zone.bg,
                }}
              />
            ))}

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

            {NPCS.map((npc) => {
              const sprite = NPC_SPRITE[npc.kind];
              const pixelSize = NPC_SPRITE_SIZE / sprite.rows[0].length;
              const w = sprite.rows[0].length * pixelSize;
              const h = sprite.rows.length * pixelSize;
              const met = state.metNpcIds.includes(npc.id);
              return (
                <View key={npc.id} style={{ position: 'absolute', left: npc.x - w / 2, top: npc.y - h / 2 }}>
                  <PixelGrid sprite={sprite} pixelSize={pixelSize} />
                  {!met && <Text style={styles.npcMarker}>❓</Text>}
                </View>
              );
            })}

            {visibleTreasures.map((treasure) => (
              <View
                key={treasure.id}
                style={{
                  position: 'absolute',
                  left: treasure.x - TREASURE_SIZE / 2,
                  top: treasure.y - TREASURE_SIZE / 2,
                }}
              >
                <PixelGrid sprite={TREASURE_SPRITE} pixelSize={TREASURE_SIZE / TREASURE_SPRITE.rows[0].length} />
              </View>
            ))}

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
              {hasBow && (
                <View style={styles.bow}>
                  <PixelGrid sprite={BOW_SPRITE} pixelSize={4} />
                </View>
              )}
              {showHeart && <Text style={styles.heart}>💕</Text>}
            </Pressable>
          </View>
        )}

        <View style={styles.toastLayer} pointerEvents="none">
          {toasts.map((toast) => (
            <View key={toast.id} style={styles.toast}>
              <Text style={styles.toastText}>{toast.text}</Text>
            </View>
          ))}
        </View>
      </View>

      <View style={styles.joystickWrap}>
        <Joystick onChange={(v) => (joystickRef.current = v)} />
      </View>

      {showStory && (
        <View style={styles.storyOverlay}>
          <View style={styles.storyPanel}>
            <Text style={styles.storyTitle}>고양이 마당 이야기</Text>
            <ScrollView style={styles.storyScroll}>
              {buildStoryLog(state.metNpcIds, state.collectedTreasureIds).map((entry, i) => (
                <Text key={i} style={styles.storyEntry}>
                  {i + 1}. {entry}
                </Text>
              ))}
            </ScrollView>
            <Text style={styles.storyClose} onPress={() => setShowStory(false)}>
              닫기
            </Text>
          </View>
        </View>
      )}
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
  hudBottomRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  bondText: {
    color: colors.accent,
    fontSize: 13,
    fontWeight: '700',
  },
  storyButton: {
    color: colors.textDim,
    fontSize: 13,
    fontWeight: '600',
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
  bow: {
    position: 'absolute',
    top: -10,
    left: 6,
  },
  npcMarker: {
    position: 'absolute',
    top: -20,
    alignSelf: 'center',
    fontSize: 16,
  },
  joystickWrap: {
    position: 'absolute',
    left: 24,
    bottom: 24,
  },
  toastLayer: {
    position: 'absolute',
    top: 12,
    left: 12,
    right: 12,
    alignItems: 'center',
    gap: 6,
  },
  toast: {
    backgroundColor: 'rgba(20,14,40,0.85)',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 12,
    maxWidth: '100%',
  },
  toastText: {
    color: colors.text,
    fontSize: 13,
    fontWeight: '600',
    textAlign: 'center',
  },
  storyOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(10,6,24,0.7)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  storyPanel: {
    width: '100%',
    maxWidth: 340,
    maxHeight: '70%',
    backgroundColor: colors.panel,
    borderRadius: 20,
    borderWidth: 2,
    borderColor: colors.panelBorder,
    padding: 20,
  },
  storyTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '800',
    marginBottom: 12,
  },
  storyScroll: {
    marginBottom: 12,
  },
  storyEntry: {
    color: colors.textDim,
    fontSize: 13,
    lineHeight: 20,
    marginBottom: 10,
  },
  storyClose: {
    alignSelf: 'flex-end',
    color: colors.accent,
    fontSize: 14,
    fontWeight: '700',
  },
});
