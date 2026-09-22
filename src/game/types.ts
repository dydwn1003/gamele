export type Facing = 'left' | 'right';

export interface Vec2 {
  x: number;
  y: number;
}

export interface CatState {
  x: number;
  y: number;
  facing: Facing;
  moving: boolean;
  animTimer: number;
  animFrame: 0 | 1;
}

export interface Treat {
  id: number;
  x: number;
  y: number;
}

export interface GameEvent {
  type: 'zone' | 'friend' | 'treasure' | 'levelup' | 'complete';
  text: string;
}

export interface FieldState {
  cat: CatState;
  treats: Treat[];
  fullness: number;
  affection: number;
  bondLevel: number;
  spawnCooldown: number;
  nextTreatId: number;
  currentZoneId: string;
  metNpcIds: string[];
  collectedTreasureIds: number[];
  events: GameEvent[];
}
