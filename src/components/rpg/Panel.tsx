import { LinearGradient } from 'expo-linear-gradient';
import { ReactNode } from 'react';
import { StyleProp, StyleSheet, View, ViewStyle } from 'react-native';

import { colors } from '../../theme/colors';

interface Props {
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
}

const GEM = 8;

/** An ornate gold-trimmed panel with corner rivets — the RPG-UI stand-in for a plain card. */
export function Panel({ children, style }: Props) {
  return (
    <View style={styles.wrapper}>
      <LinearGradient
        colors={[colors.frame.panelTop, colors.frame.panelBottom]}
        style={styles.gradient}
      >
        <View style={[styles.innerBorder, style]}>{children}</View>
      </LinearGradient>
      <View style={[styles.gem, styles.gemTL]} />
      <View style={[styles.gem, styles.gemTR]} />
      <View style={[styles.gem, styles.gemBL]} />
      <View style={[styles.gem, styles.gemBR]} />
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    borderRadius: 16,
    padding: 3,
    backgroundColor: colors.frame.goldDark,
  },
  gradient: { borderRadius: 13 },
  innerBorder: {
    borderRadius: 13,
    borderWidth: 1,
    borderColor: colors.frame.gold + '40',
    padding: 14,
    gap: 8,
  },
  gem: {
    position: 'absolute',
    width: GEM,
    height: GEM,
    borderRadius: GEM / 2,
    backgroundColor: colors.frame.gold,
    borderWidth: 1,
    borderColor: colors.frame.goldDark,
  },
  gemTL: { top: -GEM / 2, left: -GEM / 2 },
  gemTR: { top: -GEM / 2, right: -GEM / 2 },
  gemBL: { bottom: -GEM / 2, left: -GEM / 2 },
  gemBR: { bottom: -GEM / 2, right: -GEM / 2 },
});
