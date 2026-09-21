import type { ReactElement } from 'react';
import Svg, { Circle, Defs, Ellipse, LinearGradient, Path, Polygon, Stop } from 'react-native-svg';

import { chapterForStage, ChapterPalette, paletteForChapter } from './palette';

interface Props {
  stageId: number;
  isMiniBoss?: boolean;
  size?: number;
}

const OUTLINE = '#241a30';
const OUTLINE_W = 2.6;

interface SpeciesProps {
  palette: ChapterPalette;
  boss: boolean;
}

/** Big cute eyes with a highlight dot — the single biggest lever for "cute mobile RPG" appeal. */
function CuteEyes({ cx1, cx2, cy, r = 5.5 }: { cx1: number; cx2: number; cy: number; r?: number }) {
  return (
    <>
      <Circle cx={cx1} cy={cy} r={r} fill="#fff" stroke={OUTLINE} strokeWidth={1.4} />
      <Circle cx={cx2} cy={cy} r={r} fill="#fff" stroke={OUTLINE} strokeWidth={1.4} />
      <Circle cx={cx1 + 1} cy={cy + 1} r={r * 0.55} fill="#241a30" />
      <Circle cx={cx2 + 1} cy={cy + 1} r={r * 0.55} fill="#241a30" />
      <Circle cx={cx1 - 1} cy={cy - 1.4} r={r * 0.22} fill="#fff" />
      <Circle cx={cx2 - 1} cy={cy - 1.4} r={r * 0.22} fill="#fff" />
    </>
  );
}

function Blush({ cx1, cx2, cy }: { cx1: number; cx2: number; cy: number }) {
  return (
    <>
      <Ellipse cx={cx1} cy={cy} rx={4.5} ry={2.8} fill="#ff8fa3" opacity={0.55} />
      <Ellipse cx={cx2} cy={cy} rx={4.5} ry={2.8} fill="#ff8fa3" opacity={0.55} />
    </>
  );
}

function GrassPuff({ palette, boss }: SpeciesProps) {
  const scale = boss ? 1.25 : 1;
  return (
    <>
      <Ellipse cx="50" cy={70 - (scale - 1) * 20} rx={30 * scale} ry={9 * scale} fill="#00000030" />
      <Path
        d="M22 62 Q18 30 50 26 Q82 30 78 62 Q78 86 50 88 Q22 86 22 62 Z"
        fill={palette.body}
        stroke={OUTLINE}
        strokeWidth={OUTLINE_W}
      />
      <Path d="M30 30 Q24 6 34 4 Q40 8 36 32 Z" fill={palette.accent} stroke={OUTLINE} strokeWidth={2} />
      <Path d="M70 30 Q76 6 66 4 Q60 8 64 32 Z" fill={palette.accent} stroke={OUTLINE} strokeWidth={2} />
      {boss && (
        <Polygon points="38,20 44,6 50,16 56,6 62,20" fill="#ffd94a" stroke={OUTLINE} strokeWidth={1.6} />
      )}
      <CuteEyes cx1={40} cx2={60} cy={58} />
      <Blush cx1={32} cx2={68} cy={68} />
      <Path d="M42 72 Q50 78 58 72" stroke={OUTLINE} strokeWidth={2} fill="none" strokeLinecap="round" />
      <Ellipse cx="36" cy="86" rx="8" ry="5" fill={palette.accent} stroke={OUTLINE} strokeWidth={2} />
      <Ellipse cx="64" cy="86" rx="8" ry="5" fill={palette.accent} stroke={OUTLINE} strokeWidth={2} />
    </>
  );
}

function LakeFrog({ palette, boss }: SpeciesProps) {
  const scale = boss ? 1.25 : 1;
  return (
    <>
      <Ellipse cx="50" cy={72 - (scale - 1) * 20} rx={32 * scale} ry={9 * scale} fill="#00000030" />
      <Path
        d="M18 66 Q16 40 50 36 Q84 40 82 66 Q82 84 50 86 Q18 84 18 66 Z"
        fill={palette.body}
        stroke={OUTLINE}
        strokeWidth={OUTLINE_W}
      />
      <Circle cx="34" cy="30" r={boss ? 13 : 11} fill={palette.body} stroke={OUTLINE} strokeWidth={OUTLINE_W} />
      <Circle cx="66" cy="30" r={boss ? 13 : 11} fill={palette.body} stroke={OUTLINE} strokeWidth={OUTLINE_W} />
      <Circle cx="30" cy="46" r="3.5" fill={palette.accent} opacity={0.6} />
      <Circle cx="70" cy="46" r="3.5" fill={palette.accent} opacity={0.6} />
      <Circle cx="50" cy="60" r="3" fill={palette.accent} opacity={0.6} />
      {boss && <Polygon points="42,20 50,8 58,20" fill="#ffd94a" stroke={OUTLINE} strokeWidth={1.6} />}
      <CuteEyes cx1={34} cx2={66} cy={30} r={6} />
      <Path d="M32 68 Q50 78 68 68" stroke={OUTLINE} strokeWidth={2.2} fill="none" strokeLinecap="round" />
      <Path d="M14 74 Q6 70 8 62" stroke={palette.accent} strokeWidth={5} fill="none" strokeLinecap="round" />
      <Path d="M86 74 Q94 70 92 62" stroke={palette.accent} strokeWidth={5} fill="none" strokeLinecap="round" />
    </>
  );
}

function ArcaneWisp({ palette, boss }: SpeciesProps) {
  const scale = boss ? 1.25 : 1;
  return (
    <>
      <Ellipse cx="50" cy={78} rx={26 * scale} ry={7 * scale} fill="#00000030" />
      <Polygon
        points="50,16 76,38 68,74 32,74 24,38"
        fill={palette.body}
        stroke={OUTLINE}
        strokeWidth={OUTLINE_W}
      />
      <Path d="M40 30 L44 50" stroke={palette.accent} strokeWidth={2} opacity={0.7} />
      <Path d="M60 32 L58 55" stroke={palette.accent} strokeWidth={2} opacity={0.7} />
      <Polygon points="38,44 44,38 50,44 44,50" fill={palette.glow} stroke={OUTLINE} strokeWidth={1.6} />
      <Polygon points="52,44 58,38 64,44 58,50" fill={palette.glow} stroke={OUTLINE} strokeWidth={1.6} />
      {boss && (
        <>
          <Polygon points="14,40 22,34 20,46" fill={palette.accent} stroke={OUTLINE} strokeWidth={1.6} />
          <Polygon points="86,40 78,34 80,46" fill={palette.accent} stroke={OUTLINE} strokeWidth={1.6} />
        </>
      )}
      <Path d="M40 62 Q50 68 60 62" stroke={OUTLINE} strokeWidth={2} fill="none" strokeLinecap="round" />
    </>
  );
}

function FlameImp({ palette, boss }: SpeciesProps) {
  const scale = boss ? 1.25 : 1;
  return (
    <>
      <Ellipse cx="50" cy={78} rx={24 * scale} ry={7 * scale} fill="#00000030" />
      <Path
        d="M50 18 Q40 8 34 16 Q42 20 40 26 Q26 32 24 52 Q22 76 50 80 Q78 76 76 52 Q74 32 60 26 Q58 20 66 16 Q60 8 50 18 Z"
        fill={palette.body}
        stroke={OUTLINE}
        strokeWidth={OUTLINE_W}
      />
      <Polygon points="30,22 26,10 36,18" fill={palette.accent} stroke={OUTLINE} strokeWidth={1.8} />
      <Polygon points="70,22 74,10 64,18" fill={palette.accent} stroke={OUTLINE} strokeWidth={1.8} />
      {boss && <Polygon points="42,14 50,2 58,14" fill="#ffd94a" stroke={OUTLINE} strokeWidth={1.6} />}
      <CuteEyes cx1={40} cx2={60} cy={48} />
      <Path d="M40 62 Q50 70 60 62 Q50 58 40 62 Z" fill="#3a1a12" stroke={OUTLINE} strokeWidth={1.6} />
      <Polygon points="43,62 46,58 49,62" fill="#fff" />
      <Polygon points="51,62 54,58 57,62" fill="#fff" />
    </>
  );
}

function SnowCub({ palette, boss }: SpeciesProps) {
  const scale = boss ? 1.25 : 1;
  return (
    <>
      <Ellipse cx="50" cy={78} rx={28 * scale} ry={7 * scale} fill="#00000030" />
      <Circle cx="50" cy="58" r={30 * scale * 0.9} fill={palette.body} stroke={OUTLINE} strokeWidth={OUTLINE_W} />
      <Circle cx="30" cy="38" r="7" fill={palette.body} stroke={OUTLINE} strokeWidth={2} />
      <Circle cx="70" cy="38" r="7" fill={palette.body} stroke={OUTLINE} strokeWidth={2} />
      <Polygon points="46,30 50,16 54,30" fill={palette.accent} stroke={OUTLINE} strokeWidth={1.8} />
      {boss && (
        <Polygon points="36,26 50,10 64,26" fill="#e8f8ff" stroke={OUTLINE} strokeWidth={1.8} opacity={0.9} />
      )}
      <CuteEyes cx1={40} cx2={60} cy={54} />
      <Blush cx1={33} cx2={67} cy={62} />
      <Ellipse cx="50" cy="64" rx="4" ry="3" fill={palette.accent} stroke={OUTLINE} strokeWidth={1.4} />
      <Ellipse cx="36" cy="84" rx="9" ry="5" fill={palette.accent} stroke={OUTLINE} strokeWidth={2} />
      <Ellipse cx="64" cy="84" rx="9" ry="5" fill={palette.accent} stroke={OUTLINE} strokeWidth={2} />
    </>
  );
}

function ShadowWisp({ palette, boss }: SpeciesProps) {
  const scale = boss ? 1.25 : 1;
  return (
    <>
      <Ellipse cx="50" cy={80} rx={24 * scale} ry={6 * scale} fill="#00000030" />
      <Path
        d="M50 14 Q80 26 76 56 Q84 66 74 72 Q76 80 64 78 Q58 86 50 78 Q42 86 36 78 Q24 80 26 72 Q16 66 24 56 Q20 26 50 14 Z"
        fill={palette.body}
        stroke={OUTLINE}
        strokeWidth={OUTLINE_W}
      />
      <Polygon points="18,44 4,38 14,54" fill={palette.accent} stroke={OUTLINE} strokeWidth={1.8} opacity={0.9} />
      <Polygon points="82,44 96,38 86,54" fill={palette.accent} stroke={OUTLINE} strokeWidth={1.8} opacity={0.9} />
      {boss && (
        <Polygon points="40,18 50,4 60,18" fill="#ff5a5f" stroke={OUTLINE} strokeWidth={1.6} />
      )}
      <Circle cx="42" cy="44" r="5" fill="#ffe27a" />
      <Circle cx="58" cy="44" r="5" fill="#ffe27a" />
      <Circle cx="42" cy="44" r="2.4" fill="#241a30" />
      <Circle cx="58" cy="44" r="2.4" fill="#241a30" />
      <Path d="M42 58 Q50 52 58 58" stroke={OUTLINE} strokeWidth={2} fill="none" strokeLinecap="round" />
    </>
  );
}

const SPECIES_BY_CHAPTER: Record<number, (p: SpeciesProps) => ReactElement> = {
  1: GrassPuff,
  2: LakeFrog,
  3: ArcaneWisp,
  4: FlameImp,
  5: SnowCub,
  6: ShadowWisp,
};

export function MonsterSprite({ stageId, isMiniBoss = false, size = 72 }: Props) {
  const chapter = chapterForStage(stageId);
  const palette = paletteForChapter(chapter);
  const Species = SPECIES_BY_CHAPTER[Math.min(Math.max(chapter, 1), 6)];

  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      <Defs>
        <LinearGradient id="mglow" x1="0" y1="0" x2="0" y2="1">
          <Stop offset="0" stopColor={palette.glow} stopOpacity={0.4} />
          <Stop offset="1" stopColor={palette.glow} stopOpacity={0} />
        </LinearGradient>
      </Defs>
      <Circle cx="50" cy="50" r="46" fill="url(#mglow)" />
      <Species palette={palette} boss={isMiniBoss} />
    </Svg>
  );
}
