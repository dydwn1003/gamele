import { LinearGradient } from 'expo-linear-gradient';
import Svg, { Circle, Ellipse, Path, Polygon, Rect } from 'react-native-svg';
import { StyleSheet, View } from 'react-native';

import { ChapterPalette } from './sprites/palette';
import { FIELD_HEIGHT, FIELD_WIDTH, GROUND_Y } from '../game/field';
import { colors } from '../theme/colors';

interface Props {
  palette: ChapterPalette;
  chapter: number;
}

function Deco({
  x,
  w,
  h,
  children,
}: {
  x: number;
  w: number;
  h: number;
  children: React.ReactNode;
}) {
  return (
    <Svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ position: 'absolute', left: x, top: GROUND_Y - h + 6 }}>
      {children}
    </Svg>
  );
}

function Tree({ x, scale, color }: { x: number; scale: number; color: string }) {
  const h = 46 * scale;
  return (
    <Deco x={x} w={30 * scale} h={h}>
      <Rect x={12 * scale} y={26 * scale} width={6 * scale} height={20 * scale} fill="#5a3a20" />
      <Ellipse cx={15 * scale} cy={18 * scale} rx={15 * scale} ry={18 * scale} fill={color} />
    </Deco>
  );
}

function ReedCluster({ x, scale, color }: { x: number; scale: number; color: string }) {
  const h = 40 * scale;
  return (
    <Deco x={x} w={22 * scale} h={h}>
      <Path d={`M4 ${h} Q2 ${h * 0.3} 6 4`} stroke={color} strokeWidth={2.5 * scale} fill="none" />
      <Path d={`M11 ${h} Q11 ${h * 0.2} 11 2`} stroke={color} strokeWidth={2.5 * scale} fill="none" />
      <Path d={`M18 ${h} Q20 ${h * 0.3} 16 6`} stroke={color} strokeWidth={2.5 * scale} fill="none" />
      <Ellipse cx="11" cy="6" rx="3.5" ry="6" fill="#5a3a2a" />
    </Deco>
  );
}

function RuinPillar({ x, scale, color }: { x: number; scale: number; color: string }) {
  const h = 50 * scale;
  return (
    <Deco x={x} w={18 * scale} h={h}>
      <Rect x="2" y="6" width="14" height={h - 6} fill={color} stroke="#241a30" strokeWidth={1.6} />
      <Path d="M0 6 L9 -2 L18 6 Z" fill={color} stroke="#241a30" strokeWidth={1.6} />
      <Rect x="2" y={h * 0.45} width="14" height="4" fill="#00000030" />
    </Deco>
  );
}

function LavaRock({ x, scale, color, accent }: { x: number; scale: number; color: string; accent: string }) {
  const h = 34 * scale;
  return (
    <Deco x={x} w={30 * scale} h={h}>
      <Polygon points={`2,${h} 8,${h * 0.3} 16,${h * 0.55} 22,${h * 0.15} 28,${h}`} fill={color} stroke="#241a30" strokeWidth={1.8} />
      <Path d={`M14 ${h} Q16 ${h * 0.6} 20 ${h * 0.7}`} stroke={accent} strokeWidth={2} fill="none" opacity={0.85} />
    </Deco>
  );
}

function IceCrystal({ x, scale, color }: { x: number; scale: number; color: string }) {
  const h = 42 * scale;
  return (
    <Deco x={x} w={24 * scale} h={h}>
      <Polygon points={`12,0 20,${h * 0.5} 12,${h} 4,${h * 0.5}`} fill={color} stroke="#241a30" strokeWidth={1.8} opacity={0.9} />
      <Polygon points={`12,6 16,${h * 0.5} 12,${h - 6}`} fill="#ffffff60" />
    </Deco>
  );
}

function DeadTree({ x, scale, color }: { x: number; scale: number; color: string }) {
  const h = 48 * scale;
  return (
    <Deco x={x} w={30 * scale} h={h}>
      <Path
        d={`M15 ${h} L15 ${h * 0.3} M15 ${h * 0.5} L4 ${h * 0.2} M15 ${h * 0.4} L26 ${h * 0.1} M15 ${h * 0.65} L6 ${h * 0.45}`}
        stroke={color}
        strokeWidth={3 * scale}
        fill="none"
        strokeLinecap="round"
      />
    </Deco>
  );
}

const MAP_DECOR: Record<
  number,
  (palette: ChapterPalette) => { x: number; node: React.ReactNode }[]
> = {
  1: (p) => [
    { x: 0.08, node: <Tree x={0} scale={1} color={p.body} /> },
    { x: 0.55, node: <Tree x={0} scale={0.8} color={p.accent} /> },
    { x: 0.78, node: <Tree x={0} scale={1.2} color={p.body} /> },
  ],
  2: (p) => [
    { x: 0.1, node: <ReedCluster x={0} scale={1} color={p.accent} /> },
    { x: 0.4, node: <ReedCluster x={0} scale={0.8} color={p.body} /> },
    { x: 0.82, node: <ReedCluster x={0} scale={1.1} color={p.accent} /> },
  ],
  3: (p) => [
    { x: 0.1, node: <RuinPillar x={0} scale={1} color={p.body} /> },
    { x: 0.5, node: <RuinPillar x={0} scale={0.75} color={p.accent} /> },
    { x: 0.8, node: <RuinPillar x={0} scale={1.15} color={p.body} /> },
  ],
  4: (p) => [
    { x: 0.08, node: <LavaRock x={0} scale={1.1} color={p.accent} accent={p.glow} /> },
    { x: 0.48, node: <LavaRock x={0} scale={0.85} color={p.body} accent={p.glow} /> },
    { x: 0.78, node: <LavaRock x={0} scale={1.2} color={p.accent} accent={p.glow} /> },
  ],
  5: (p) => [
    { x: 0.1, node: <IceCrystal x={0} scale={1} color={p.body} /> },
    { x: 0.45, node: <IceCrystal x={0} scale={1.3} color={p.accent} /> },
    { x: 0.8, node: <IceCrystal x={0} scale={0.85} color={p.body} /> },
  ],
  6: (p) => [
    { x: 0.08, node: <DeadTree x={0} scale={1} color={p.accent} /> },
    { x: 0.5, node: <DeadTree x={0} scale={0.8} color={p.body} /> },
    { x: 0.8, node: <DeadTree x={0} scale={1.15} color={p.accent} /> },
  ],
};

/** A parallax side-scroller backdrop: sky, distant hills, ground band, and per-map decoration. */
export function SideScrollBackground({ palette, chapter }: Props) {
  const decorate = MAP_DECOR[Math.min(Math.max(chapter, 1), 6)] ?? MAP_DECOR[1];

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

      {decorate(palette).map((d, i) => (
        <View key={i} style={{ position: 'absolute', left: FIELD_WIDTH * d.x, top: 0 }}>
          {d.node}
        </View>
      ))}
    </View>
  );
}
