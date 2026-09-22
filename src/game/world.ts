export const WORLD_WIDTH = 1800;
export const WORLD_HEIGHT = 2400;

export interface Zone {
  id: string;
  name: string;
  bg: string;
  x0: number;
  y0: number;
  x1: number;
  y1: number;
}

export const ZONES: Zone[] = [
  { id: 'meadow', name: '포근한 마당', bg: '#4a9c4a', x0: 0, y0: 0, x1: WORLD_WIDTH / 2, y1: WORLD_HEIGHT / 2 },
  { id: 'garden', name: '꽃밭', bg: '#6fbf6f', x0: WORLD_WIDTH / 2, y0: 0, x1: WORLD_WIDTH, y1: WORLD_HEIGHT / 2 },
  { id: 'forest', name: '그늘진 숲', bg: '#2f6b3a', x0: 0, y0: WORLD_HEIGHT / 2, x1: WORLD_WIDTH / 2, y1: WORLD_HEIGHT },
  {
    id: 'dune',
    name: '모래 언덕',
    bg: '#d9c27a',
    x0: WORLD_WIDTH / 2,
    y0: WORLD_HEIGHT / 2,
    x1: WORLD_WIDTH,
    y1: WORLD_HEIGHT,
  },
];

export function zoneAt(x: number, y: number): Zone {
  return ZONES.find((z) => x >= z.x0 && x < z.x1 && y >= z.y0 && y < z.y1) ?? ZONES[0];
}

export type DecorationKind = 'flower-pink' | 'flower-white' | 'flower-purple' | 'bush' | 'tree' | 'pond';

export interface Decoration {
  kind: DecorationKind;
  x: number;
  y: number;
}

export const DECORATIONS: Decoration[] = [
  // meadow (top-left): a few bushes near the starting area
  { kind: 'bush', x: 130, y: 160 },
  { kind: 'bush', x: 760, y: 120 },
  { kind: 'bush', x: 200, y: 980 },
  { kind: 'flower-pink', x: 500, y: 300 },
  { kind: 'flower-white', x: 650, y: 700 },
  { kind: 'flower-purple', x: 300, y: 600 },

  // garden (top-right): dense flowers
  { kind: 'flower-pink', x: 1050, y: 200 },
  { kind: 'flower-white', x: 1250, y: 350 },
  { kind: 'flower-purple', x: 1450, y: 180 },
  { kind: 'flower-pink', x: 1600, y: 500 },
  { kind: 'flower-white', x: 1150, y: 650 },
  { kind: 'flower-purple', x: 1350, y: 850 },
  { kind: 'flower-pink', x: 1700, y: 950 },
  { kind: 'bush', x: 950, y: 1000 },

  // forest (bottom-left): trees and bushes, darker and denser
  { kind: 'tree', x: 200, y: 1350 },
  { kind: 'tree', x: 450, y: 1550 },
  { kind: 'tree', x: 150, y: 1800 },
  { kind: 'tree', x: 600, y: 2100 },
  { kind: 'bush', x: 350, y: 1950 },
  { kind: 'bush', x: 700, y: 1450 },
  { kind: 'tree', x: 750, y: 2250 },

  // dune (bottom-right): sparse, sandy, a pond
  { kind: 'pond', x: 1500, y: 1450 },
  { kind: 'pond', x: 1250, y: 2150 },
  { kind: 'bush', x: 1650, y: 1700 },
  { kind: 'bush', x: 1100, y: 1850 },
];

export interface TerrainPatch {
  x: number;
  y: number;
  size: number;
}

export const TERRAIN_PATCHES: TerrainPatch[] = [
  { x: 300, y: 400, size: 180 },
  { x: 700, y: 250, size: 140 },
  { x: 500, y: 850, size: 200 },
  { x: 1200, y: 300, size: 160 },
  { x: 1550, y: 700, size: 190 },
  { x: 1000, y: 900, size: 150 },
  { x: 300, y: 1450, size: 170 },
  { x: 600, y: 1750, size: 200 },
  { x: 250, y: 2100, size: 150 },
  { x: 700, y: 2000, size: 160 },
  { x: 1300, y: 1500, size: 180 },
  { x: 1650, y: 1900, size: 150 },
  { x: 1050, y: 2150, size: 170 },
  { x: 1500, y: 2250, size: 140 },
];

export interface NpcDef {
  id: string;
  kind: 'dog' | 'hamster';
  name: string;
  x: number;
  y: number;
  greeting: string;
}

export const NPCS: NpcDef[] = [
  {
    id: 'dog',
    kind: 'dog',
    name: '몽실이',
    x: 350,
    y: 250,
    greeting: '멍! 안녕, 새로 왔구나! 나는 몽실이야. 우리 마당에서 친하게 지내자!',
  },
  {
    id: 'hamster',
    kind: 'hamster',
    name: '콩이',
    x: 250,
    y: 2150,
    greeting: '(부스럭) 어멋, 깜짝이야! 숲 속까지 찾아오다니 대단한걸? 난 콩이야, 잘 부탁해!',
  },
];

export interface TreasureDef {
  id: number;
  x: number;
  y: number;
}

export const TREASURES: TreasureDef[] = [
  { id: 1, x: 850, y: 150 },
  { id: 2, x: 1650, y: 300 },
  { id: 3, x: 550, y: 1150 },
  { id: 4, x: 800, y: 2000 },
  { id: 5, x: 1700, y: 2250 },
  { id: 6, x: 1400, y: 1150 },
];
