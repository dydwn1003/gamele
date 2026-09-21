import Svg, { Circle, Path, Rect } from 'react-native-svg';

import { EquipmentSlot } from '../../game/types';

interface Props {
  slot: EquipmentSlot;
  color: string;
  size?: number;
}

export function EquipmentIcon({ slot, color, size = 28 }: Props) {
  if (slot === 'weapon') {
    return (
      <Svg width={size} height={size} viewBox="0 0 100 100">
        <Rect x="46" y="10" width="8" height="52" rx="3" fill={color} transform="rotate(20 50 36)" />
        <Rect x="34" y="56" width="32" height="10" rx="3" fill="#8a6a2a" transform="rotate(20 50 61)" />
        <Circle cx="60" cy="80" r="8" fill="#f4c542" />
      </Svg>
    );
  }
  if (slot === 'armor') {
    return (
      <Svg width={size} height={size} viewBox="0 0 100 100">
        <Path d="M50 10 L82 24 L78 60 Q50 92 22 60 L18 24 Z" fill={color} />
        <Path d="M50 24 L50 74" stroke="#ffffff55" strokeWidth="4" />
      </Svg>
    );
  }
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      <Circle cx="50" cy="60" r="26" fill="none" stroke={color} strokeWidth="10" />
      <Path d="M40 40 L50 14 L60 40 Z" fill={color} />
      <Circle cx="50" cy="60" r="9" fill="#fff" opacity={0.85} />
    </Svg>
  );
}
