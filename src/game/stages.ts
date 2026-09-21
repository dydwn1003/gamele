import { StageConfig } from './types';

const STAGE_COUNT = 60;

function makeStage(id: number): StageConfig {
  // Gentle exponential ramp so early stages are quick wins and later ones
  // require real gear/level investment.
  const scale = Math.pow(1.16, id - 1);
  return {
    id,
    name: `${Math.ceil(id / 10)}-${((id - 1) % 10) + 1}`,
    enemyName: id % 10 === 0 ? '보스 슬라임' : '들개',
    enemyStats: {
      atk: Math.round(8 * scale),
      hp: Math.round(40 * scale * (id % 10 === 0 ? 4 : 1)),
      def: Math.round(2 * scale),
      critRate: 0.05,
    },
    goldReward: Math.round(10 * scale),
    expReward: Math.round(6 * scale),
    idleGoldPerSec: Math.round(1 * scale) / 4,
  };
}

export const STAGES: StageConfig[] = Array.from({ length: STAGE_COUNT }, (_, i) =>
  makeStage(i + 1)
);

export function getStage(id: number): StageConfig {
  return STAGES[Math.min(Math.max(id, 1), STAGES.length) - 1];
}
