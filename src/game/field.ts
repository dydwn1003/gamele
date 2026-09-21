export const FIELD_WIDTH = 340;
export const FIELD_HEIGHT = 380;
export const ENTITY_RADIUS = 30;

export const PLAYER_SPEED = 130; // px/sec
export const MONSTER_SPEED = 55; // px/sec
export const MONSTER_COUNT = 3;
export const KILLS_PER_STAGE = 8;

export const ATTACK_RANGE = 62;
export const ATTACK_COOLDOWN_MS = 850;

export const MONSTER_ATTACK_RANGE = 40;
export const MONSTER_ATTACK_COOLDOWN_MS = 1400;

export const HERO_STUN_MS = 1800;
export const RESPAWN_DELAY_MS = 900;

export const HIT_FLASH_MS = 180;
export const DEATH_ANIM_MS = 350;
export const LUNGE_MS = 180;
export const DAMAGE_POPUP_MS = 650;
export const TICK_MS = 40;

export function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

export function distance(ax: number, ay: number, bx: number, by: number): number {
  return Math.hypot(ax - bx, ay - by);
}

export function randomFieldPoint(): { x: number; y: number } {
  return {
    x: ENTITY_RADIUS + Math.random() * (FIELD_WIDTH - ENTITY_RADIUS * 2),
    y: ENTITY_RADIUS + Math.random() * (FIELD_HEIGHT - ENTITY_RADIUS * 2),
  };
}

/** Nudges a wandering monster's velocity occasionally so top-down movement feels organic. */
export function wanderVelocity(vx: number, vy: number): { vx: number; vy: number } {
  const speed = MONSTER_SPEED;
  const angle = Math.atan2(vy, vx) + (Math.random() - 0.5) * 0.8;
  return { vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed };
}
