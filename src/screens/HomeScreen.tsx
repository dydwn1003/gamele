import { useEffect } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { CurrencyBar } from '../components/CurrencyBar';
import { ProgressBar } from '../components/ProgressBar';
import { expToNextLevel } from '../game/hero';
import { getStage } from '../game/stages';
import { showRewardedAd } from '../services/ads';
import { GEM_PACKS, purchaseGemPack } from '../services/iap';
import { useAuthStore } from '../state/useAuthStore';
import { useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

export function HomeScreen() {
  const user = useAuthStore((s) => s.user);
  const {
    gold,
    gems,
    heroLevel,
    heroExp,
    currentStage,
    highestStageCleared,
    pendingOfflineGold,
    syncOfflineProgress,
    claimOfflineGold,
    addGems,
    heroPower,
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

      <View style={styles.card}>
        <Text style={styles.cardTitle}>영웅</Text>
        <Text style={styles.heroLevel}>Lv.{heroLevel}</Text>
        <ProgressBar progress={heroExp / needed} color={colors.success} />
        <Text style={styles.subText}>
          {heroExp} / {needed} EXP · 전투력 {heroPower().toLocaleString()}
        </Text>
      </View>

      <View style={styles.card}>
        <Text style={styles.cardTitle}>진행 상황</Text>
        <Text style={styles.stageName}>{stage.name} · {stage.enemyName}</Text>
        <Text style={styles.subText}>최고 기록: {highestStageCleared} 스테이지</Text>
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
  cardTitle: { color: colors.textMuted, fontSize: 12, fontWeight: '700', letterSpacing: 1 },
  heroLevel: { color: colors.text, fontSize: 24, fontWeight: '800' },
  subText: { color: colors.textMuted, fontSize: 12 },
  stageName: { color: colors.text, fontSize: 18, fontWeight: '700' },
  shopButton: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 10,
    padding: 12,
    marginTop: 6,
  },
  shopButtonText: { color: colors.text, fontWeight: '600' },
});
