import Svg, { Circle, Ellipse, Path } from 'react-native-svg';

import { chapterForStage, paletteForChapter } from './palette';

interface Props {
  stageId: number;
  isMiniBoss?: boolean;
  size?: number;
}

export function MonsterSprite({ stageId, isMiniBoss = false, size = 72 }: Props) {
  const palette = paletteForChapter(chapterForStage(stageId));

  if (isMiniBoss) {
    return (
      <Svg width={size} height={size} viewBox="0 0 100 100">
        <Circle cx="50" cy="55" r="34" fill={palette.glow} opacity={0.5} />
        <Path
          d="M20 60 Q18 25 50 20 Q82 25 80 60 Q80 88 50 90 Q20 88 20 60 Z"
          fill={palette.body}
        />
        <Path d="M32 30 L38 14 L44 32 Z" fill={palette.accent} />
        <Path d="M68 30 L62 14 L56 32 Z" fill={palette.accent} />
        <Circle cx="40" cy="55" r="5" fill="#241a12" />
        <Circle cx="60" cy="55" r="5" fill="#241a12" />
        <Path d="M38 70 Q50 80 62 70" stroke="#241a12" strokeWidth="3" fill="none" strokeLinecap="round" />
      </Svg>
    );
  }

  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      {/* body */}
      <Ellipse cx="50" cy="58" rx="30" ry="24" fill={palette.body} />
      {/* head */}
      <Circle cx="50" cy="32" r="20" fill={palette.body} />
      {/* ears */}
      <Path d="M32 22 L26 6 L42 16 Z" fill={palette.accent} />
      <Path d="M68 22 L74 6 L58 16 Z" fill={palette.accent} />
      {/* muzzle */}
      <Ellipse cx="50" cy="38" rx="9" ry="6" fill="#fff7ec" />
      {/* eyes */}
      <Circle cx="42" cy="30" r="2.6" fill="#241a12" />
      <Circle cx="58" cy="30" r="2.6" fill="#241a12" />
      {/* nose */}
      <Circle cx="50" cy="37" r="2" fill="#241a12" />
      {/* legs */}
      <Ellipse cx="34" cy="80" rx="7" ry="6" fill={palette.accent} />
      <Ellipse cx="66" cy="80" rx="7" ry="6" fill={palette.accent} />
      {/* tail */}
      <Path d="M78 55 Q92 50 88 36" stroke={palette.accent} strokeWidth="6" fill="none" strokeLinecap="round" />
    </Svg>
  );
}
