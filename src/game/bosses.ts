import { getStage, STAGES } from './stages';
import { Rarity, StageConfig } from './types';

export const CHAPTER_COUNT = Math.ceil(STAGES.length / 10);

export interface BossConfig extends StageConfig {
  chapter: number;
  gemReward: number;
  guaranteedRarity: Rarity;
}

const GUARANTEED_RARITY_BY_CHAPTER: Rarity[] = ['rare', 'rare', 'epic', 'epic', 'legendary', 'legendary'];

function makeBoss(chapter: number): BossConfig {
  const referenceStage = getStage(chapter * 10);
  return {
    ...referenceStage,
    id: chapter,
    chapter,
    name: `${chapter}장 레이드`,
    enemyStats: {
      atk: Math.round(referenceStage.enemyStats.atk * 1.7),
      hp: Math.round(referenceStage.enemyStats.hp * 2.6),
      def: Math.round(referenceStage.enemyStats.def * 1.5),
      critRate: 0.08,
    },
    goldReward: Math.round(referenceStage.goldReward * 4),
    gemReward: 15 + chapter * 5,
    expReward: Math.round(referenceStage.expReward * 3),
    guaranteedRarity: GUARANTEED_RARITY_BY_CHAPTER[chapter - 1] ?? 'rare',
  };
}

export const BOSSES: BossConfig[] = Array.from({ length: CHAPTER_COUNT }, (_, i) => makeBoss(i + 1));

export function getBoss(chapter: number): BossConfig {
  return BOSSES[Math.min(Math.max(chapter, 1), BOSSES.length) - 1];
}
