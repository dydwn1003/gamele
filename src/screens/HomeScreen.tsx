import { useEffect } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { CurrencyBar } from '../components/CurrencyBar';
import { Panel } from '../components/rpg/Panel';
import { RPGButton } from '../components/rpg/RPGButton';
import { RPGStatBar } from '../components/rpg/RPGStatBar';
import { SectionHeader } from '../components/rpg/SectionHeader';
import { HeroSprite } from '../components/sprites/HeroSprite';
import { MonsterSprite } from '../components/sprites/MonsterSprite';
import { classTitle, expToNextLevel } from '../game/hero';
import { getStage } from '../game/stages';
import { CLASS_SKILLS, SKILL_MAX_LEVEL } from '../game/skills';
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
    skillPoints,
    skillLevels,
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
    levelUpSkill,
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
        <Panel>
          <View style={styles.offlineRow}>
            <Text style={styles.offlineText}>
              자리를 비운 동안 {pendingOfflineGold.toLocaleString()} 골드를 벌었어요!
            </Text>
            <RPGButton onPress={claimOfflineGold} style={styles.offlineButton}>
              수령
            </RPGButton>
          </View>
        </Panel>
      )}

      <Panel style={styles.heroCard}>
        <HeroSprite classId={classId ?? 'warrior'} size={64} />
        <View style={{ flex: 1, gap: 4 }}>
          <Text style={styles.className}>{classId ? classTitle(classId, heroLevel) : '영웅'}</Text>
          <Text style={styles.heroLevel}>Lv.{heroLevel}</Text>
          <RPGStatBar progress={heroExp / needed} color={colors.success} label={`${heroExp} / ${needed}`} />
          <Text style={styles.subText}>전투력 {heroPower().toLocaleString()}</Text>
        </View>
      </Panel>

      <Panel>
        <SectionHeader
          title={`스탯 · ${statPoints} 포인트`}
          right={
            statPoints > 0 ? (
              <TouchableOpacity onPress={autoAllocateStats}>
                <Text style={styles.autoAllocateText}>자동분배</Text>
              </TouchableOpacity>
            ) : undefined
          }
        />
        {(Object.keys(allocatedStats) as (keyof PrimaryStats)[]).map((stat) => (
          <View key={stat} style={styles.statRow}>
            <Text style={styles.statLabel}>{STAT_LABEL[stat]}</Text>
            <Text style={styles.statValue}>{Math.round(allocatedStats[stat])}</Text>
            <TouchableOpacity
              style={[styles.plusButton, statPoints <= 0 && styles.plusButtonDisabled]}
              disabled={statPoints <= 0}
              onPress={() => allocateStat(stat)}
            >
              <Text style={styles.plusText}>+</Text>
            </TouchableOpacity>
          </View>
        ))}
        <RPGButton
          variant="neutral"
          disabled={gold < RESPEC_GOLD_COST}
          onPress={respecStats}
          style={{ marginTop: 4 }}
        >
          🪙 스탯 초기화 ({RESPEC_GOLD_COST}G)
        </RPGButton>
      </Panel>

      <Panel>
        <SectionHeader title={`스킬 · ${skillPoints} 포인트`} />
        {CLASS_SKILLS[classId ?? 'warrior'].map((skill) => {
          const level = skillLevels[skill.id] ?? 0;
          const locked = heroLevel < skill.requiredLevel;
          const maxed = level >= SKILL_MAX_LEVEL;
          const canLevelUp = !locked && !maxed && skillPoints > 0;
          return (
            <View key={skill.id} style={styles.skillRow}>
              <Text style={styles.skillIcon}>{skill.icon}</Text>
              <View style={{ flex: 1 }}>
                <Text style={styles.skillName}>{skill.name}</Text>
                <Text style={styles.skillMeta}>
                  {locked ? `Lv.${skill.requiredLevel} 해금` : maxed ? '최대 레벨' : `Lv ${level} / ${SKILL_MAX_LEVEL}`}
                </Text>
              </View>
              <TouchableOpacity
                style={[styles.plusButton, !canLevelUp && styles.plusButtonDisabled]}
                disabled={!canLevelUp}
                onPress={() => levelUpSkill(skill.id)}
              >
                <Text style={styles.plusText}>+</Text>
              </TouchableOpacity>
            </View>
          );
        })}
      </Panel>

      <Panel style={styles.heroCard}>
        <MonsterSprite
          stageId={stage.id}
          isMiniBoss={stage.enemyName.includes('보스')}
          size={64}
        />
        <View style={{ flex: 1 }}>
          <SectionHeader title="진행 상황" />
          <Text style={styles.stageName}>{stage.name} · {stage.enemyName}</Text>
          <Text style={styles.subText}>최고 기록: {highestStageCleared} 스테이지</Text>
        </View>
      </Panel>

      <Panel>
        <SectionHeader title="상점" />
        <RPGButton variant="neutral" onPress={async () => {
          const result = await showRewardedAd();
          if (result.rewarded) addGems(20);
        }}>
          📺 광고 보고 젬 20개 받기
        </RPGButton>
        {GEM_PACKS.map((pack) => (
          <RPGButton
            key={pack.id}
            variant="neutral"
            style={{ marginTop: 6 }}
            onPress={async () => {
              const result = await purchaseGemPack(pack.id);
              if (result) addGems(result.gems);
            }}
          >
            {`💎 젬 ${pack.gems}개 — ${pack.priceLabel}`}
          </RPGButton>
        ))}
      </Panel>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 16, gap: 14, paddingBottom: 40 },
  headerRow: { gap: 10 },
  greeting: { color: colors.text, fontSize: 20, fontWeight: '700' },
  offlineRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  offlineText: { color: colors.gold, flex: 1 },
  offlineButton: { paddingHorizontal: 8 },
  heroCard: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  className: { color: colors.frame.gold, fontSize: 13, fontWeight: '800', letterSpacing: 1 },
  heroLevel: { color: colors.text, fontSize: 22, fontWeight: '800' },
  subText: { color: colors.textMuted, fontSize: 12 },
  stageName: { color: colors.text, fontSize: 17, fontWeight: '700', marginTop: 4 },
  autoAllocateText: { color: colors.gold, fontSize: 12, fontWeight: '700' },
  statRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  statLabel: { color: colors.text, fontSize: 13, fontWeight: '700', width: 36 },
  statValue: { color: colors.text, fontSize: 14, fontWeight: '800', flex: 1 },
  plusButton: {
    width: 28,
    height: 28,
    borderRadius: 8,
    backgroundColor: colors.frame.gold,
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: colors.frame.goldDark,
  },
  plusButtonDisabled: { opacity: 0.35 },
  plusText: { color: '#3a2a0a', fontWeight: '800', fontSize: 16, lineHeight: 18 },
  skillRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 4 },
  skillIcon: { fontSize: 20, width: 26, textAlign: 'center' },
  skillName: { color: colors.text, fontSize: 13, fontWeight: '700' },
  skillMeta: { color: colors.textMuted, fontSize: 11, marginTop: 1 },
});
