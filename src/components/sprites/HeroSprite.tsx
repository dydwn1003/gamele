import Svg, { Circle, Ellipse, Path, Rect } from 'react-native-svg';

interface Props {
  size?: number;
}

export function HeroSprite({ size = 72 }: Props) {
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      {/* cape */}
      <Path d="M30 45 L20 85 L50 75 L80 85 L70 45 Z" fill="#4a3a8a" />
      {/* body */}
      <Rect x="34" y="42" width="32" height="34" rx="10" fill="#5b4bcf" />
      {/* belt */}
      <Rect x="34" y="60" width="32" height="7" fill="#f4c542" />
      {/* head */}
      <Circle cx="50" cy="28" r="20" fill="#ffd9b3" />
      {/* hair */}
      <Path d="M30 24 Q30 6 50 8 Q70 6 70 24 Q70 14 50 14 Q30 14 30 24 Z" fill="#3a2a1a" />
      {/* eyes */}
      <Circle cx="43" cy="29" r="2.6" fill="#241a12" />
      <Circle cx="57" cy="29" r="2.6" fill="#241a12" />
      {/* smile */}
      <Path d="M44 36 Q50 41 56 36" stroke="#a5643c" strokeWidth="2" fill="none" strokeLinecap="round" />
      {/* arms */}
      <Ellipse cx="30" cy="52" rx="7" ry="12" fill="#5b4bcf" />
      <Ellipse cx="70" cy="52" rx="7" ry="12" fill="#5b4bcf" />
      {/* sword */}
      <Rect x="76" y="20" width="6" height="40" rx="2" fill="#d9d9e6" transform="rotate(20 79 40)" />
      <Rect x="72" y="52" width="14" height="8" rx="2" fill="#8a6a2a" transform="rotate(20 79 56)" />
      {/* legs */}
      <Rect x="38" y="75" width="9" height="16" rx="3" fill="#2e2657" />
      <Rect x="53" y="75" width="9" height="16" rx="3" fill="#2e2657" />
    </Svg>
  );
}
