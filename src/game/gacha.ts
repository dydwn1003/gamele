import { EquipmentItem, EquipmentSlot, Rarity } from './types';
import { rollEquipment } from './equipment';

export const GACHA_COST_GEMS = 50;

const RARITY_RATES: { rarity: Rarity; weight: number }[] = [
  { rarity: 'normal', weight: 60 },
  { rarity: 'rare', weight: 30 },
  { rarity: 'epic', weight: 9 },
  { rarity: 'legendary', weight: 1 },
];

const SLOTS: EquipmentSlot[] = ['weapon', 'armor', 'accessory'];

function pickRarity(): Rarity {
  const total = RARITY_RATES.reduce((sum, r) => sum + r.weight, 0);
  let roll = Math.random() * total;
  for (const entry of RARITY_RATES) {
    if (roll < entry.weight) return entry.rarity;
    roll -= entry.weight;
  }
  return 'normal';
}

export function pullGacha(): EquipmentItem {
  const slot = SLOTS[Math.floor(Math.random() * SLOTS.length)];
  const rarity = pickRarity();
  return rollEquipment(slot, rarity);
}

const RARITY_ORDER: Rarity[] = ['normal', 'rare', 'epic', 'legendary'];

/** Boss rewards: roll normally but never below the raid's guaranteed floor. */
export function pullBossReward(minRarity: Rarity): EquipmentItem {
  const slot = SLOTS[Math.floor(Math.random() * SLOTS.length)];
  const rolled = pickRarity();
  const rarity =
    RARITY_ORDER.indexOf(rolled) < RARITY_ORDER.indexOf(minRarity) ? minRarity : rolled;
  return rollEquipment(slot, rarity);
}
