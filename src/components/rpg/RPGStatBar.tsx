import { StyleSheet, Text, View } from 'react-native';

import { colors } from '../../theme/colors';

interface Props {
  progress: number; // 0..1
  color: string;
  label?: string;
  height?: number;
}

/** A gold-framed stat bar (HP/EXP) with an inset gradient-look fill and optional centered label. */
export function RPGStatBar({ progress, color, label, height = 18 }: Props) {
  const clamped = Math.max(0, Math.min(1, progress));
  return (
    <View style={[styles.frame, { height }]}>
      <View style={styles.track}>
        <View style={[styles.fill, { width: `${clamped * 100}%`, backgroundColor: color }]} />
        <View style={styles.sheen} />
      </View>
      {label && <Text style={styles.label}>{label}</Text>}
    </View>
  );
}

const styles = StyleSheet.create({
  frame: {
    borderRadius: 999,
    borderWidth: 1.5,
    borderColor: colors.frame.goldDark,
    backgroundColor: colors.frame.wood,
    justifyContent: 'center',
    padding: 2,
  },
  track: {
    flex: 1,
    borderRadius: 999,
    overflow: 'hidden',
    backgroundColor: '#00000055',
  },
  fill: { height: '100%' },
  sheen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '45%',
    backgroundColor: '#ffffff25',
  },
  label: {
    position: 'absolute',
    alignSelf: 'center',
    color: colors.text,
    fontSize: 10,
    fontWeight: '800',
    textShadowColor: '#000000aa',
    textShadowRadius: 2,
    textShadowOffset: { width: 0, height: 1 },
  },
});
