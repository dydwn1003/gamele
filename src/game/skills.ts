import { ClassId, StatBlock } from './types';

export type SkillKind = 'single' | 'aoe' | 'buff';

export interface SkillConfig {
  id: string;
  name: string;
  kind: SkillKind;
  cooldownMs: number;
  multiplier: number;
  range: number;
  icon: string;
  /** buff-only: which combat stat is temporarily multiplied, and for how long. */
  buffStat?: keyof StatBlock;
  buffMultiplier?: number;
  durationMs?: number;
}

export const CLASS_SKILLS: Record<ClassId, SkillConfig[]> = {
  warrior: [
    { id: 'w_strike', name: '강타', kind: 'single', cooldownMs: 4000, multiplier: 2.4, range: 70, icon: '💥' },
    { id: 'w_whirl', name: '회전베기', kind: 'aoe', cooldownMs: 8000, multiplier: 1.5, range: 90, icon: '🌀' },
    {
      id: 'w_guard',
      name: '철벽의지',
      kind: 'buff',
      cooldownMs: 14000,
      multiplier: 1,
      range: 0,
      icon: '🛡️',
      buffStat: 'def',
      buffMultiplier: 1.8,
      durationMs: 5000,
    },
  ],
  rogue: [
    { id: 'r_stab', name: '급소찌르기', kind: 'single', cooldownMs: 3200, multiplier: 2.1, range: 60, icon: '🗡️' },
    { id: 'r_flurry', name: '연속베기', kind: 'aoe', cooldownMs: 7000, multiplier: 1.3, range: 70, icon: '🌪️' },
    {
      id: 'r_haste',
      name: '그림자질주',
      kind: 'buff',
      cooldownMs: 13000,
      multiplier: 1,
      range: 0,
      icon: '💨',
      buffStat: 'atk',
      buffMultiplier: 1.5,
      durationMs: 5000,
    },
  ],
  archer: [
    { id: 'a_snipe', name: '저격', kind: 'single', cooldownMs: 4500, multiplier: 2.8, range: 130, icon: '🎯' },
    { id: 'a_rain', name: '화살비', kind: 'aoe', cooldownMs: 8500, multiplier: 1.4, range: 110, icon: '🏹' },
    {
      id: 'a_focus',
      name: '집중조준',
      kind: 'buff',
      cooldownMs: 14000,
      multiplier: 1,
      range: 0,
      icon: '🔍',
      buffStat: 'critRate',
      buffMultiplier: 2.0,
      durationMs: 5000,
    },
  ],
  mage: [
    { id: 'm_bolt', name: '파이어볼', kind: 'single', cooldownMs: 3800, multiplier: 2.6, range: 110, icon: '🔥' },
    { id: 'm_nova', name: '블리자드', kind: 'aoe', cooldownMs: 9000, multiplier: 1.6, range: 100, icon: '❄️' },
    {
      id: 'm_shield',
      name: '마나실드',
      kind: 'buff',
      cooldownMs: 15000,
      multiplier: 1,
      range: 0,
      icon: '🔮',
      buffStat: 'def',
      buffMultiplier: 2.2,
      durationMs: 5000,
    },
  ],
};
