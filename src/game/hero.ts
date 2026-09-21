import { EquipmentItem, HeroProgress, StatBlock } from './types';

export const BASE_STATS: StatBlock = {
  atk: 10,
  hp: 100,
  def: 3,
  critRate: 0.05,
};

export function expToNextLevel(level: number): number {
  return Math.round(20 * Math.pow(1.12, level - 1));
}

export function applyExp(progress: HeroProgress, gained: number): HeroProgress {
  let { level, exp } = progress;
  exp += gained;
  let needed = expToNextLevel(level);
  while (exp >= needed) {
    exp -= needed;
    level += 1;
    needed = expToNextLevel(level);
  }
  return { level, exp };
}

export function statsAtLevel(level: number): StatBlock {
  const growth = level - 1;
  return {
    atk: BASE_STATS.atk + growth * 2.4,
    hp: BASE_STATS.hp + growth * 14,
    def: BASE_STATS.def + growth * 0.8,
    critRate: BASE_STATS.critRate,
  };
}

export function totalStats(level: number, equipped: EquipmentItem[]): StatBlock {
  const base = statsAtLevel(level);
  return equipped.reduce<StatBlock>(
    (acc, item) => ({
      atk: acc.atk + item.stats.atk,
      hp: acc.hp + item.stats.hp,
      def: acc.def + item.stats.def,
      critRate: Math.min(0.6, acc.critRate + item.stats.critRate),
    }),
    base
  );
}

export function powerScore(stats: StatBlock): number {
  return Math.round(stats.atk * 3.5 + stats.hp * 0.6 + stats.def * 4 + stats.critRate * 100);
}
