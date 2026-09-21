import { LinearGradient } from 'expo-linear-gradient';
import Svg, { Circle, Ellipse, Path, Rect } from 'react-native-svg';
import { StyleSheet, View } from 'react-native';

import { ChapterPalette } from './sprites/palette';
import { FIELD_HEIGHT, FIELD_WIDTH, GROUND_Y } from '../game/field';
import { colors } from '../theme/colors';

interface Props {
  palette: ChapterPalette;
}

function Tree({ x, scale, color }: { x: number; scale: number; color: string }) {
  const h = 46 * scale;
  return (
    <Svg
      width={30 * scale}
      height={h}
      viewBox="0 0 30 46"
      style={{ position: 'absolute', left: x, top: GROUND_Y - h + 6 }}
    >
      <Rect x="12" y="26" width="6" height="20" fill="#5a3a20" />
      <Ellipse cx="15" cy="18" rx="15" ry="18" fill={color} />
    </Svg>
  );
}

/** A parallax side-scroller backdrop: sky, distant hills, and a ground band — themed per chapter. */
export function SideScrollBackground({ palette }: Props) {
  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <LinearGradient
        colors={[palette.glow, colors.background]}
        style={StyleSheet.absoluteFill}
      />

      <Svg width={FIELD_WIDTH} height={FIELD_HEIGHT} style={StyleSheet.absoluteFill}>
        <Path
          d={`M0 ${GROUND_Y - 10} Q ${FIELD_WIDTH * 0.2} ${GROUND_Y - 55} ${FIELD_WIDTH * 0.45} ${GROUND_Y - 15} Q ${FIELD_WIDTH * 0.7} ${GROUND_Y - 60} ${FIELD_WIDTH} ${GROUND_Y - 20} L ${FIELD_WIDTH} ${GROUND_Y} L 0 ${GROUND_Y} Z`}
          fill={palette.body}
          opacity={0.28}
        />
        <Rect x={0} y={GROUND_Y} width={FIELD_WIDTH} height={FIELD_HEIGHT - GROUND_Y} fill={palette.accent} />
        <Rect x={0} y={GROUND_Y} width={FIELD_WIDTH} height={6} fill={palette.body} />
      </Svg>

      <Tree x={FIELD_WIDTH * 0.08} scale={1} color={palette.body} />
      <Tree x={FIELD_WIDTH * 0.78} scale={1.2} color={palette.body} />
      <Tree x={FIELD_WIDTH * 0.55} scale={0.8} color={palette.accent} />
    </View>
  );
}
