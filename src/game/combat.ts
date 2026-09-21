import { BattleResult, StageConfig, StatBlock } from './types';

const MAX_TICKS = 200;

function rollDamage(attacker: StatBlock, defender: StatBlock): number {
  const isCrit = Math.random() < attacker.critRate;
  const raw = Math.max(1, attacker.atk - defender.def * 0.5);
  return Math.round(isCrit ? raw * 1.75 : raw);
}

/**
 * One auto-battle round: hero and enemy trade hits every tick until someone
 * drops to 0 HP or MAX_TICKS is hit (treated as a loss to avoid stalemates).
 */
export function simulateBattle(hero: StatBlock, stage: StageConfig): BattleResult {
  let heroHp = hero.hp;
  let enemyHp = stage.enemyStats.hp;
  let ticks = 0;

  while (heroHp > 0 && enemyHp > 0 && ticks < MAX_TICKS) {
    ticks += 1;
    enemyHp -= rollDamage(hero, stage.enemyStats);
    if (enemyHp <= 0) break;
    heroHp -= rollDamage(stage.enemyStats, hero);
  }

  const won = enemyHp <= 0 && heroHp > 0;
  return {
    won,
    ticks,
    goldEarned: won ? stage.goldReward : Math.round(stage.goldReward * 0.2),
    expEarned: won ? stage.expReward : Math.round(stage.expReward * 0.2),
  };
}

/** Idle/offline gold accrued while the app was closed, capped so long absences don't dominate. */
export function calculateOfflineGold(idleGoldPerSec: number, elapsedMs: number): number {
  const MAX_OFFLINE_HOURS = 8;
  const cappedSeconds = Math.min(elapsedMs / 1000, MAX_OFFLINE_HOURS * 3600);
  return Math.round(idleGoldPerSec * cappedSeconds);
}
