export type SkillKind = 'single' | 'aoe';

export interface SkillConfig {
  id: string;
  name: string;
  kind: SkillKind;
  cooldownMs: number;
  multiplier: number;
  range: number;
  icon: string;
}

export const SKILLS: SkillConfig[] = [
  {
    id: 'power_strike',
    name: '강타',
    kind: 'single',
    cooldownMs: 4000,
    multiplier: 2.4,
    range: 70,
    icon: '💥',
  },
  {
    id: 'whirlwind',
    name: '회전베기',
    kind: 'aoe',
    cooldownMs: 8000,
    multiplier: 1.5,
    range: 90,
    icon: '🌀',
  },
];
