import { ClassId, EquipmentItem, EquipmentSlot, Rarity } from './types';
import { rollEquipment } from './equipment';

export const GACHA_COST_GEMS = 50;
export const GACHA_COST_GEMS_TEN = 450; // 10% off a straight 10x

const RARITY_RATES: { rarity: Rarity; weight: number }[] = [
  { rarity: 'normal', weight: 60 },
  { rarity: 'rare', weight: 30 },
  { rarity: 'epic', weight: 9 },
  { rarity: 'legendary', weight: 1 },
];

const SLOTS: EquipmentSlot[] = ['weapon', 'armor', 'offhand', 'shoes', 'ring', 'necklace'];

const RARITY_ORDER: Rarity[] = ['normal', 'rare', 'epic', 'legendary'];

function pickRarity(): Rarity {
  const total = RARITY_RATES.reduce((sum, r) => sum + r.weight, 0);
  let roll = Math.random() * total;
  for (const entry of RARITY_RATES) {
    if (roll < entry.weight) return entry.rarity;
    roll -= entry.weight;
  }
  return 'normal';
}

function pickSlot(): EquipmentSlot {
  return SLOTS[Math.floor(Math.random() * SLOTS.length)];
}

export function pullGacha(classId: ClassId): EquipmentItem {
  return rollEquipment(classId, pickSlot(), pickRarity());
}

/** 10-pull with a pity rule: if every roll came back normal, the last slot is upgraded to rare. */
export function pullGachaTen(classId: ClassId): EquipmentItem[] {
  const results = Array.from({ length: 10 }, () => ({ slot: pickSlot(), rarity: pickRarity() }));
  const hasRarePlus = results.some((r) => r.rarity !== 'normal');
  if (!hasRarePlus) {
    results[results.length - 1].rarity = 'rare';
  }
  return results.map((r) => rollEquipment(classId, r.slot, r.rarity));
}

/** Boss rewards: roll normally but never below the raid's guaranteed floor. */
export function pullBossReward(classId: ClassId, minRarity: Rarity): EquipmentItem {
  const rolled = pickRarity();
  const rarity =
    RARITY_ORDER.indexOf(rolled) < RARITY_ORDER.indexOf(minRarity) ? minRarity : rolled;
  return rollEquipment(classId, pickSlot(), rarity);
}
