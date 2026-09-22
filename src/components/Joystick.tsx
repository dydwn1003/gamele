import React, { useMemo, useRef, useState } from 'react';
import { PanResponder, StyleSheet, View } from 'react-native';

import { colors } from '../theme/colors';

interface Props {
  onChange: (vector: { x: number; y: number }) => void;
}

const BASE_SIZE = 120;
const KNOB_SIZE = 52;
const MAX_RADIUS = (BASE_SIZE - KNOB_SIZE) / 2;

export function Joystick({ onChange }: Props) {
  const [knobOffset, setKnobOffset] = useState({ x: 0, y: 0 });
  const onChangeRef = useRef(onChange);
  onChangeRef.current = onChange;

  const panResponder = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => true,
        onMoveShouldSetPanResponder: () => true,
        onPanResponderMove: (_evt, gesture) => {
          const dist = Math.hypot(gesture.dx, gesture.dy);
          const clamped = Math.min(dist, MAX_RADIUS);
          const angle = Math.atan2(gesture.dy, gesture.dx);
          const x = Math.cos(angle) * clamped;
          const y = Math.sin(angle) * clamped;
          setKnobOffset({ x, y });
          onChangeRef.current({ x: x / MAX_RADIUS, y: y / MAX_RADIUS });
        },
        onPanResponderRelease: () => {
          setKnobOffset({ x: 0, y: 0 });
          onChangeRef.current({ x: 0, y: 0 });
        },
        onPanResponderTerminate: () => {
          setKnobOffset({ x: 0, y: 0 });
          onChangeRef.current({ x: 0, y: 0 });
        },
      }),
    [],
  );

  return (
    <View style={styles.base} {...panResponder.panHandlers}>
      <View style={[styles.knob, { transform: [{ translateX: knobOffset.x }, { translateY: knobOffset.y }] }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    width: BASE_SIZE,
    height: BASE_SIZE,
    borderRadius: BASE_SIZE / 2,
    backgroundColor: 'rgba(255,255,255,0.12)',
    borderWidth: 2,
    borderColor: 'rgba(255,255,255,0.25)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  knob: {
    width: KNOB_SIZE,
    height: KNOB_SIZE,
    borderRadius: KNOB_SIZE / 2,
    backgroundColor: colors.accent,
  },
});
