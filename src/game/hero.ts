import { effectiveItemStats } from './equipment';
import { ClassId, EquipmentItem, HeroProgress, PrimaryStats, StatBlock } from './types';

export const STAT_POINTS_PER_LEVEL = 5;

export const CLASS_BASE_PRIMARY: Record<ClassId, PrimaryStats> = {
  warrior: { str: 12, agi: 6, int: 4, vit: 13 },
  rogue: { str: 7, agi: 14, int: 5, vit: 9 },
  archer: { str: 6, agi: 13, int: 6, vit: 9 },
  mage: { str: 4, agi: 6, int: 15, vit: 8 },
};

export const CLASS_GROWTH_PER_LEVEL: Record<ClassId, PrimaryStats> = {
  warrior: { str: 2.4, agi: 0.9, int: 0.5, vit: 2.2 },
  rogue: { str: 1.1, agi: 2.6, int: 0.7, vit: 1.4 },
  archer: { str: 1.0, agi: 2.4, int: 0.8, vit: 1.4 },
  mage: { str: 0.5, agi: 0.9, int: 2.7, vit: 1.2 },
};

/** Suggested weights for "auto-allocate" — where each class wants its free points. */
export const CLASS_AUTO_WEIGHTS: Record<ClassId, PrimaryStats> = {
  warrior: { str: 0.5, agi: 0.15, int: 0.05, vit: 0.3 },
  rogue: { str: 0.15, agi: 0.55, int: 0.05, vit: 0.25 },
  archer: { str: 0.15, agi: 0.55, int: 0.05, vit: 0.25 },
  mage: { str: 0.05, agi: 0.15, int: 0.55, vit: 0.25 },
};

export const CLASS_NAME: Record<ClassId, string> = {
  warrior: '전사',
  rogue: '도적',
  archer: '궁수',
  mage: '마법사',
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

export function primaryStatsAtLevel(
  classId: ClassId,
  level: number,
  allocated: PrimaryStats
): PrimaryStats {
  const base = CLASS_BASE_PRIMARY[classId];
  const growth = CLASS_GROWTH_PER_LEVEL[classId];
  const g = level - 1;
  return {
    str: base.str + growth.str * g + allocated.str,
    agi: base.agi + growth.agi * g + allocated.agi,
    int: base.int + growth.int * g + allocated.int,
    vit: base.vit + growth.vit * g + allocated.vit,
  };
}

/** Converts a class's primary stats into the combat stat block. Each class
 * leans on a different primary stat for damage, matching its playstyle. */
export function derivedStats(classId: ClassId, p: PrimaryStats): StatBlock {
  switch (classId) {
    case 'warrior':
      return {
        atk: 4 + p.str * 2.2,
        hp: 90 + p.vit * 11,
        def: 2 + p.vit * 1.4 + p.str * 0.2,
        critRate: 0.04 + p.agi * 0.002,
      };
    case 'rogue':
      return {
        atk: 3 + p.agi * 1.9 + p.str * 0.5,
        hp: 78 + p.vit * 8.5,
        def: 1.5 + p.vit * 0.9,
        critRate: 0.1 + p.agi * 0.004,
      };
    case 'archer':
      return {
        atk: 3 + p.agi * 1.7 + p.str * 0.4,
        hp: 80 + p.vit * 9,
        def: 1.8 + p.vit * 1.0,
        critRate: 0.08 + p.agi * 0.0035,
      };
    case 'mage':
      return {
        atk: 2 + p.int * 2.3,
        hp: 68 + p.vit * 7.5,
        def: 1.2 + p.vit * 0.7 + p.int * 0.15,
        critRate: 0.05 + p.agi * 0.0015 + p.int * 0.001,
      };
  }
}

export function totalStats(
  classId: ClassId,
  level: number,
  allocated: PrimaryStats,
  equipped: EquipmentItem[]
): StatBlock {
  const primary = primaryStatsAtLevel(classId, level, allocated);
  const base = derivedStats(classId, primary);
  return equipped.reduce<StatBlock>((acc, item) => {
    const bonus = effectiveItemStats(item);
    return {
      atk: acc.atk + bonus.atk,
      hp: acc.hp + bonus.hp,
      def: acc.def + bonus.def,
      critRate: Math.min(0.75, acc.critRate + bonus.critRate),
    };
  }, base);
}

export function powerScore(stats: StatBlock): number {
  return Math.round(stats.atk * 3.5 + stats.hp * 0.6 + stats.def * 4 + stats.critRate * 100);
}
