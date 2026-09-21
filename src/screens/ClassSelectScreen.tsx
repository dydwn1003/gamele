import { ScrollView, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { HeroSprite } from '../components/sprites/HeroSprite';
import { ProgressBar } from '../components/ProgressBar';
import { CLASS_BASE_PRIMARY, CLASS_NAME } from '../game/hero';
import { ClassId, PrimaryStats } from '../game/types';
import { useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

const CLASS_ORDER: ClassId[] = ['warrior', 'rogue', 'archer', 'mage'];

const CLASS_BLURB: Record<ClassId, string> = {
  warrior: '높은 체력과 방어력으로 최전선에서 버티는 근접 전투 특화',
  rogue: '빠른 공격과 높은 치명타로 순식간에 적을 처치하는 암살자',
  archer: '먼 거리에서 안전하게 활을 쏘는 원거리 딜러',
  mage: '강력한 마법으로 넓은 범위에 피해를 주는 지능형 딜러',
};

const STAT_LABEL: Record<keyof PrimaryStats, string> = {
  str: '힘',
  agi: '민첩',
  int: '지능',
  vit: '체력',
};

const MAX_BASE = 16;

export function ClassSelectScreen() {
  const chooseClass = useGameStore((s) => s.chooseClass);

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      <Text style={styles.title}>직업을 선택하세요</Text>
      <Text style={styles.subtitle}>한 번 선택하면 바꿀 수 없어요</Text>

      {CLASS_ORDER.map((classId) => {
        const base = CLASS_BASE_PRIMARY[classId];
        return (
          <View key={classId} style={styles.card}>
            <View style={styles.cardHeader}>
              <HeroSprite classId={classId} size={72} />
              <View style={{ flex: 1 }}>
                <Text style={styles.className}>{CLASS_NAME[classId]}</Text>
                <Text style={styles.blurb}>{CLASS_BLURB[classId]}</Text>
              </View>
            </View>

            <View style={styles.statBlock}>
              {(Object.keys(base) as (keyof PrimaryStats)[]).map((stat) => (
                <View key={stat} style={styles.statRow}>
                  <Text style={styles.statLabel}>{STAT_LABEL[stat]}</Text>
                  <ProgressBar progress={base[stat] / MAX_BASE} color={colors.primary} height={7} />
                </View>
              ))}
            </View>

            <TouchableOpacity style={styles.selectButton} onPress={() => chooseClass(classId)}>
              <Text style={styles.selectButtonText}>{CLASS_NAME[classId]}(으)로 시작하기</Text>
            </TouchableOpacity>
          </View>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  content: { padding: 20, gap: 16, paddingBottom: 40 },
  title: { color: colors.text, fontSize: 24, fontWeight: '800', textAlign: 'center' },
  subtitle: { color: colors.textMuted, fontSize: 12, textAlign: 'center', marginBottom: 8 },
  card: { backgroundColor: colors.surface, borderRadius: 18, padding: 16, gap: 12 },
  cardHeader: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  className: { color: colors.text, fontSize: 18, fontWeight: '800' },
  blurb: { color: colors.textMuted, fontSize: 12, marginTop: 4, lineHeight: 17 },
  statBlock: { gap: 6 },
  statRow: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  statLabel: { color: colors.textMuted, fontSize: 11, width: 32, fontWeight: '700' },
  selectButton: {
    backgroundColor: colors.primary,
    borderRadius: 12,
    paddingVertical: 12,
    alignItems: 'center',
  },
  selectButtonText: { color: colors.text, fontWeight: '700' },
});
