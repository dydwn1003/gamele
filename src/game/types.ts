export type Rarity = 'normal' | 'rare' | 'epic' | 'legendary';

export type EquipmentSlot = 'weapon' | 'armor' | 'offhand' | 'shoes' | 'ring' | 'necklace';

export type ClassId = 'warrior' | 'rogue' | 'archer' | 'mage';

export interface StatBlock {
  atk: number;
  hp: number;
  def: number;
  critRate: number; // 0..1
}

export interface PrimaryStats {
  str: number;
  agi: number;
  int: number;
  vit: number;
}

export interface EquipmentItem {
  id: string;
  slot: EquipmentSlot;
  rarity: Rarity;
  classId: ClassId;
  name: string;
  stats: StatBlock;
  enhanceLevel: number;
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
