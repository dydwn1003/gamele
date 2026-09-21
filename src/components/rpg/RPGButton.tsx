import { LinearGradient } from 'expo-linear-gradient';
import { ReactNode } from 'react';
import { StyleProp, StyleSheet, Text, TouchableOpacity, ViewStyle } from 'react-native';

import { colors } from '../../theme/colors';

type Variant = 'gold' | 'neutral' | 'danger';

interface Props {
  children: ReactNode;
  onPress?: () => void;
  disabled?: boolean;
  variant?: Variant;
  style?: StyleProp<ViewStyle>;
}

const GRADIENTS: Record<Variant, [string, string]> = {
  gold: [colors.frame.goldLight, colors.frame.goldDark],
  neutral: [colors.surfaceAlt, colors.frame.wood],
  danger: ['#ff8a8a', '#a13a3a'],
};

const TEXT_COLOR: Record<Variant, string> = {
  gold: '#3a2a0a',
  neutral: colors.text,
  danger: colors.text,
};

/** A beveled, gold-trimmed button matching the game's fantasy chrome. */
export function RPGButton({ children, onPress, disabled, variant = 'gold', style }: Props) {
  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled}
      style={[styles.wrapper, disabled && styles.disabled, style]}
    >
      <LinearGradient colors={GRADIENTS[variant]} style={styles.gradient}>
        {typeof children === 'string' ? (
          <Text style={[styles.text, { color: TEXT_COLOR[variant] }]}>{children}</Text>
        ) : (
          children
        )}
      </LinearGradient>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: colors.frame.goldDark,
    overflow: 'hidden',
  },
  disabled: { opacity: 0.4 },
  gradient: {
    paddingVertical: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  text: { fontWeight: '800', fontSize: 14 },
});
