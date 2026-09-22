import { CatState, FieldState, GameEvent, Treat, Vec2 } from './types';
import { NPCS, TREASURES, WORLD_HEIGHT, WORLD_WIDTH, zoneAt } from './world';

export const CAT_SPEED = 220;
export const CAT_SPRITE_SIZE = 70;
export const NPC_SPRITE_SIZE = 70;
export const TREAT_SIZE = 34;
export const TREASURE_SIZE = 32;
export const CATCH_RADIUS = 40;
export const NPC_GREET_RADIUS = 85;
export const TREASURE_RADIUS = 34;
export const MAX_TREATS = 6;
export const ANIM_FRAME_SECONDS = 0.18;

const FULLNESS_DECAY_PER_SEC = 100 / 240;
const AFFECTION_DECAY_PER_SEC = 100 / 480;
const PET_AFFECTION_GAIN = 6;
const FEED_FULLNESS_GAIN = 20;
const FEED_AFFECTION_GAIN = 4;
const FRIEND_AFFECTION_GAIN = 15;
const TREASURE_AFFECTION_GAIN = 8;
const TREASURE_FULLNESS_GAIN = 10;

function randomRange(min: number, max: number) {
  return min + Math.random() * (max - min);
}

export function createInitialFieldState(
  bondLevel: number,
  affection: number,
  fullness: number,
  metNpcIds: string[],
  collectedTreasureIds: number[],
): FieldState {
  const startX = WORLD_WIDTH / 2;
  const startY = WORLD_HEIGHT / 2;
  const cat: CatState = {
    x: startX,
    y: startY,
    facing: 'right',
    moving: false,
    animTimer: 0,
    animFrame: 0,
  };
  return {
    cat,
    treats: [],
    fullness,
    affection,
    bondLevel,
    spawnCooldown: 1.5,
    nextTreatId: 1,
    currentZoneId: zoneAt(startX, startY).id,
    metNpcIds,
    collectedTreasureIds,
    events: [],
  };
}

function spawnTreat(nextTreatId: number): Treat {
  const margin = TREAT_SIZE;
  return {
    id: nextTreatId,
    x: randomRange(margin, WORLD_WIDTH - margin),
    y: randomRange(margin, WORLD_HEIGHT - margin),
  };
}

function applyAffectionGain(
  affection: number,
  bondLevel: number,
  amount: number,
): { affection: number; bondLevel: number; leveledUp: boolean } {
  let next = affection + amount;
  let level = bondLevel;
  let leveledUp = false;
  while (next >= 100) {
    next -= 100;
    level += 1;
    leveledUp = true;
  }
  return { affection: Math.max(0, next), bondLevel: level, leveledUp };
}

export function stepField(state: FieldState, dt: number, joystick: Vec2): FieldState {
  const events: GameEvent[] = [];
  const magnitude = Math.min(1, Math.hypot(joystick.x, joystick.y));
  const moving = magnitude > 0.12;

  let { x, y, facing, animTimer, animFrame } = state.cat;
  if (moving) {
    const norm = Math.hypot(joystick.x, joystick.y) || 1;
    const nx = joystick.x / norm;
    const ny = joystick.y / norm;
    x += nx * CAT_SPEED * magnitude * dt;
    y += ny * CAT_SPEED * magnitude * dt;
    if (joystick.x > 0.15) facing = 'right';
    else if (joystick.x < -0.15) facing = 'left';

    animTimer += dt;
    if (animTimer >= ANIM_FRAME_SECONDS) {
      animTimer -= ANIM_FRAME_SECONDS;
      animFrame = animFrame === 0 ? 1 : 0;
    }
  } else {
    animTimer = 0;
    animFrame = 0;
  }

  const half = CAT_SPRITE_SIZE / 2;
  x = Math.max(half, Math.min(WORLD_WIDTH - half, x));
  y = Math.max(half, Math.min(WORLD_HEIGHT - half, y));

  const cat: CatState = { x, y, facing, moving, animTimer, animFrame };

  let fullness = state.fullness;
  let affection = state.affection;
  let bondLevel = state.bondLevel;

  // zone transition
  const zone = zoneAt(x, y);
  let currentZoneId = state.currentZoneId;
  if (zone.id !== currentZoneId) {
    currentZoneId = zone.id;
    events.push({ type: 'zone', text: `📍 ${zone.name}에 들어왔어요` });
  }

  // treats
  const remainingTreats: Treat[] = [];
  for (const treat of state.treats) {
    const dist = Math.hypot(treat.x - x, treat.y - y);
    if (dist < CATCH_RADIUS) {
      fullness = Math.min(100, fullness + FEED_FULLNESS_GAIN);
      const gained = applyAffectionGain(affection, bondLevel, FEED_AFFECTION_GAIN);
      affection = gained.affection;
      bondLevel = gained.bondLevel;
      if (gained.leveledUp) events.push({ type: 'levelup', text: `💗 친밀도 Lv.${bondLevel + 1}!` });
    } else {
      remainingTreats.push(treat);
    }
  }
  let treats = remainingTreats;

  let spawnCooldown = state.spawnCooldown - dt;
  let nextTreatId = state.nextTreatId;
  if (spawnCooldown <= 0 && treats.length < MAX_TREATS) {
    spawnCooldown = randomRange(3, 6);
    treats = [...treats, spawnTreat(nextTreatId)];
    nextTreatId += 1;
  }

  // NPC greetings (one-time)
  let metNpcIds = state.metNpcIds;
  for (const npc of NPCS) {
    if (metNpcIds.includes(npc.id)) continue;
    const dist = Math.hypot(npc.x - x, npc.y - y);
    if (dist < NPC_GREET_RADIUS) {
      metNpcIds = [...metNpcIds, npc.id];
      const gained = applyAffectionGain(affection, bondLevel, FRIEND_AFFECTION_GAIN);
      affection = gained.affection;
      bondLevel = gained.bondLevel;
      events.push({ type: 'friend', text: `🐾 ${npc.name}: ${npc.greeting}` });
      if (gained.leveledUp) events.push({ type: 'levelup', text: `💗 친밀도 Lv.${bondLevel + 1}!` });
    }
  }

  // treasures (one-time)
  let collectedTreasureIds = state.collectedTreasureIds;
  for (const treasure of TREASURES) {
    if (collectedTreasureIds.includes(treasure.id)) continue;
    const dist = Math.hypot(treasure.x - x, treasure.y - y);
    if (dist < TREASURE_RADIUS) {
      collectedTreasureIds = [...collectedTreasureIds, treasure.id];
      fullness = Math.min(100, fullness + TREASURE_FULLNESS_GAIN);
      const gained = applyAffectionGain(affection, bondLevel, TREASURE_AFFECTION_GAIN);
      affection = gained.affection;
      bondLevel = gained.bondLevel;
      events.push({ type: 'treasure', text: `✨ 반짝이는 보물을 찾았어요! (${collectedTreasureIds.length}/${TREASURES.length})` });
      if (gained.leveledUp) events.push({ type: 'levelup', text: `💗 친밀도 Lv.${bondLevel + 1}!` });
      if (collectedTreasureIds.length === TREASURES.length) {
        events.push({ type: 'complete', text: '🎀 보물을 모두 찾았어요! 고양이가 예쁜 리본을 얻었어요!' });
      }
    }
  }

  fullness = Math.max(0, fullness - FULLNESS_DECAY_PER_SEC * dt);
  affection = Math.max(0, affection - AFFECTION_DECAY_PER_SEC * dt);

  return {
    cat,
    treats,
    fullness,
    affection,
    bondLevel,
    spawnCooldown,
    nextTreatId,
    currentZoneId,
    metNpcIds,
    collectedTreasureIds,
    events,
  };
}

export function petCat(state: FieldState): FieldState {
  const { affection, bondLevel, leveledUp } = applyAffectionGain(state.affection, state.bondLevel, PET_AFFECTION_GAIN);
  const events = leveledUp ? [{ type: 'levelup' as const, text: `💗 친밀도 Lv.${bondLevel + 1}!` }] : [];
  return { ...state, affection, bondLevel, events };
}
