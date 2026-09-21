import { StyleSheet, View } from 'react-native';
import Svg, {
  Circle,
  Defs,
  Ellipse,
  Path,
  Pattern,
  Polygon,
  Rect,
} from 'react-native-svg';

import { ChapterPalette } from './sprites/palette';
import { FIELD_HEIGHT, FIELD_WIDTH } from '../game/field';

interface Props {
  palette: ChapterPalette;
  chapter: number;
}

const TILE = 24;

/** Tileable ground texture: a repeating SVG pattern instead of hundreds of individual views. */
function GroundTexture({ palette }: { palette: ChapterPalette }) {
  return (
    <Svg width={FIELD_WIDTH} height={FIELD_HEIGHT} style={StyleSheet.absoluteFill}>
      <Defs>
        <Pattern id="ground" width={TILE} height={TILE} patternUnits="userSpaceOnUse">
          <Rect width={TILE} height={TILE} fill={palette.body} />
          <Path d="M4 20 L3 14" stroke={palette.accent} strokeWidth={1.4} opacity={0.6} />
          <Path d="M16 22 L15 16" stroke={palette.accent} strokeWidth={1.4} opacity={0.6} />
          <Path d="M9 8 L8 3" stroke={palette.accent} strokeWidth={1.4} opacity={0.5} />
          <Path d="M20 10 L21 5" stroke={palette.accent} strokeWidth={1.4} opacity={0.5} />
          <Circle cx={4} cy={5} r={1.6} fill={palette.glow} opacity={0.5} />
          <Circle cx={16} cy={3} r={1.2} fill={palette.glow} opacity={0.4} />
          <Circle cx={10} cy={14} r={1.8} fill={palette.accent} opacity={0.35} />
          <Circle cx={20} cy={18} r={1.3} fill={palette.glow} opacity={0.4} />
          <Circle cx={2} cy={20} r={1.1} fill={palette.accent} opacity={0.3} />
        </Pattern>
      </Defs>
      <Rect width={FIELD_WIDTH} height={FIELD_HEIGHT} fill="url(#ground)" />
    </Svg>
  );
}

function Prop({ x, y, w, h, children }: { x: number; y: number; w: number; h: number; children: React.ReactNode }) {
  return (
    <Svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ position: 'absolute', left: x, top: y }}>
      {children}
    </Svg>
  );
}

function TreeProp({ x, y, scale, color }: { x: number; y: number; scale: number; color: string }) {
  const h = 44 * scale;
  const w = 32 * scale;
  return (
    <Prop x={x} y={y} w={w} h={h}>
      <Ellipse cx={w / 2} cy={h - 4} rx={w * 0.4} ry={5} fill="#00000030" />
      <Rect x={w / 2 - 3} y={h * 0.5} width={6} height={h * 0.4} fill="#5a3a20" />
      <Circle cx={w / 2} cy={h * 0.4} r={w * 0.42} fill={color} stroke="#1e3d22" strokeWidth={2} />
    </Prop>
  );
}

function RockProp({ x, y, scale, color }: { x: number; y: number; scale: number; color: string }) {
  const w = 26 * scale;
  const h = 18 * scale;
  return (
    <Prop x={x} y={y} w={w} h={h}>
      <Ellipse cx={w / 2} cy={h - 2} rx={w * 0.42} ry={3} fill="#00000030" />
      <Polygon points={`2,${h - 2} ${w * 0.3},2 ${w * 0.6},4 ${w - 2},${h - 2}`} fill={color} stroke="#241a30" strokeWidth={1.6} />
    </Prop>
  );
}

/** One distinct landmark structure per chapter/map, echoing the reference's central tower. */
function Landmark({ chapter, palette }: { chapter: number; palette: ChapterPalette }) {
  const w = 100;
  const h = 110;
  switch (chapter) {
    case 1: // stone watchtower
      return (
        <Prop x={FIELD_WIDTH * 0.5 - w / 2} y={10} w={w} h={h}>
          <Ellipse cx={w / 2} cy={h - 6} rx={34} ry={8} fill="#00000030" />
          <Path d={`M28 ${h - 10} L28 40 Q${w / 2} 24 72 40 L72 ${h - 10} Z`} fill="#aab0c0" stroke="#241a30" strokeWidth={2.4} />
          <Rect x={44} y={h - 34} width={12} height={24} rx={3} fill="#3a2a1a" stroke="#241a30" strokeWidth={2} />
          <Polygon points={`24,40 ${w / 2},18 76,40`} fill="#8991a6" stroke="#241a30" strokeWidth={2.4} />
          <Rect x={30} y={30} width={8} height={10} fill="#5a6072" stroke="#241a30" strokeWidth={1.4} />
          <Rect x={62} y={30} width={8} height={10} fill="#5a6072" stroke="#241a30" strokeWidth={1.4} />
        </Prop>
      );
    case 2: // lakeside dock hut
      return (
        <Prop x={FIELD_WIDTH * 0.5 - w / 2} y={20} w={w} h={h * 0.75}>
          <Ellipse cx={w / 2} cy={h * 0.7} rx={30} ry={7} fill="#00000030" />
          <Rect x={20} y={40} width={60} height={30} fill="#8a5a2a" stroke="#241a30" strokeWidth={2.2} />
          <Polygon points={`14,40 ${w / 2},18 86,40`} fill="#5a3a1a" stroke="#241a30" strokeWidth={2.2} />
          <Rect x={44} y={50} width={12} height={20} fill="#3a2410" stroke="#241a30" strokeWidth={1.6} />
          <Rect x={10} y={70} width={8} height={20} fill="#6b4826" />
          <Rect x={82} y={70} width={8} height={20} fill="#6b4826" />
        </Prop>
      );
    case 3: // broken stone arch
      return (
        <Prop x={FIELD_WIDTH * 0.5 - w / 2} y={16} w={w} h={h}>
          <Ellipse cx={w / 2} cy={h - 8} rx={32} ry={7} fill="#00000030" />
          <Rect x={20} y={30} width={16} height={70} fill={palette.body} stroke="#241a30" strokeWidth={2.2} />
          <Rect x={64} y={30} width={16} height={70} fill={palette.body} stroke="#241a30" strokeWidth={2.2} />
          <Path d="M20 30 Q50 6 80 30" stroke={palette.body} strokeWidth={14} fill="none" />
          <Path d="M20 30 Q50 6 80 30" stroke="#241a30" strokeWidth={2.2} fill="none" />
          <Path d="M40 40 L36 60" stroke={palette.accent} strokeWidth={2} opacity={0.7} />
        </Prop>
      );
    case 4: // volcanic spire
      return (
        <Prop x={FIELD_WIDTH * 0.5 - w / 2} y={10} w={w} h={h}>
          <Ellipse cx={w / 2} cy={h - 6} rx={30} ry={7} fill="#00000030" />
          <Polygon points={`30,${h - 8} ${w / 2 - 8},20 ${w / 2 + 8},20 70,${h - 8}`} fill="#4a3020" stroke="#241a30" strokeWidth={2.2} />
          <Path d={`M${w / 2} 24 L${w / 2 - 4} 60 L${w / 2 + 6} 90`} stroke={palette.glow} strokeWidth={3} fill="none" opacity={0.9} />
          <Circle cx={w / 2} cy={20} r={7} fill={palette.glow} opacity={0.8} />
        </Prop>
      );
    case 5: // ice fortress spikes
      return (
        <Prop x={FIELD_WIDTH * 0.5 - w / 2} y={14} w={w} h={h}>
          <Ellipse cx={w / 2} cy={h - 8} rx={32} ry={7} fill="#00000030" />
          <Polygon points={`26,${h - 10} 26,40 ${w / 2},16 74,40 74,${h - 10}`} fill="#cdeeff" stroke="#241a30" strokeWidth={2.2} />
          <Polygon points={`36,${h - 10} 36,50 ${w / 2},30 64,50 64,${h - 10}`} fill="#eafcff" opacity={0.8} />
        </Prop>
      );
    default: // dark citadel
      return (
        <Prop x={FIELD_WIDTH * 0.5 - w / 2} y={10} w={w} h={h}>
          <Ellipse cx={w / 2} cy={h - 6} rx={32} ry={7} fill="#00000030" />
          <Rect x={26} y={36} width={48} height={64} fill="#3a2030" stroke="#241a30" strokeWidth={2.2} />
          <Polygon points={`20,36 30,16 40,36`} fill="#3a2030" stroke="#241a30" strokeWidth={1.8} />
          <Polygon points={`60,36 70,16 80,36`} fill="#3a2030" stroke="#241a30" strokeWidth={1.8} />
          <Circle cx={w / 2} cy={60} r={8} fill="#ff5a5f" opacity={0.8} />
        </Prop>
      );
  }
}

const PROP_LAYOUT: Record<number, { x: number; y: number; scale: number; kind: 'tree' | 'rock' }[]> = {
  1: [
    { x: 0.05, y: 0.15, scale: 1, kind: 'tree' },
    { x: 0.85, y: 0.2, scale: 1.1, kind: 'tree' },
    { x: 0.12, y: 0.75, scale: 0.9, kind: 'tree' },
    { x: 0.88, y: 0.7, scale: 1, kind: 'rock' },
    { x: 0.6, y: 0.85, scale: 1, kind: 'rock' },
  ],
  2: [
    { x: 0.08, y: 0.2, scale: 0.9, kind: 'tree' },
    { x: 0.9, y: 0.25, scale: 1, kind: 'rock' },
    { x: 0.15, y: 0.8, scale: 1, kind: 'rock' },
    { x: 0.85, y: 0.78, scale: 0.9, kind: 'tree' },
  ],
  3: [
    { x: 0.06, y: 0.18, scale: 1, kind: 'rock' },
    { x: 0.9, y: 0.2, scale: 1.1, kind: 'rock' },
    { x: 0.1, y: 0.78, scale: 1, kind: 'rock' },
    { x: 0.88, y: 0.75, scale: 0.9, kind: 'rock' },
  ],
  4: [
    { x: 0.06, y: 0.2, scale: 1, kind: 'rock' },
    { x: 0.88, y: 0.18, scale: 0.9, kind: 'rock' },
    { x: 0.15, y: 0.8, scale: 1.1, kind: 'rock' },
    { x: 0.82, y: 0.78, scale: 1, kind: 'rock' },
  ],
  5: [
    { x: 0.06, y: 0.18, scale: 1, kind: 'tree' },
    { x: 0.88, y: 0.2, scale: 0.9, kind: 'tree' },
    { x: 0.12, y: 0.78, scale: 1, kind: 'rock' },
    { x: 0.85, y: 0.75, scale: 1, kind: 'rock' },
  ],
  6: [
    { x: 0.06, y: 0.2, scale: 1, kind: 'tree' },
    { x: 0.88, y: 0.18, scale: 0.9, kind: 'tree' },
    { x: 0.14, y: 0.8, scale: 1, kind: 'rock' },
    { x: 0.84, y: 0.78, scale: 0.9, kind: 'tree' },
  ],
};

/** A top-down tile-based world: ground texture, scattered trees/rocks, and a per-map landmark. */
export function TileWorldBackground({ palette, chapter }: Props) {
  const props = PROP_LAYOUT[Math.min(Math.max(chapter, 1), 6)] ?? PROP_LAYOUT[1];

  return (
    <View style={StyleSheet.absoluteFill} pointerEvents="none">
      <GroundTexture palette={palette} />
      <Landmark chapter={chapter} palette={palette} />
      {props.map((p, i) =>
        p.kind === 'tree' ? (
          <TreeProp key={i} x={FIELD_WIDTH * p.x} y={FIELD_HEIGHT * p.y} scale={p.scale} color={palette.body} />
        ) : (
          <RockProp key={i} x={FIELD_WIDTH * p.x} y={FIELD_HEIGHT * p.y} scale={p.scale} color={palette.accent} />
        )
      )}
    </View>
  );
}
