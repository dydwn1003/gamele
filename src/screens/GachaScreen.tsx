import { FlatList, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { CurrencyBar } from '../components/CurrencyBar';
import { EquipmentIcon } from '../components/sprites/EquipmentIcon';
import { GACHA_COST_GEMS } from '../game/gacha';
import { RARITY_LABEL } from '../game/equipment';
import { EquipmentItem } from '../game/types';
import { useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

const SLOT_LABEL: Record<EquipmentItem['slot'], string> = {
  weapon: '무기',
  armor: '방어구',
  accessory: '장신구',
};

export function GachaScreen() {
  const { gold, gems, inventory, equipped, pullGacha, equipItem, unequipItem } = useGameStore();

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.title}>장비 뽑기</Text>
        <CurrencyBar gold={gold} gems={gems} />
      </View>

      <TouchableOpacity
        style={[styles.pullButton, gems < GACHA_COST_GEMS && styles.pullButtonDisabled]}
        disabled={gems < GACHA_COST_GEMS}
        onPress={() => pullGacha()}
      >
        <Text style={styles.pullButtonText}>💎 {GACHA_COST_GEMS}개로 뽑기</Text>
      </TouchableOpacity>

      <View style={styles.equippedRow}>
        {(['weapon', 'armor', 'accessory'] as const).map((slot) => {
          const item = equipped[slot];
          return (
            <View key={slot} style={styles.equippedSlot}>
              <EquipmentIcon
                slot={slot}
                color={item ? colors.rarity[item.rarity] : colors.textMuted}
                size={30}
              />
              <Text style={styles.slotLabel}>{SLOT_LABEL[slot]}</Text>
              <Text style={styles.slotItem} numberOfLines={1}>
                {item ? item.name : '없음'}
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
        renderItem={({ item }) => (
          <View style={styles.itemRow}>
            <EquipmentIcon slot={item.slot} color={colors.rarity[item.rarity]} size={30} />
            <View style={styles.itemInfo}>
              <Text style={[styles.itemName, { color: colors.rarity[item.rarity] }]}>
                [{RARITY_LABEL[item.rarity]}] {item.name}
              </Text>
              <Text style={styles.itemStats}>
                ATK+{item.stats.atk} HP+{item.stats.hp} DEF+{item.stats.def} 치명+
                {(item.stats.critRate * 100).toFixed(1)}%
              </Text>
            </View>
            <TouchableOpacity style={styles.equipButton} onPress={() => equipItem(item)}>
              <Text style={styles.equipButtonText}>장착</Text>
            </TouchableOpacity>
          </View>
        )}
        ListEmptyComponent={<Text style={styles.emptyText}>아직 뽑은 장비가 없어요</Text>}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, padding: 16, gap: 12 },
  headerRow: { gap: 10 },
  title: { color: colors.text, fontSize: 22, fontWeight: '800' },
  pullButton: {
    backgroundColor: colors.gem,
    borderRadius: 12,
    paddingVertical: 14,
    alignItems: 'center',
  },
  pullButtonDisabled: { opacity: 0.4 },
  pullButtonText: { color: colors.background, fontWeight: '800', fontSize: 16 },
  equippedRow: { flexDirection: 'row', gap: 8 },
  equippedSlot: {
    flex: 1,
    backgroundColor: colors.surface,
    borderRadius: 10,
    padding: 10,
    alignItems: 'center',
    gap: 4,
  },
  slotLabel: { color: colors.textMuted, fontSize: 10, fontWeight: '700' },
  slotItem: { color: colors.text, fontSize: 12, fontWeight: '600' },
  unequipText: { color: colors.danger, fontSize: 11 },
  sectionTitle: { color: colors.textMuted, fontSize: 12, fontWeight: '700', marginTop: 4 },
  itemRow: {
    flexDirection: 'row',
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
    alignItems: 'center',
  },
  itemInfo: { flex: 1 },
  itemName: { fontWeight: '700', fontSize: 14 },
  itemStats: { color: colors.textMuted, fontSize: 11, marginTop: 2 },
  equipButton: {
    backgroundColor: colors.primary,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  equipButtonText: { color: colors.text, fontWeight: '700', fontSize: 12 },
  emptyText: { color: colors.textMuted, textAlign: 'center', marginTop: 20 },
});
