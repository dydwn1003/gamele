import { useEffect, useState } from 'react';
import { FlatList, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { RPGButton } from '../components/rpg/RPGButton';
import { SectionHeader } from '../components/rpg/SectionHeader';
import { BossSprite, BOSS_NAMES } from '../components/sprites/BossSprite';
import { CHAPTER_COUNT, getBoss } from '../game/bosses';
import { chapterForStage } from '../components/sprites/palette';
import { RARITY_LABEL } from '../game/equipment';
import { MAX_BOSS_TICKETS, useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

interface LogEntry {
  id: number;
  text: string;
  won: boolean;
}

let logIdCounter = 0;

export function DungeonScreen() {
  const { highestStageCleared, bossTickets, fightBoss, syncBossTickets, heroPower } =
    useGameStore();
  const [log, setLog] = useState<LogEntry[]>([]);

  useEffect(() => {
    syncBossTickets();
  }, [syncBossTickets]);

  const unlockedChapters = Math.max(1, chapterForStage(highestStageCleared));
  const chapters = Array.from({ length: CHAPTER_COUNT }, (_, i) => i + 1);

  const challenge = (chapter: number) => {
    const result = fightBoss(chapter);
    if (!result) return;
    logIdCounter += 1;
    const text = result.won
      ? `${BOSS_NAMES[chapter]} 처치! +${result.goldEarned}G +${result.gemsEarned}💎` +
        (result.item ? ` [${RARITY_LABEL[result.item.rarity]}] ${result.item.name} 획득` : '')
      : `${BOSS_NAMES[chapter]}에게 패배... +${result.goldEarned}G`;
    setLog((prev) => [{ id: logIdCounter, text, won: result.won }, ...prev].slice(0, 30));
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.title}>레이드 던전</Text>
        <View style={styles.ticketPill}>
          <Text style={styles.ticketText}>
            🎟 {bossTickets} / {MAX_BOSS_TICKETS}
          </Text>
        </View>
      </View>
      <Text style={styles.subText}>전투력 {heroPower().toLocaleString()}</Text>

      <FlatList
        data={chapters}
        keyExtractor={(c) => String(c)}
        contentContainerStyle={{ gap: 10, paddingVertical: 10 }}
        renderItem={({ item: chapter }) => {
          const locked = chapter > unlockedChapters;
          const boss = getBoss(chapter);
          return (
            <View style={[styles.bossCard, locked && styles.bossCardLocked]}>
              <BossSprite chapter={chapter} size={64} />
              <View style={styles.bossInfo}>
                <Text style={styles.bossName}>{BOSS_NAMES[chapter]}</Text>
                <Text style={styles.bossMeta}>
                  {locked
                    ? `${chapter * 10 - 9} 스테이지 클리어 시 해금`
                    : `보상 ${boss.goldReward}G · ${boss.gemReward}💎 · ${RARITY_LABEL[boss.guaranteedRarity]}+ 확정`}
                </Text>
              </View>
              <RPGButton
                disabled={locked || bossTickets <= 0}
                onPress={() => challenge(chapter)}
                style={styles.challengeButton}
              >
                {locked ? '잠김' : '도전'}
              </RPGButton>
            </View>
          );
        }}
      />

      <SectionHeader title="전투 기록" />
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
  container: { flex: 1, backgroundColor: colors.background, padding: 16 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  title: { color: colors.text, fontSize: 22, fontWeight: '800' },
  subText: { color: colors.textMuted, fontSize: 12, marginTop: 2 },
  ticketPill: {
    backgroundColor: colors.frame.wood,
    borderWidth: 1,
    borderColor: colors.frame.goldDark,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
  },
  ticketText: { color: colors.gold, fontWeight: '700' },
  bossCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.frame.wood,
    borderWidth: 1,
    borderColor: colors.frame.goldDark + '80',
    borderRadius: 14,
    padding: 12,
    gap: 12,
  },
  bossCardLocked: { opacity: 0.45 },
  bossInfo: { flex: 1 },
  bossName: { color: colors.text, fontWeight: '800', fontSize: 15 },
  bossMeta: { color: colors.textMuted, fontSize: 11, marginTop: 2 },
  challengeButton: { paddingHorizontal: 8, minWidth: 80 },
  log: { maxHeight: 140, marginTop: 6 },
  logText: { fontSize: 12, paddingVertical: 2 },
});
