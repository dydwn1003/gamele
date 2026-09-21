import { ReactNode } from 'react';
import { StyleSheet, Text, View } from 'react-native';

import { colors } from '../../theme/colors';

interface Props {
  title: string;
  right?: ReactNode;
}

/** A banner-style section title: a gold rule on each side of the text. */
export function SectionHeader({ title, right }: Props) {
  return (
    <View style={styles.row}>
      <View style={styles.line} />
      <Text style={styles.title}>{title}</Text>
      <View style={styles.line} />
      {right}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  line: { flex: 1, height: 1, backgroundColor: colors.frame.gold + '55' },
  title: {
    color: colors.frame.gold,
    fontSize: 12,
    fontWeight: '800',
    letterSpacing: 1.5,
  },
});
