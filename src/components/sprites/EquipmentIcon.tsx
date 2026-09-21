import Svg, { Circle, Ellipse, Path, Rect } from 'react-native-svg';

import { EquipmentSlot } from '../../game/types';

interface Props {
  slot: EquipmentSlot;
  color: string;
  size?: number;
}

export function EquipmentIcon({ slot, color, size = 28 }: Props) {
  switch (slot) {
    case 'weapon':
      return (
        <Svg width={size} height={size} viewBox="0 0 100 100">
          <Rect x="46" y="10" width="8" height="52" rx="3" fill={color} transform="rotate(20 50 36)" />
          <Rect x="34" y="56" width="32" height="10" rx="3" fill="#8a6a2a" transform="rotate(20 50 61)" />
          <Circle cx="60" cy="80" r="8" fill="#f4c542" />
        </Svg>
      );
    case 'armor':
      return (
        <Svg width={size} height={size} viewBox="0 0 100 100">
          <Path d="M50 10 L82 24 L78 60 Q50 92 22 60 L18 24 Z" fill={color} />
          <Path d="M50 24 L50 74" stroke="#ffffff55" strokeWidth="4" />
        </Svg>
      );
    case 'offhand':
      return (
        <Svg width={size} height={size} viewBox="0 0 100 100">
          <Path d="M50 8 L84 20 L80 56 Q50 88 20 56 L16 20 Z" fill={color} stroke="#ffffff40" strokeWidth="3" />
          <Circle cx="50" cy="46" r="10" fill="#ffffff35" />
        </Svg>
      );
    case 'shoes':
      return (
        <Svg width={size} height={size} viewBox="0 0 100 100">
          <Path d="M32 20 L64 20 L64 56 Q84 60 88 76 L88 84 L18 84 L18 56 Z" fill={color} />
          <Rect x="32" y="20" width="32" height="10" fill="#ffffff40" />
        </Svg>
      );
    case 'ring':
      return (
        <Svg width={size} height={size} viewBox="0 0 100 100">
          <Circle cx="50" cy="60" r="26" fill="none" stroke={color} strokeWidth="10" />
          <Path d="M40 40 L50 14 L60 40 Z" fill={color} />
          <Circle cx="50" cy="60" r="9" fill="#fff" opacity={0.85} />
        </Svg>
      );
    case 'necklace':
      return (
        <Svg width={size} height={size} viewBox="0 0 100 100">
          <Path
            d="M18 22 Q50 46 82 22 Q80 46 66 58 Q50 68 34 58 Q20 46 18 22 Z"
            fill="none"
            stroke={color}
            strokeWidth="7"
          />
          <Ellipse cx="50" cy="62" rx="11" ry="13" fill={color} />
        </Svg>
      );
  }
}
