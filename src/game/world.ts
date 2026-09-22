export const WORLD_WIDTH = 900;
export const WORLD_HEIGHT = 1300;

export type DecorationKind = 'flower-pink' | 'flower-white' | 'flower-purple' | 'bush';

export interface Decoration {
  kind: DecorationKind;
  x: number;
  y: number;
}

export const DECORATIONS: Decoration[] = [
  { kind: 'bush', x: 90, y: 120 },
  { kind: 'bush', x: 780, y: 160 },
  { kind: 'bush', x: 140, y: 980 },
  { kind: 'bush', x: 760, y: 1040 },
  { kind: 'bush', x: 450, y: 90 },
  { kind: 'flower-pink', x: 220, y: 240 },
  { kind: 'flower-white', x: 300, y: 480 },
  { kind: 'flower-purple', x: 180, y: 640 },
  { kind: 'flower-pink', x: 620, y: 320 },
  { kind: 'flower-white', x: 700, y: 560 },
  { kind: 'flower-purple', x: 560, y: 780 },
  { kind: 'flower-pink', x: 380, y: 900 },
  { kind: 'flower-white', x: 500, y: 1120 },
  { kind: 'flower-purple', x: 250, y: 1150 },
  { kind: 'flower-pink', x: 680, y: 1180 },
  { kind: 'bush', x: 420, y: 1240 },
];

export interface TerrainPatch {
  x: number;
  y: number;
  size: number;
}

export const TERRAIN_PATCHES: TerrainPatch[] = [
  { x: 160, y: 320, size: 180 },
  { x: 620, y: 240, size: 140 },
  { x: 420, y: 520, size: 220 },
  { x: 740, y: 700, size: 160 },
  { x: 220, y: 800, size: 190 },
  { x: 560, y: 980, size: 150 },
  { x: 320, y: 1100, size: 170 },
  { x: 100, y: 1180, size: 130 },
];
