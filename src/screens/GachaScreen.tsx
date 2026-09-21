import { useState } from 'react';
import { FlatList, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { CurrencyBar } from '../components/CurrencyBar';
import { EquipmentIcon } from '../components/sprites/EquipmentIcon';
import { GACHA_COST_GEMS, GACHA_COST_GEMS_TEN } from '../game/gacha';
import {
  ENHANCE_MAX_LEVEL,
  RARITY_LABEL,
  SLOT_LABEL_BY_CLASS,
  effectiveItemStats,
  enhanceCost,
} from '../game/equipment';
import { EquipmentItem, EquipmentSlot } from '../game/types';
import { useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

const SLOTS: EquipmentSlot[] = ['weapon', 'armor', 'offhand', 'shoes', 'ring', 'necklace'];

export function GachaScreen() {
  const {
    classId,
    gold,
    gems,
    inventory,
    equipped,
    pullGacha,
    pullGachaTen,
    equipItem,
    unequipItem,
    enhanceItem,
  } = useGameStore();
  const [lastPull, setLastPull] = useState<EquipmentItem[]>([]);

  const slotLabel = SLOT_LABEL_BY_CLASS[classId ?? 'warrior'];

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.title}>장비 뽑기</Text>
        <CurrencyBar gold={gold} gems={gems} />
      </View>

      <View style={styles.pullRow}>
        <TouchableOpacity
          style={[styles.pullButton, gems < GACHA_COST_GEMS && styles.pullButtonDisabled]}
          disabled={gems < GACHA_COST_GEMS}
          onPress={() => {
            const item = pullGacha();
            if (item) setLastPull([item]);
          }}
        >
          <Text style={styles.pullButtonText}>💎 {GACHA_COST_GEMS} 1회 뽑기</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.pullButtonTen, gems < GACHA_COST_GEMS_TEN && styles.pullButtonDisabled]}
          disabled={gems < GACHA_COST_GEMS_TEN}
          onPress={() => {
            const items = pullGachaTen();
            if (items) setLastPull(items);
          }}
        >
          <Text style={styles.pullButtonText}>💎 {GACHA_COST_GEMS_TEN} 10연차</Text>
        </TouchableOpacity>
      </View>

      {lastPull.length > 0 && (
        <View style={styles.resultBar}>
          <FlatList
            horizontal
            data={lastPull}
            keyExtractor={(item, i) => `${item.id}-${i}`}
            showsHorizontalScrollIndicator={false}
            renderItem={({ item }) => (
              <View style={styles.resultItem}>
                <EquipmentIcon slot={item.slot} color={colors.rarity[item.rarity]} size={30} />
                <Text style={[styles.resultLabel, { color: colors.rarity[item.rarity] }]} numberOfLines={1}>
                  {RARITY_LABEL[item.rarity]}
                </Text>
              </View>
            )}
          />
          <TouchableOpacity onPress={() => setLastPull([])}>
            <Text style={styles.resultClose}>닫기</Text>
          </TouchableOpacity>
        </View>
      )}

      <View style={styles.equippedGrid}>
        {SLOTS.map((slot) => {
          const item = equipped[slot];
          return (
            <View key={slot} style={styles.equippedSlot}>
              <EquipmentIcon
                slot={slot}
                color={item ? colors.rarity[item.rarity] : colors.textMuted}
                size={26}
              />
              <Text style={styles.slotLabel}>{slotLabel[slot]}</Text>
              <Text style={styles.slotItem} numberOfLines={1}>
                {item ? `${item.name}${item.enhanceLevel > 0 ? ` +${item.enhanceLevel}` : ''}` : '없음'}
              </Text>
              {item && (
                <TouchableOpacity onPress={() => unequipItem(slot)}>
                  <Text style={styles.unequipText}>해제</Text>
                </TouchableOpacity>
              )}
            </View>
          );
        })}
      </View>

      <Text style={styles.sectionTitle}>보유 장비 ({inventory.length})</Text>
      <FlatList
        data={[...inventory].reverse()}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => {
          const stats = effectiveItemStats(item);
          const cost = enhanceCost(item);
          const maxed = item.enhanceLevel >= ENHANCE_MAX_LEVEL;
          return (
            <View style={styles.itemRow}>
              <EquipmentIcon slot={item.slot} color={colors.rarity[item.rarity]} size={30} />
              <View style={styles.itemInfo}>
                <Text style={[styles.itemName, { color: colors.rarity[item.rarity] }]}>
                  [{RARITY_LABEL[item.rarity]}] {item.name}
                  {item.enhanceLevel > 0 ? ` +${item.enhanceLevel}` : ''}
                </Text>
                <Text style={styles.itemStats}>
                  ATK+{stats.atk.toFixed(1)} HP+{stats.hp.toFixed(1)} DEF+{stats.def.toFixed(1)} 치명+
                  {(stats.critRate * 100).toFixed(1)}%
                </Text>
              </View>
              <View style={styles.itemActions}>
                <TouchableOpacity style={styles.equipButton} onPress={() => equipItem(item)}>
                  <Text style={styles.equipButtonText}>장착</Text>
                </TouchableOpacity>
                <TouchableOpacity
                  style={[styles.enhanceButton, (maxed || gold < cost) && styles.enhanceButtonDisabled]}
                  disabled={maxed || gold < cost}
                  onPress={() => enhanceItem(item.id)}
                >
                  <Text style={styles.enhanceButtonText}>
                    {maxed ? '최대' : `강화 (${cost}G)`}
                  </Text>
                </TouchableOpacity>
              </View>
            </View>
          );
        }}
        ListEmptyComponent={<Text style={styles.emptyText}>아직 뽑은 장비가 없어요</Text>}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, padding: 16, gap: 12 },
  headerRow: { gap: 10 },
  title: { color: colors.text, fontSize: 22, fontWeight: '800' },
  pullRow: { flexDirection: 'row', gap: 8 },
  pullButton: {
    flex: 1,
    backgroundColor: colors.gem,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  pullButtonTen: {
    flex: 1,
    backgroundColor: colors.primary,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  pullButtonDisabled: { opacity: 0.4 },
  pullButtonText: { color: colors.background, fontWeight: '800', fontSize: 13 },
  resultBar: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surfaceAlt,
    borderRadius: 12,
    padding: 8,
    gap: 8,
  },
  resultItem: { alignItems: 'center', width: 46 },
  resultLabel: { fontSize: 9, fontWeight: '800', marginTop: 2 },
  resultClose: { color: colors.textMuted, fontSize: 12, paddingHorizontal: 6 },
  equippedGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  equippedSlot: {
    width: '31%',
    backgroundColor: colors.surface,
    borderRadius: 10,
    padding: 8,
    alignItems: 'center',
    gap: 3,
  },
  slotLabel: { color: colors.textMuted, fontSize: 10, fontWeight: '700' },
  slotItem: { color: colors.text, fontSize: 11, fontWeight: '600' },
  unequipText: { color: colors.danger, fontSize: 10 },
  sectionTitle: { color: colors.textMuted, fontSize: 12, fontWeight: '700', marginTop: 4 },
  itemRow: {
    flexDirection: 'row',
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
    alignItems: 'center',
    gap: 10,
  },
  itemInfo: { flex: 1 },
  itemName: { fontWeight: '700', fontSize: 13 },
  itemStats: { color: colors.textMuted, fontSize: 10, marginTop: 2 },
  itemActions: { gap: 6 },
  equipButton: {
    backgroundColor: colors.primary,
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  equipButtonText: { color: colors.text, fontWeight: '700', fontSize: 11, textAlign: 'center' },
  enhanceButton: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
  },
  enhanceButtonDisabled: { opacity: 0.4 },
  enhanceButtonText: { color: colors.gold, fontWeight: '700', fontSize: 10, textAlign: 'center' },
  emptyText: { color: colors.textMuted, textAlign: 'center', marginTop: 20 },
});
