import { FAVORITE_FOOD, GameState, ItemKind, Species } from './types';

export const STARTING_LIVES = 3;
export const PLAYER_SIZE = 56;
export const ITEM_SIZE = 34;
export const PLAYER_BOTTOM_MARGIN = 24;

const ALL_ITEM_KINDS: ItemKind[] = ['fish', 'bone', 'seed', 'rock'];

export function createInitialState(species: Species, areaWidth: number, areaHeight: number): GameState {
  return {
    species,
    areaWidth,
    areaHeight,
    playerX: areaWidth / 2,
    playerSize: PLAYER_SIZE,
    items: [],
    score: 0,
    lives: STARTING_LIVES,
    elapsed: 0,
    spawnCooldown: 0.6,
    nextId: 1,
    status: 'playing',
  };
}

function difficultyAt(elapsed: number) {
  const rampSpawn = Math.max(0.45, 1.1 - elapsed * 0.012);
  const rampSpeed = 90 + elapsed * 4.5;
  return { spawnInterval: rampSpawn, fallSpeed: Math.min(rampSpeed, 260) };
}

function pickItemKind(species: Species): ItemKind {
  const favorite = FAVORITE_FOOD[species];
  const roll = Math.random();
  if (roll < 0.45) return favorite;
  if (roll < 0.85) {
    const others = ALL_ITEM_KINDS.filter((kind) => kind !== favorite && kind !== 'rock');
    return others[Math.floor(Math.random() * others.length)];
  }
  return 'rock';
}

function resolveCatch(species: Species, kind: ItemKind): { scoreDelta: number; livesDelta: number } {
  if (kind === 'rock') return { scoreDelta: 0, livesDelta: -1 };
  if (kind === FAVORITE_FOOD[species]) return { scoreDelta: 10, livesDelta: 0 };
  return { scoreDelta: 2, livesDelta: 0 };
}

export function setPlayerTarget(state: GameState, targetX: number): GameState {
  const half = state.playerSize / 2;
  const clamped = Math.max(half, Math.min(state.areaWidth - half, targetX));
  return { ...state, playerX: clamped };
}

export function stepGame(state: GameState, dt: number): GameState {
  if (state.status !== 'playing') return state;

  const elapsed = state.elapsed + dt;
  const { spawnInterval, fallSpeed } = difficultyAt(elapsed);

  let spawnCooldown = state.spawnCooldown - dt;
  const items = state.items.map((item) => ({ ...item, y: item.y + item.speed * dt }));
  let nextId = state.nextId;

  if (spawnCooldown <= 0) {
    spawnCooldown += spawnInterval;
    const kind = pickItemKind(state.species);
    items.push({
      id: nextId++,
      kind,
      x: ITEM_SIZE / 2 + Math.random() * (state.areaWidth - ITEM_SIZE),
      y: -ITEM_SIZE,
      size: ITEM_SIZE,
      speed: fallSpeed * (0.85 + Math.random() * 0.3),
    });
  }

  const playerTop = state.areaHeight - PLAYER_BOTTOM_MARGIN - state.playerSize;
  const playerLeft = state.playerX - state.playerSize / 2;
  const playerRight = state.playerX + state.playerSize / 2;

  let score = state.score;
  let lives = state.lives;
  const survivors = items.filter((item) => {
    const itemBottom = item.y + item.size;
    const itemLeft = item.x - item.size / 2;
    const itemRight = item.x + item.size / 2;

    if (itemBottom < playerTop) return true;
    if (item.y > state.areaHeight) return false;

    const overlapsX = itemRight > playerLeft && itemLeft < playerRight;
    if (!overlapsX) return itemBottom < state.areaHeight + item.size;

    const { scoreDelta, livesDelta } = resolveCatch(state.species, item.kind);
    score += scoreDelta;
    lives += livesDelta;
    return false;
  });

  const status = lives <= 0 ? 'gameover' : 'playing';

  return {
    ...state,
    elapsed,
    spawnCooldown,
    items: survivors,
    nextId,
    score,
    lives: Math.max(0, lives),
    status,
  };
}
