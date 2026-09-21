import { useEffect, useRef, useState } from 'react';
import { Animated, FlatList, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { HeroSprite } from '../components/sprites/HeroSprite';
import { MonsterSprite } from '../components/sprites/MonsterSprite';
import { getStage } from '../game/stages';
import { useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

const AUTO_FIGHT_INTERVAL_MS = 1200;

interface LogEntry {
  id: number;
  text: string;
  won: boolean;
}

let logIdCounter = 0;

export function BattleScreen() {
  const { currentStage, fightCurrentStage, heroPower } = useGameStore();
  const [autoFight, setAutoFight] = useState(false);
  const [log, setLog] = useState<LogEntry[]>([]);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const heroLunge = useRef(new Animated.Value(0)).current;
  const enemyShake = useRef(new Animated.Value(0)).current;

  const playAttackAnim = (won: boolean) => {
    Animated.sequence([
      Animated.timing(heroLunge, { toValue: 1, duration: 130, useNativeDriver: true }),
      Animated.timing(heroLunge, { toValue: 0, duration: 150, useNativeDriver: true }),
    ]).start();
    Animated.sequence([
      Animated.timing(enemyShake, { toValue: 1, duration: 60, useNativeDriver: true }),
      Animated.timing(enemyShake, { toValue: -1, duration: 60, useNativeDriver: true }),
      Animated.timing(enemyShake, { toValue: won ? 0 : 0.4, duration: 80, useNativeDriver: true }),
    ]).start();
  };

  const runFight = () => {
    const stageBeforeFight = getStage(useGameStore.getState().currentStage);
    const result = fightCurrentStage();
    playAttackAnim(result.won);
    logIdCounter += 1;
    const text = result.won
      ? `${stageBeforeFight.name} 승리! +${result.goldEarned}G +${result.expEarned}EXP`
      : `${stageBeforeFight.name} 패배... +${result.goldEarned}G`;
    setLog((prev) => [{ id: logIdCounter, text, won: result.won }, ...prev].slice(0, 30));
  };

  useEffect(() => {
    if (autoFight) {
      intervalRef.current = setInterval(runFight, AUTO_FIGHT_INTERVAL_MS);
    } else if (intervalRef.current) {
      clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoFight]);

  const stage = getStage(currentStage);
  const isMiniBoss = stage.enemyName.includes('보스');

  return (
    <View style={styles.container}>
      <View style={styles.arena}>
        <View style={styles.arenaBackdrop} />
        <Animated.View
          style={{
            transform: [
              { translateX: heroLunge.interpolate({ inputRange: [0, 1], outputRange: [0, 18] }) },
            ],
          }}
        >
          <HeroSprite size={84} />
        </Animated.View>
        <Text style={styles.vsText}>VS</Text>
        <Animated.View
          style={{
            transform: [
              { translateX: Animated.multiply(enemyShake, 8) },
            ],
          }}
        >
          <MonsterSprite stageId={stage.id} isMiniBoss={isMiniBoss} size={84} />
        </Animated.View>
      </View>

      <View style={styles.infoCard}>
        <Text style={styles.stageLabel}>{stage.name}</Text>
        <Text style={styles.enemyName}>{stage.enemyName}</Text>
        <Text style={styles.subText}>HP {stage.enemyStats.hp.toLocaleString()}</Text>
      </View>

      <View style={styles.vsRow}>
        <Text style={styles.powerText}>내 전투력 {heroPower().toLocaleString()}</Text>
        <Text style={styles.powerText}>
          적 전투력 {Math.round(stage.enemyStats.atk * 3.5 + stage.enemyStats.hp * 0.6)}
        </Text>
      </View>

      <TouchableOpacity style={styles.fightButton} onPress={runFight}>
        <Text style={styles.fightButtonText}>한 번 전투</Text>
      </TouchableOpacity>

      <TouchableOpacity
        style={[styles.autoButton, autoFight && styles.autoButtonActive]}
        onPress={() => setAutoFight((v) => !v)}
      >
        <Text style={styles.autoButtonText}>{autoFight ? '자동전투 끄기' : '자동전투 켜기'}</Text>
      </TouchableOpacity>

      <FlatList
        style={styles.log}
        data={log}
        keyExtractor={(item) => String(item.id)}
        renderItem={({ item }) => (
          <Text style={[styles.logText, { color: item.won ? colors.success : colors.danger }]}>
            {item.text}
          </Text>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, padding: 16, gap: 12 },
  arena: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-evenly',
    backgroundColor: colors.surface,
    borderRadius: 16,
    paddingVertical: 18,
    overflow: 'hidden',
  },
  arenaBackdrop: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 16,
    backgroundColor: colors.surfaceAlt,
  },
  vsText: { color: colors.primary, fontWeight: '800', fontSize: 16 },
  infoCard: { backgroundColor: colors.surface, borderRadius: 16, padding: 16, gap: 6 },
  stageLabel: { color: colors.textMuted, fontSize: 12, fontWeight: '700' },
  enemyName: { color: colors.text, fontSize: 20, fontWeight: '800' },
  subText: { color: colors.textMuted, fontSize: 12 },
  vsRow: { flexDirection: 'row', justifyContent: 'space-between' },
  powerText: { color: colors.text, fontSize: 12 },
  fightButton: {
    backgroundColor: colors.primary,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  fightButtonText: { color: colors.text, fontWeight: '700', fontSize: 16 },
  autoButton: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: 'center',
  },
  autoButtonActive: { backgroundColor: colors.success },
  autoButtonText: { color: colors.text, fontWeight: '700' },
  log: { flex: 1, marginTop: 4 },
  logText: { fontSize: 13, paddingVertical: 3 },
});
