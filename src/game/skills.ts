import { ClassId, StatBlock } from './types';

export type SkillKind = 'single' | 'aoe' | 'buff';

export interface SkillConfig {
  id: string;
  name: string;
  kind: SkillKind;
  requiredLevel: number;
  cooldownMs: number;
  multiplier: number;
  range: number;
  icon: string;
  /** buff-only: which combat stat is temporarily multiplied, and for how long. */
  buffStat?: keyof StatBlock;
  buffMultiplier?: number;
  durationMs?: number;
}

export const SKILL_MAX_LEVEL = 10;
export const SKILL_LEVEL_BONUS = 0.15; // +15% effect per skill level beyond 1
export const SKILL_POINTS_PER_LEVEL = 1;

/** Multiplier scaled by how many points are invested in a skill (skillLevel 0 = not learned). */
export function skillPowerMultiplier(skill: SkillConfig, skillLevel: number): number {
  if (skillLevel <= 0) return 0;
  return skill.multiplier * (1 + (skillLevel - 1) * SKILL_LEVEL_BONUS);
}

export const CLASS_SKILLS: Record<ClassId, SkillConfig[]> = {
  warrior: [
    { id: 'w_strike', name: '강타', kind: 'single', requiredLevel: 1, cooldownMs: 4000, multiplier: 2.4, range: 70, icon: '💥' },
    { id: 'w_bash', name: '방패강타', kind: 'single', requiredLevel: 5, cooldownMs: 4500, multiplier: 2.6, range: 65, icon: '🔨' },
    { id: 'w_whirl', name: '회전베기', kind: 'aoe', requiredLevel: 10, cooldownMs: 8000, multiplier: 1.5, range: 90, icon: '🌀' },
    {
      id: 'w_guard',
      name: '철벽의지',
      kind: 'buff',
      requiredLevel: 15,
      cooldownMs: 14000,
      multiplier: 1,
      range: 0,
      icon: '🛡️',
      buffStat: 'def',
      buffMultiplier: 1.8,
      durationMs: 5000,
    },
    {
      id: 'w_shout',
      name: '도전의외침',
      kind: 'buff',
      requiredLevel: 20,
      cooldownMs: 14000,
      multiplier: 1,
      range: 0,
      icon: '📢',
      buffStat: 'atk',
      buffMultiplier: 1.4,
      durationMs: 5000,
    },
    { id: 'w_crush', name: '대지분쇄', kind: 'aoe', requiredLevel: 25, cooldownMs: 9000, multiplier: 1.9, range: 95, icon: '💢' },
    {
      id: 'w_rage',
      name: '광폭화',
      kind: 'buff',
      requiredLevel: 30,
      cooldownMs: 16000,
      multiplier: 1,
      range: 0,
      icon: '🔥',
      buffStat: 'atk',
      buffMultiplier: 1.7,
      durationMs: 6000,
    },
    { id: 'w_finish', name: '필살의일격', kind: 'single', requiredLevel: 40, cooldownMs: 6000, multiplier: 3.6, range: 75, icon: '⚔️' },
    {
      id: 'w_invuln',
      name: '무적의방패',
      kind: 'buff',
      requiredLevel: 50,
      cooldownMs: 20000,
      multiplier: 1,
      range: 0,
      icon: '🔰',
      buffStat: 'def',
      buffMultiplier: 2.6,
      durationMs: 6000,
    },
    { id: 'w_ultimate', name: '검신강림', kind: 'aoe', requiredLevel: 60, cooldownMs: 12000, multiplier: 3.0, range: 110, icon: '🌟' },
  ],
  rogue: [
    { id: 'r_stab', name: '급소찌르기', kind: 'single', requiredLevel: 1, cooldownMs: 3200, multiplier: 2.1, range: 60, icon: '🗡️' },
    { id: 'r_flurry', name: '연속베기', kind: 'aoe', requiredLevel: 5, cooldownMs: 7000, multiplier: 1.3, range: 70, icon: '🌪️' },
    {
      id: 'r_haste',
      name: '그림자질주',
      kind: 'buff',
      requiredLevel: 10,
      cooldownMs: 13000,
      multiplier: 1,
      range: 0,
      icon: '💨',
      buffStat: 'atk',
      buffMultiplier: 1.5,
      durationMs: 5000,
    },
    { id: 'r_poison', name: '독날림', kind: 'single', requiredLevel: 15, cooldownMs: 3800, multiplier: 2.3, range: 80, icon: '🧪' },
    { id: 'r_clones', name: '그림자분신', kind: 'aoe', requiredLevel: 20, cooldownMs: 8500, multiplier: 1.6, range: 85, icon: '👥' },
    { id: 'r_assassinate', name: '암살', kind: 'single', requiredLevel: 25, cooldownMs: 5500, multiplier: 3.0, range: 55, icon: '🔪' },
    {
      id: 'r_stealth',
      name: '은신',
      kind: 'buff',
      requiredLevel: 30,
      cooldownMs: 15000,
      multiplier: 1,
      range: 0,
      icon: '🌑',
      buffStat: 'critRate',
      buffMultiplier: 2.2,
      durationMs: 5000,
    },
    { id: 'r_bladestorm', name: '칼날폭풍', kind: 'aoe', requiredLevel: 40, cooldownMs: 9500, multiplier: 2.0, range: 90, icon: '🌀' },
    { id: 'r_execute', name: '처형', kind: 'single', requiredLevel: 50, cooldownMs: 6500, multiplier: 3.8, range: 60, icon: '💀' },
    { id: 'r_ultimate', name: '천개의칼날', kind: 'aoe', requiredLevel: 60, cooldownMs: 12000, multiplier: 2.8, range: 100, icon: '🌟' },
  ],
  archer: [
    { id: 'a_snipe', name: '저격', kind: 'single', requiredLevel: 1, cooldownMs: 4500, multiplier: 2.8, range: 130, icon: '🎯' },
    { id: 'a_rain', name: '화살비', kind: 'aoe', requiredLevel: 5, cooldownMs: 8500, multiplier: 1.4, range: 110, icon: '🏹' },
    {
      id: 'a_focus',
      name: '집중조준',
      kind: 'buff',
      requiredLevel: 10,
      cooldownMs: 14000,
      multiplier: 1,
      range: 0,
      icon: '🔍',
      buffStat: 'critRate',
      buffMultiplier: 2.0,
      durationMs: 5000,
    },
    { id: 'a_pierce', name: '관통사격', kind: 'single', requiredLevel: 15, cooldownMs: 4800, multiplier: 2.9, range: 140, icon: '➶' },
    { id: 'a_multi', name: '다중사격', kind: 'aoe', requiredLevel: 20, cooldownMs: 9000, multiplier: 1.7, range: 115, icon: '🏹' },
    { id: 'a_poison', name: '독화살', kind: 'single', requiredLevel: 25, cooldownMs: 5200, multiplier: 3.1, range: 125, icon: '☠️' },
    {
      id: 'a_eagle',
      name: '매의눈',
      kind: 'buff',
      requiredLevel: 30,
      cooldownMs: 16000,
      multiplier: 1,
      range: 0,
      icon: '🦅',
      buffStat: 'critRate',
      buffMultiplier: 2.6,
      durationMs: 6000,
    },
    { id: 'a_explosive', name: '폭발화살', kind: 'aoe', requiredLevel: 40, cooldownMs: 9800, multiplier: 2.1, range: 120, icon: '💥' },
    { id: 'a_killshot', name: '필살의화살', kind: 'single', requiredLevel: 50, cooldownMs: 6800, multiplier: 3.9, range: 150, icon: '🎯' },
    { id: 'a_ultimate', name: '유성우', kind: 'aoe', requiredLevel: 60, cooldownMs: 12500, multiplier: 3.0, range: 130, icon: '🌟' },
  ],
  mage: [
    { id: 'm_bolt', name: '파이어볼', kind: 'single', requiredLevel: 1, cooldownMs: 3800, multiplier: 2.6, range: 110, icon: '🔥' },
    { id: 'm_nova', name: '블리자드', kind: 'aoe', requiredLevel: 5, cooldownMs: 9000, multiplier: 1.6, range: 100, icon: '❄️' },
    {
      id: 'm_shield',
      name: '마나실드',
      kind: 'buff',
      requiredLevel: 10,
      cooldownMs: 15000,
      multiplier: 1,
      range: 0,
      icon: '🔮',
      buffStat: 'def',
      buffMultiplier: 2.2,
      durationMs: 5000,
    },
    { id: 'm_lightning', name: '라이트닝볼트', kind: 'single', requiredLevel: 15, cooldownMs: 4200, multiplier: 2.9, range: 115, icon: '⚡' },
    { id: 'm_meteor', name: '메테오', kind: 'aoe', requiredLevel: 20, cooldownMs: 9500, multiplier: 1.9, range: 105, icon: '☄️' },
    { id: 'm_icespear', name: '아이스스피어', kind: 'single', requiredLevel: 25, cooldownMs: 4600, multiplier: 3.2, range: 120, icon: '🧊' },
    {
      id: 'm_barrier',
      name: '아케인배리어',
      kind: 'buff',
      requiredLevel: 30,
      cooldownMs: 16000,
      multiplier: 1,
      range: 0,
      icon: '🟣',
      buffStat: 'def',
      buffMultiplier: 2.8,
      durationMs: 6000,
    },
    { id: 'm_firestorm', name: '파이어스톰', kind: 'aoe', requiredLevel: 40, cooldownMs: 10000, multiplier: 2.3, range: 110, icon: '🌋' },
    { id: 'm_holy', name: '홀리스매시', kind: 'single', requiredLevel: 50, cooldownMs: 7000, multiplier: 4.0, range: 100, icon: '✨' },
    { id: 'm_ultimate', name: '아포칼립스', kind: 'aoe', requiredLevel: 60, cooldownMs: 13000, multiplier: 3.2, range: 120, icon: '🌟' },
  ],
};
