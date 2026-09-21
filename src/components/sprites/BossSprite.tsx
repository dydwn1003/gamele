import Svg, { Circle, Ellipse, Path, Polygon, Rect } from 'react-native-svg';

import { paletteForChapter } from './palette';

interface Props {
  chapter: number;
  size?: number;
}

export const BOSS_NAMES: Record<number, string> = {
  1: '슬라임 킹',
  2: '스톤 골렘',
  3: '아케인 울프로드',
  4: '플레임 오우거',
  5: '프로스트 와이번',
  6: '어비스 마왕',
};

function BossBody({ chapter, body, accent }: { chapter: number; body: string; accent: string }) {
  switch (chapter) {
    case 1: // Slime King — big slime with crown
      return (
        <>
          <Path d="M14 62 Q10 20 50 14 Q90 20 86 62 Q86 92 50 94 Q14 92 14 62 Z" fill={body} />
          <Polygon points="36,18 40,4 50,14 60,4 64,18" fill="#ffd94a" />
          <Circle cx="40" cy="58" r="5.5" fill="#241a12" />
          <Circle cx="60" cy="58" r="5.5" fill="#241a12" />
          <Path d="M36 74 Q50 86 64 74" stroke="#241a12" strokeWidth="3.5" fill="none" strokeLinecap="round" />
        </>
      );
    case 2: // Stone Golem — blocky body
      return (
        <>
          <Rect x="24" y="40" width="52" height="46" rx="8" fill={body} />
          <Rect x="14" y="50" width="14" height="26" rx="5" fill={accent} />
          <Rect x="72" y="50" width="14" height="26" rx="5" fill={accent} />
          <Circle cx="50" cy="26" r="18" fill={body} />
          <Rect x="38" y="20" width="8" height="8" fill="#ffd94a" />
          <Rect x="54" y="20" width="8" height="8" fill="#ffd94a" />
          <Rect x="40" y="60" width="8" height="8" fill={accent} />
          <Rect x="52" y="60" width="8" height="8" fill={accent} />
        </>
      );
    case 3: // Arcane Wolf Lord — sharp ears, cloak
      return (
        <>
          <Path d="M24 88 L30 46 L70 46 L76 88 Z" fill={accent} />
          <Circle cx="50" cy="34" r="22" fill={body} />
          <Polygon points="26,26 20,2 42,20" fill={accent} />
          <Polygon points="74,26 80,2 58,20" fill={accent} />
          <Ellipse cx="50" cy="42" rx="8" ry="5" fill="#fff7ec" />
          <Circle cx="42" cy="32" r="3" fill="#ffd94a" />
          <Circle cx="58" cy="32" r="3" fill="#ffd94a" />
        </>
      );
    case 4: // Flame Ogre — broad, horns, tusks
      return (
        <>
          <Rect x="22" y="42" width="56" height="48" rx="14" fill={body} />
          <Polygon points="30,20 22,2 40,16" fill={accent} />
          <Polygon points="70,20 78,2 60,16" fill={accent} />
          <Circle cx="50" cy="32" r="22" fill={body} />
          <Circle cx="41" cy="30" r="3.4" fill="#241a12" />
          <Circle cx="59" cy="30" r="3.4" fill="#241a12" />
          <Polygon points="42,42 46,52 38,50" fill="#fff7ec" />
          <Polygon points="58,42 54,52 62,50" fill="#fff7ec" />
        </>
      );
    case 5: // Frost Wyvern — wings + long snout
      return (
        <>
          <Polygon points="8,50 30,30 34,58" fill={accent} />
          <Polygon points="92,50 70,30 66,58" fill={accent} />
          <Ellipse cx="50" cy="58" rx="26" ry="22" fill={body} />
          <Ellipse cx="50" cy="30" rx="16" ry="14" fill={body} />
          <Polygon points="50,14 44,30 56,30" fill={accent} />
          <Circle cx="43" cy="28" r="2.6" fill="#241a12" />
          <Circle cx="57" cy="28" r="2.6" fill="#241a12" />
        </>
      );
    default: // Abyss Demon Lord — dark, horns + wings
      return (
        <>
          <Polygon points="10,42 30,58 26,80" fill={accent} />
          <Polygon points="90,42 70,58 74,80" fill={accent} />
          <Path d="M26 88 L30 42 L70 42 L74 88 Z" fill={body} />
          <Circle cx="50" cy="28" r="20" fill={body} />
          <Polygon points="34,16 26,0 44,12" fill={accent} />
          <Polygon points="66,16 74,0 56,12" fill={accent} />
          <Circle cx="42" cy="27" r="3" fill="#ff5a5f" />
          <Circle cx="58" cy="27" r="3" fill="#ff5a5f" />
        </>
      );
  }
}

export function BossSprite({ chapter, size = 120 }: Props) {
  const palette = paletteForChapter(chapter);
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      <Circle cx="50" cy="55" r="46" fill={palette.glow} opacity={0.45} />
      <BossBody chapter={chapter} body={palette.body} accent={palette.accent} />
    </Svg>
  );
}
