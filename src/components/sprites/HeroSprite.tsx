import type { ReactElement } from 'react';
import Svg, { Circle, Defs, Ellipse, LinearGradient, Path, Rect, Stop } from 'react-native-svg';

import { ClassId } from '../../game/types';

interface Props {
  classId?: ClassId;
  size?: number;
}

function WarriorBody() {
  return (
    <>
      <Defs>
        <LinearGradient id="armor" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#c7ccd8" />
          <Stop offset="1" stopColor="#7b8399" />
        </LinearGradient>
        <LinearGradient id="cape" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#e05a5a" />
          <Stop offset="1" stopColor="#8f2f2f" />
        </LinearGradient>
      </Defs>
      <Path d="M28 46 L18 88 L50 78 L82 88 L72 46 Z" fill="url(#cape)" />
      <Rect x="32" y="42" width="36" height="36" rx="10" fill="url(#armor)" stroke="#4b4f5c" strokeWidth="1.5" />
      <Rect x="32" y="58" width="36" height="8" fill="#f4c542" />
      <Rect x="43" y="46" width="14" height="6" rx="2" fill="#ffffff55" />
      <Circle cx="50" cy="26" r="19" fill="url(#armor)" stroke="#4b4f5c" strokeWidth="1.5" />
      <Path d="M31 24 Q31 10 50 10 Q69 10 69 24 L69 20 Q50 14 31 20 Z" fill="#8f96a8" />
      <Rect x="38" y="30" width="24" height="6" rx="3" fill="#2a2d36" />
      <Circle cx="43" cy="33" r="1.8" fill="#8fd8ff" />
      <Circle cx="57" cy="33" r="1.8" fill="#8fd8ff" />
      <Ellipse cx="30" cy="54" rx="7.5" ry="13" fill="url(#armor)" />
      <Ellipse cx="70" cy="54" rx="7.5" ry="13" fill="url(#armor)" />
      <Rect x="78" y="16" width="7" height="46" rx="2.5" fill="#e7e9ef" transform="rotate(24 81 39)" />
      <Rect x="74" y="52" width="16" height="9" rx="2" fill="#8a6a2a" transform="rotate(24 81 56)" />
      <Rect x="14" y="46" width="16" height="22" rx="4" fill="#5a6072" stroke="#2a2d36" strokeWidth="1.2" />
      <Rect x="38" y="76" width="10" height="17" rx="3" fill="#2e3140" />
      <Rect x="53" y="76" width="10" height="17" rx="3" fill="#2e3140" />
    </>
  );
}

function RogueBody() {
  return (
    <>
      <Defs>
        <LinearGradient id="leather" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#6a4fa0" />
          <Stop offset="1" stopColor="#392a63" />
        </LinearGradient>
        <LinearGradient id="hood" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#4a3a7a" />
          <Stop offset="1" stopColor="#221a3d" />
        </LinearGradient>
      </Defs>
      <Path d="M22 42 L16 90 L84 90 L78 42 Q50 32 22 42 Z" fill="url(#leather)" />
      <Rect x="36" y="58" width="28" height="6" fill="#2a2140" />
      <Circle cx="50" cy="27" r="18" fill="#e0b28c" />
      <Path d="M28 26 Q28 4 50 4 Q72 4 72 26 Q72 14 50 12 Q28 14 28 26 Z" fill="url(#hood)" />
      <Path d="M38 30 Q50 24 62 30 L62 36 Q50 32 38 36 Z" fill="#2a2140" />
      <Circle cx="44" cy="29" r="2.2" fill="#8fffcf" />
      <Circle cx="56" cy="29" r="2.2" fill="#8fffcf" />
      <Ellipse cx="29" cy="52" rx="6.5" ry="12" fill="url(#leather)" />
      <Ellipse cx="71" cy="52" rx="6.5" ry="12" fill="url(#leather)" />
      <Rect x="10" y="40" width="5" height="26" rx="2" fill="#cfd3de" transform="rotate(-30 12 53)" />
      <Rect x="85" y="40" width="5" height="26" rx="2" fill="#cfd3de" transform="rotate(30 88 53)" />
      <Rect x="39" y="80" width="9" height="13" rx="3" fill="#221a3d" />
      <Rect x="52" y="80" width="9" height="13" rx="3" fill="#221a3d" />
    </>
  );
}

function ArcherBody() {
  return (
    <>
      <Defs>
        <LinearGradient id="cloak" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#6fcf73" />
          <Stop offset="1" stopColor="#2f7a39" />
        </LinearGradient>
      </Defs>
      <Path d="M26 44 L20 90 L80 90 L74 44 Q50 36 26 44 Z" fill="url(#cloak)" />
      <Rect x="60" y="30" width="14" height="30" rx="6" fill="#8a5a2a" transform="rotate(18 67 45)" />
      <Circle cx="50" cy="27" r="18" fill="#e8c39c" />
      <Path d="M30 24 Q30 6 50 6 Q70 6 70 24 Q70 14 50 12 Q30 14 30 24 Z" fill="#245c2c" />
      <Circle cx="44" cy="29" r="2.2" fill="#241a12" />
      <Circle cx="56" cy="29" r="2.2" fill="#241a12" />
      <Path d="M44 36 Q50 39 56 36" stroke="#a5643c" strokeWidth="1.6" fill="none" strokeLinecap="round" />
      <Ellipse cx="30" cy="52" rx="7" ry="12" fill="url(#cloak)" />
      <Ellipse cx="70" cy="52" rx="7" ry="12" fill="url(#cloak)" />
      <Path d="M78 20 Q92 45 78 70" stroke="#8a5a2a" strokeWidth="3.5" fill="none" />
      <Path d="M78 20 L78 70" stroke="#e8c39c" strokeWidth="1" />
      <Rect x="39" y="80" width="9" height="13" rx="3" fill="#1f4a26" />
      <Rect x="52" y="80" width="9" height="13" rx="3" fill="#1f4a26" />
    </>
  );
}

function MageBody() {
  return (
    <>
      <Defs>
        <LinearGradient id="robe" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#6a8fe0" />
          <Stop offset="1" stopColor="#31469e" />
        </LinearGradient>
        <LinearGradient id="orb" x1="0" y1="0" x2="1" y2="1">
          <Stop offset="0" stopColor="#c8f0ff" />
          <Stop offset="1" stopColor="#5cc7ff" />
        </LinearGradient>
      </Defs>
      <Path d="M24 46 L14 92 L86 92 L76 46 Q50 34 24 46 Z" fill="url(#robe)" />
      <Path d="M40 50 L50 92 L60 50 Z" fill="#22308a" opacity={0.6} />
      <Circle cx="50" cy="27" r="18" fill="#f0d3ae" />
      <Path d="M50 2 L72 30 Q50 20 28 30 Z" fill="#31469e" />
      <Circle cx="50" cy="4" r="3.5" fill="#c8f0ff" />
      <Circle cx="44" cy="29" r="2.2" fill="#241a12" />
      <Circle cx="56" cy="29" r="2.2" fill="#241a12" />
      <Ellipse cx="30" cy="54" rx="7" ry="13" fill="url(#robe)" />
      <Ellipse cx="70" cy="54" rx="7" ry="13" fill="url(#robe)" />
      <Rect x="76" y="24" width="5" height="52" rx="2.5" fill="#8a5a2a" transform="rotate(10 78 50)" />
      <Circle cx="80" cy="22" r="7" fill="url(#orb)" />
    </>
  );
}

const BODY_BY_CLASS: Record<ClassId, () => ReactElement> = {
  warrior: WarriorBody,
  rogue: RogueBody,
  archer: ArcherBody,
  mage: MageBody,
};

export function HeroSprite({ classId = 'warrior', size = 72 }: Props) {
  const Body = BODY_BY_CLASS[classId];
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      <Body />
    </Svg>
  );
}
