export type Species = 'cat' | 'dog' | 'hamster';

export type ItemKind = 'fish' | 'bone' | 'seed' | 'rock';

export const FAVORITE_FOOD: Record<Species, ItemKind> = {
  cat: 'fish',
  dog: 'bone',
  hamster: 'seed',
};

export const SPECIES_LABEL: Record<Species, string> = {
  cat: '고양이',
  dog: '강아지',
  hamster: '햄스터',
};

export interface FallingItem {
  id: number;
  kind: ItemKind;
  x: number;
  y: number;
  size: number;
  speed: number;
}

export type GameStatus = 'playing' | 'gameover';

export interface GameState {
  species: Species;
  areaWidth: number;
  areaHeight: number;
  playerX: number;
  playerSize: number;
  items: FallingItem[];
  score: number;
  lives: number;
  elapsed: number;
  spawnCooldown: number;
  nextId: number;
  status: GameStatus;
}
