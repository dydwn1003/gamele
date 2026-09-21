import { useEffect } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { CurrencyBar } from '../components/CurrencyBar';
import { ProgressBar } from '../components/ProgressBar';
import { HeroSprite } from '../components/sprites/HeroSprite';
import { MonsterSprite } from '../components/sprites/MonsterSprite';
import { CLASS_NAME, expToNextLevel } from '../game/hero';
import { getStage } from '../game/stages';
import { PrimaryStats } from '../game/types';
import { showRewardedAd } from '../services/ads';
import { GEM_PACKS, purchaseGemPack } from '../services/iap';
import { useAuthStore } from '../state/useAuthStore';
import { RESPEC_GOLD_COST, useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

const STAT_LABEL: Record<keyof PrimaryStats, string> = {
  str: '힘',
  agi: '민첩',
  int: '지능',
  vit: '체력',
};

export function HomeScreen() {
  const user = useAuthStore((s) => s.user);
  const {
    classId,
    gold,
    gems,
    heroLevel,
    heroExp,
    statPoints,
    allocatedStats,
    currentStage,
    highestStageCleared,
    pendingOfflineGold,
    syncOfflineProgress,
    claimOfflineGold,
    addGems,
    heroPower,
    allocateStat,
    autoAllocateStats,
    respecStats,
  } = useGameStore();

  useEffect(() => {
    syncOfflineProgress();
  }, [syncOfflineProgress]);

  const stage = getStage(currentStage);
  const needed = expToNextLevel(heroLevel);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <View style={styles.headerRow}>
        <Text style={styles.greeting}>{user?.displayName ?? '모험가'}님</Text>
        <CurrencyBar gold={gold} gems={gems} />
      </View>

      {pendingOfflineGold > 0 && (
        <View style={styles.offlineBanner}>
          <Text style={styles.offlineText}>
            자리를 비운 동안 {pendingOfflineGold.toLocaleString()} 골드를 벌었어요!
          </Text>
          <TouchableOpacity style={styles.claimButton} onPress={claimOfflineGold}>
            <Text style={styles.claimButtonText}>수령</Text>
          </TouchableOpacity>
        </View>
      )}

      <View style={[styles.card, styles.heroCard]}>
        <HeroSprite classId={classId ?? 'warrior'} size={64} />
        <View style={{ flex: 1 }}>
          <Text style={styles.cardTitle}>{classId ? CLASS_NAME[classId] : '영웅'}</Text>
          <Text style={styles.heroLevel}>Lv.{heroLevel}</Text>
          <ProgressBar progress={heroExp / needed} color={colors.success} />
          <Text style={styles.subText}>
            {heroExp} / {needed} EXP · 전투력 {heroPower().toLocaleString()}
          </Text>
        </View>
      </View>

      <View style={styles.card}>
        <View style={styles.statHeaderRow}>
          <Text style={styles.cardTitle}>스탯 ({statPoints} 포인트 남음)</Text>
          {statPoints > 0 && (
            <TouchableOpacity onPress={autoAllocateStats}>
              <Text style={styles.autoAllocateText}>자동 분배</Text>
            </TouchableOpacity>
          )}
        </View>
        {(Object.keys(allocatedStats) as (keyof PrimaryStats)[]).map((stat) => (
          <View key={stat} style={styles.statRow}>
            <Text style={styles.statLabel}>{STAT_LABEL[stat]}</Text>
            <Text style={styles.statValue}>{Math.round(allocatedStats[stat])}</Text>
            <TouchableOpacity
              style={[styles.statPlusButton, statPoints <= 0 && styles.statPlusButtonDisabled]}
              disabled={statPoints <= 0}
              onPress={() => allocateStat(stat)}
            >
              <Text style={styles.statPlusText}>+</Text>
            </TouchableOpacity>
          </View>
        ))}
        <TouchableOpacity
          style={[styles.respecButton, gold < RESPEC_GOLD_COST && styles.respecButtonDisabled]}
          disabled={gold < RESPEC_GOLD_COST}
          onPress={respecStats}
        >
          <Text style={styles.respecButtonText}>🪙 스탯 초기화 ({RESPEC_GOLD_COST}G)</Text>
        </TouchableOpacity>
      </View>

      <View style={[styles.card, styles.heroCard]}>
        <MonsterSprite
          stageId={stage.id}
          isMiniBoss={stage.enemyName.includes('보스')}
          size={64}
        />
        <View style={{ flex: 1 }}>
          <Text style={styles.cardTitle}>진행 상황</Text>
          <Text style={styles.stageName}>{stage.name} · {stage.enemyName}</Text>
          <Text style={styles.subText}>최고 기록: {highestStageCleared} 스테이지</Text>
        </View>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>상점</Text>
        <TouchableOpacity
          style={styles.shopButton}
          onPress={async () => {
            const result = await showRewardedAd();
            if (result.rewarded) addGems(20);
          }}
        >
          <Text style={styles.shopButtonText}>📺 광고 보고 젬 20개 받기</Text>
        </TouchableOpacity>
        {GEM_PACKS.map((pack) => (
          <TouchableOpacity
            key={pack.id}
            style={styles.shopButton}
            onPress={async () => {
              const result = await purchaseGemPack(pack.id);
              if (result) addGems(result.gems);
            }}
          >
            <Text style={styles.shopButtonText}>
              💎 젬 {pack.gems}개 — {pack.priceLabel}
            </Text>
          </TouchableOpacity>
        ))}
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 16, gap: 14, paddingBottom: 40 },
  headerRow: { gap: 10 },
  greeting: { color: colors.text, fontSize: 20, fontWeight: '700' },
  offlineBanner: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 12,
    padding: 14,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  offlineText: { color: colors.gold, flex: 1, marginRight: 10 },
  claimButton: {
    backgroundColor: colors.primary,
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 8,
  },
  claimButtonText: { color: colors.text, fontWeight: '700' },
  card: { backgroundColor: colors.surface, borderRadius: 16, padding: 16, gap: 8 },
  heroCard: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  cardTitle: { color: colors.textMuted, fontSize: 12, fontWeight: '700', letterSpacing: 1 },
  heroLevel: { color: colors.text, fontSize: 24, fontWeight: '800' },
  subText: { color: colors.textMuted, fontSize: 12 },
  stageName: { color: colors.text, fontSize: 18, fontWeight: '700' },
  statHeaderRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  autoAllocateText: { color: colors.primary, fontSize: 12, fontWeight: '700' },
  statRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  statLabel: { color: colors.text, fontSize: 13, fontWeight: '700', width: 36 },
  statValue: { color: colors.text, fontSize: 14, fontWeight: '800', flex: 1 },
  statPlusButton: {
    width: 28,
    height: 28,
    borderRadius: 8,
    backgroundColor: colors.primary,
    alignItems: 'center',
    justifyContent: 'center',
  },
  statPlusButtonDisabled: { backgroundColor: colors.surfaceAlt },
  statPlusText: { color: colors.text, fontWeight: '800', fontSize: 16, lineHeight: 18 },
  respecButton: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 10,
    padding: 10,
    alignItems: 'center',
    marginTop: 4,
  },
  respecButtonDisabled: { opacity: 0.4 },
  respecButtonText: { color: colors.textMuted, fontSize: 12, fontWeight: '700' },
  shopButton: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 10,
    padding: 12,
    marginTop: 6,
  },
  shopButtonText: { color: colors.text, fontWeight: '600' },
});
