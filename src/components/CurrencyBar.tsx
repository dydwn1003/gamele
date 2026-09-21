import { StyleSheet, Text, View } from 'react-native';

import { colors } from '../theme/colors';

interface Props {
  gold: number;
  gems: number;
}

export function CurrencyBar({ gold, gems }: Props) {
  return (
    <View style={styles.row}>
      <View style={styles.pill}>
        <Text style={styles.icon}>🪙</Text>
        <Text style={styles.value}>{gold.toLocaleString()}</Text>
      </View>
      <View style={styles.pill}>
        <Text style={styles.icon}>💎</Text>
        <Text style={styles.value}>{gems.toLocaleString()}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: 10 },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surfaceAlt,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 20,
    gap: 6,
  },
  icon: { fontSize: 14 },
  value: { color: colors.text, fontWeight: '700' },
});
