import type { ReactElement } from 'react';
import Svg, { Circle, Defs, Ellipse, LinearGradient, Path, Polygon, Rect, Stop } from 'react-native-svg';

import { ClassId } from '../../game/types';

interface Props {
  classId?: ClassId;
  size?: number;
}

const OUTLINE = '#241a30';

function Face({ cx1, cx2, cy, skin }: { cx1: number; cx2: number; cy: number; skin: string }) {
  return (
    <>
      <Circle cx={cx1} cy={cy} r={3.4} fill="#fff" stroke={OUTLINE} strokeWidth={1} />
      <Circle cx={cx2} cy={cy} r={3.4} fill="#fff" stroke={OUTLINE} strokeWidth={1} />
      <Circle cx={cx1 + 0.6} cy={cy + 0.8} r={1.9} fill={OUTLINE} />
      <Circle cx={cx2 + 0.6} cy={cy + 0.8} r={1.9} fill={OUTLINE} />
      <Circle cx={cx1 - 0.6} cy={cy - 0.9} r={0.8} fill="#fff" />
      <Circle cx={cx2 - 0.6} cy={cy - 0.9} r={0.8} fill="#fff" />
      <Ellipse cx={cx1 - 6} cy={cy + 6} rx={3} ry={1.8} fill="#ff8fa3" opacity={0.5} />
      <Ellipse cx={cx2 + 6} cy={cy + 6} rx={3} ry={1.8} fill="#ff8fa3" opacity={0.5} />
      <Path
        d={`M${cx1 - 1} ${cy + 9} Q50 ${cy + 13} ${cx2 + 1} ${cy + 9}`}
        stroke={skin === 'dark' ? '#fff' : OUTLINE}
        strokeWidth={1.3}
        fill="none"
        strokeLinecap="round"
        opacity={0.75}
      />
    </>
  );
}

function WarriorBody() {
  return (
    <>
      <Defs>
        <LinearGradient id="armor" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#d8dce6" />
          <Stop offset="1" stopColor="#8891a5" />
        </LinearGradient>
        <LinearGradient id="cape" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#e85a5a" />
          <Stop offset="1" stopColor="#8f2f2f" />
        </LinearGradient>
      </Defs>
      <Path d="M28 46 L18 88 L50 78 L82 88 L72 46 Z" fill="url(#cape)" stroke={OUTLINE} strokeWidth={2} />
      <Ellipse cx="30" cy="54" rx="8" ry="13.5" fill="url(#armor)" stroke={OUTLINE} strokeWidth={2} />
      <Ellipse cx="70" cy="54" rx="8" ry="13.5" fill="url(#armor)" stroke={OUTLINE} strokeWidth={2} />
      <Rect x="31" y="41" width="38" height="37" rx="11" fill="url(#armor)" stroke={OUTLINE} strokeWidth={2.2} />
      <Rect x="31" y="58" width="38" height="8" fill="#f4c542" stroke={OUTLINE} strokeWidth={1.4} />
      <Circle cx="50" cy="60" r="4" fill="#ff5a5f" stroke={OUTLINE} strokeWidth={1.2} />
      <Rect x="43" y="45" width="14" height="6" rx="2" fill="#ffffff70" />
      <Circle cx="50" cy="25" r="21" fill="url(#armor)" stroke={OUTLINE} strokeWidth={2.2} />
      <Path d="M29 22 Q29 6 50 6 Q71 6 71 22 L71 17 Q50 10 29 17 Z" fill="#9aa2b8" stroke={OUTLINE} strokeWidth={1.6} />
      <Circle cx="61" cy="12" r="3" fill="#ffd94a" stroke={OUTLINE} strokeWidth={1} />
      <Rect x="36" y="30" width="28" height="7" rx="3.5" fill="#2a2d36" stroke={OUTLINE} strokeWidth={1.2} />
      <Face cx1={43} cx2={57} cy={32} skin="light" />
      <Rect x="78" y="14" width="7.5" height="48" rx="3" fill="#eef0f5" stroke={OUTLINE} strokeWidth={1.8} transform="rotate(24 81 39)" />
      <Rect x="74" y="52" width="17" height="10" rx="2.5" fill="#a3762c" stroke={OUTLINE} strokeWidth={1.6} transform="rotate(24 81 56)" />
      <Rect x="12" y="45" width="18" height="24" rx="5" fill="#6b7186" stroke={OUTLINE} strokeWidth={2} />
      <Circle cx="21" cy="57" r="4.5" fill="#f4c542" stroke={OUTLINE} strokeWidth={1.2} />
      <Rect x="37" y="76" width="11" height="18" rx="3.5" fill="#3a3d4a" stroke={OUTLINE} strokeWidth={1.8} />
      <Rect x="52" y="76" width="11" height="18" rx="3.5" fill="#3a3d4a" stroke={OUTLINE} strokeWidth={1.8} />
    </>
  );
}

function RogueBody() {
  return (
    <>
      <Defs>
        <LinearGradient id="leather" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#7a5cba" />
          <Stop offset="1" stopColor="#3d2d6e" />
        </LinearGradient>
        <LinearGradient id="hood" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#57459a" />
          <Stop offset="1" stopColor="#241a45" />
        </LinearGradient>
      </Defs>
      <Path d="M22 42 L16 90 L84 90 L78 42 Q50 32 22 42 Z" fill="url(#leather)" stroke={OUTLINE} strokeWidth={2.2} />
      <Rect x="34" y="56" width="32" height="7" rx="2" fill="#2a2140" stroke={OUTLINE} strokeWidth={1.4} />
      <Circle cx="50" cy="52" r="4" fill="#8fffcf" stroke={OUTLINE} strokeWidth={1} />
      <Ellipse cx="29" cy="52" rx="7.5" ry="13" fill="url(#leather)" stroke={OUTLINE} strokeWidth={2} />
      <Ellipse cx="71" cy="52" rx="7.5" ry="13" fill="url(#leather)" stroke={OUTLINE} strokeWidth={2} />
      <Circle cx="50" cy="26" r="20" fill="#f0c39c" stroke={OUTLINE} strokeWidth={2.2} />
      <Path d="M27 24 Q27 2 50 2 Q73 2 73 24 Q73 11 50 9 Q27 11 27 24 Z" fill="url(#hood)" stroke={OUTLINE} strokeWidth={2} />
      <Path d="M36 28 Q50 21 64 28 L64 37 Q50 32 36 37 Z" fill="#2a2140" stroke={OUTLINE} strokeWidth={1.6} />
      <Face cx1={43} cx2={57} cy={29} skin="light" />
      <Rect x="8" y="38" width="5.5" height="28" rx="2.5" fill="#dfe2ea" stroke={OUTLINE} strokeWidth={1.6} transform="rotate(-30 11 52)" />
      <Rect x="86" y="38" width="5.5" height="28" rx="2.5" fill="#dfe2ea" stroke={OUTLINE} strokeWidth={1.6} transform="rotate(30 89 52)" />
      <Rect x="38" y="80" width="10" height="14" rx="3.5" fill="#241a45" stroke={OUTLINE} strokeWidth={1.8} />
      <Rect x="52" y="80" width="10" height="14" rx="3.5" fill="#241a45" stroke={OUTLINE} strokeWidth={1.8} />
    </>
  );
}

function ArcherBody() {
  return (
    <>
      <Defs>
        <LinearGradient id="cloak" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#7fe084" />
          <Stop offset="1" stopColor="#357a3f" />
        </LinearGradient>
      </Defs>
      <Path d="M26 44 L20 90 L80 90 L74 44 Q50 36 26 44 Z" fill="url(#cloak)" stroke={OUTLINE} strokeWidth={2.2} />
      <Rect x="34" y="58" width="32" height="6" rx="2" fill="#1f4a26" stroke={OUTLINE} strokeWidth={1.2} />
      <Rect x="59" y="28" width="14" height="32" rx="6" fill="#a3762c" stroke={OUTLINE} strokeWidth={1.8} transform="rotate(18 67 45)" />
      <Ellipse cx="30" cy="52" rx="7.5" ry="13" fill="url(#cloak)" stroke={OUTLINE} strokeWidth={2} />
      <Ellipse cx="70" cy="52" rx="7.5" ry="13" fill="url(#cloak)" stroke={OUTLINE} strokeWidth={2} />
      <Circle cx="50" cy="26" r="20" fill="#f3cd9e" stroke={OUTLINE} strokeWidth={2.2} />
      <Path d="M29 24 Q29 4 50 4 Q71 4 71 24 Q71 12 50 10 Q29 12 29 24 Z" fill="#2c6b34" stroke={OUTLINE} strokeWidth={2} />
      <Polygon points="46,8 50,1 54,8" fill="#ffd94a" stroke={OUTLINE} strokeWidth={1} />
      <Face cx1={43} cx2={57} cy={29} skin="light" />
      <Path d="M79 18 Q95 46 79 74" stroke="#a3762c" strokeWidth={3.6} fill="none" strokeLinecap="round" />
      <Path d="M79 18 L79 74" stroke="#f3cd9e" strokeWidth={1.2} />
      <Rect x="38" y="80" width="10" height="14" rx="3.5" fill="#234f2a" stroke={OUTLINE} strokeWidth={1.8} />
      <Rect x="52" y="80" width="10" height="14" rx="3.5" fill="#234f2a" stroke={OUTLINE} strokeWidth={1.8} />
    </>
  );
}

function MageBody() {
  return (
    <>
      <Defs>
        <LinearGradient id="robe" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor="#7fa0f0" />
          <Stop offset="1" stopColor="#3a52b0" />
        </LinearGradient>
        <LinearGradient id="orb" x1="0" y1="0" x2="1" y2="1">
          <Stop offset="0" stopColor="#e0f7ff" />
          <Stop offset="1" stopColor="#5cc7ff" />
        </LinearGradient>
      </Defs>
      <Path d="M24 46 L14 92 L86 92 L76 46 Q50 34 24 46 Z" fill="url(#robe)" stroke={OUTLINE} strokeWidth={2.2} />
      <Path d="M40 50 L50 92 L60 50 Z" fill="#22308a" opacity={0.55} />
      <Ellipse cx="30" cy="54" rx="7.5" ry="13.5" fill="url(#robe)" stroke={OUTLINE} strokeWidth={2} />
      <Ellipse cx="70" cy="54" rx="7.5" ry="13.5" fill="url(#robe)" stroke={OUTLINE} strokeWidth={2} />
      <Circle cx="50" cy="26" r="20" fill="#f7dcb8" stroke={OUTLINE} strokeWidth={2.2} />
      <Path d="M50 4 L74 28 Q50 17 26 28 Z" fill="#3a52b0" stroke={OUTLINE} strokeWidth={2} />
      <Circle cx="50" cy="5" r="4" fill="url(#orb)" stroke={OUTLINE} strokeWidth={1.2} />
      <Face cx1={43} cx2={57} cy={28} skin="light" />
      <Rect x="76" y="22" width="5.5" height="54" rx="2.75" fill="#a3762c" stroke={OUTLINE} strokeWidth={1.8} transform="rotate(10 78 50)" />
      <Circle cx="80" cy="20" r="8" fill="url(#orb)" stroke={OUTLINE} strokeWidth={1.8} />
      <Circle cx="77" cy="17" r="2" fill="#ffffffcc" />
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
