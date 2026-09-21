import { useRef } from 'react';
import { Animated, PanResponder, StyleSheet, View } from 'react-native';

import { colors } from '../theme/colors';

interface Props {
  size?: number;
  onChange: (dir: { x: number; y: number }) => void;
}

export function Joystick({ size = 108, onChange }: Props) {
  const knob = useRef(new Animated.ValueXY({ x: 0, y: 0 })).current;
  const radius = size / 2;
  const knobSize = size * 0.46;
  const maxDist = radius - knobSize / 2;

  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderMove: (_evt, gesture) => {
        let { dx, dy } = gesture;
        const dist = Math.hypot(dx, dy);
        if (dist > maxDist) {
          const scale = maxDist / dist;
          dx *= scale;
          dy *= scale;
        }
        knob.setValue({ x: dx, y: dy });
        onChange({ x: dx / maxDist, y: dy / maxDist });
      },
      onPanResponderRelease: () => {
        Animated.spring(knob, { toValue: { x: 0, y: 0 }, useNativeDriver: true }).start();
        onChange({ x: 0, y: 0 });
      },
      onPanResponderTerminate: () => {
        Animated.spring(knob, { toValue: { x: 0, y: 0 }, useNativeDriver: true }).start();
        onChange({ x: 0, y: 0 });
      },
    })
  ).current;

  return (
    <View
      style={[styles.base, { width: size, height: size, borderRadius: radius }]}
      {...panResponder.panHandlers}
    >
      <Animated.View
        style={[
          styles.knob,
          {
            width: knobSize,
            height: knobSize,
            borderRadius: knobSize / 2,
            transform: knob.getTranslateTransform(),
          },
        ]}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    backgroundColor: '#1a1430aa',
    borderWidth: 2,
    borderColor: '#ffffff40',
    alignItems: 'center',
    justifyContent: 'center',
  },
  knob: {
    backgroundColor: colors.primary,
    opacity: 0.85,
  },
});
