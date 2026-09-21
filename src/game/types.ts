export type Rarity = 'normal' | 'rare' | 'epic' | 'legendary';

export type EquipmentSlot = 'weapon' | 'armor' | 'accessory';

export interface StatBlock {
  atk: number;
  hp: number;
  def: number;
  critRate: number; // 0..1
}

export interface EquipmentItem {
  id: string;
  slot: EquipmentSlot;
  rarity: Rarity;
  name: string;
  stats: StatBlock;
}

export interface StageConfig {
  id: number;
  name: string;
  enemyName: string;
  enemyStats: StatBlock;
  goldReward: number;
  expReward: number;
  idleGoldPerSec: number;
}

export interface HeroProgress {
  level: number;
  exp: number;
}

export interface BattleResult {
  won: boolean;
  ticks: number;
  goldEarned: number;
  expEarned: number;
}
