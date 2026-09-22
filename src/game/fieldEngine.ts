import { CatState, FieldState, Treat, Vec2 } from './types';
import { WORLD_HEIGHT, WORLD_WIDTH } from './world';

export const CAT_SPEED = 150;
export const CAT_SPRITE_SIZE = 70;
export const TREAT_SIZE = 34;
export const CATCH_RADIUS = 40;
export const MAX_TREATS = 5;
export const ANIM_FRAME_SECONDS = 0.18;

const FULLNESS_DECAY_PER_SEC = 100 / 240;
const AFFECTION_DECAY_PER_SEC = 100 / 480;
const PET_AFFECTION_GAIN = 6;
const FEED_FULLNESS_GAIN = 20;
const FEED_AFFECTION_GAIN = 4;

function randomRange(min: number, max: number) {
  return min + Math.random() * (max - min);
}

export function createInitialFieldState(bondLevel: number, affection: number, fullness: number): FieldState {
  const cat: CatState = {
    x: WORLD_WIDTH / 2,
    y: WORLD_HEIGHT / 2,
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
  };
}

function spawnTreat(state: FieldState): Treat {
  const margin = TREAT_SIZE;
  return {
    id: state.nextTreatId,
    x: randomRange(margin, WORLD_WIDTH - margin),
    y: randomRange(margin, WORLD_HEIGHT - margin),
  };
}

function applyAffectionGain(state: FieldState, amount: number): Pick<FieldState, 'affection' | 'bondLevel'> {
  let affection = state.affection + amount;
  let bondLevel = state.bondLevel;
  while (affection >= 100) {
    affection -= 100;
    bondLevel += 1;
  }
  return { affection: Math.max(0, affection), bondLevel };
}

export function stepField(state: FieldState, dt: number, joystick: Vec2): FieldState {
  const magnitude = Math.min(1, Math.hypot(joystick.x, joystick.y));
  const moving = magnitude > 0.12;

  let { x, y, facing, animTimer, animFrame } = state.cat;
  if (moving) {
    const nx = joystick.x / (Math.hypot(joystick.x, joystick.y) || 1);
    const ny = joystick.y / (Math.hypot(joystick.x, joystick.y) || 1);
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

  let treats = state.treats;
  let fullness = state.fullness;
  let affection = state.affection;
  let bondLevel = state.bondLevel;

  const remaining: Treat[] = [];
  for (const treat of treats) {
    const dist = Math.hypot(treat.x - x, treat.y - y);
    if (dist < CATCH_RADIUS) {
      fullness = Math.min(100, fullness + FEED_FULLNESS_GAIN);
      const gained = applyAffectionGain({ ...state, affection, bondLevel }, FEED_AFFECTION_GAIN);
      affection = gained.affection;
      bondLevel = gained.bondLevel;
    } else {
      remaining.push(treat);
    }
  }
  treats = remaining;

  let spawnCooldown = state.spawnCooldown - dt;
  let nextTreatId = state.nextTreatId;
  if (spawnCooldown <= 0 && treats.length < MAX_TREATS) {
    spawnCooldown = randomRange(3, 6);
    treats = [...treats, spawnTreat({ ...state, nextTreatId })];
    nextTreatId += 1;
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
  };
}

export function petCat(state: FieldState): FieldState {
  const { affection, bondLevel } = applyAffectionGain(state, PET_AFFECTION_GAIN);
  return { ...state, affection, bondLevel };
}
