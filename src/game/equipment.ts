import { EquipmentItem, EquipmentSlot, Rarity, StatBlock } from './types';

export const RARITY_ORDER: Rarity[] = ['normal', 'rare', 'epic', 'legendary'];

export const RARITY_MULTIPLIER: Record<Rarity, number> = {
  normal: 1,
  rare: 1.8,
  epic: 3.2,
  legendary: 6,
};

export const RARITY_LABEL: Record<Rarity, string> = {
  normal: '일반',
  rare: '레어',
  epic: '에픽',
  legendary: '전설',
};

const SLOT_NAMES: Record<EquipmentSlot, string[]> = {
  weapon: ['낡은 검', '강철 검', '용아검', '태초의 검'],
  armor: ['천 갑옷', '가죽 갑옷', '판금 갑옷', '용비늘 갑옷'],
  accessory: ['나무 반지', '은 목걸이', '마법 부적', '고대의 인장'],
};

function baseStatForSlot(slot: EquipmentSlot): StatBlock {
  switch (slot) {
    case 'weapon':
      return { atk: 4, hp: 0, def: 0, critRate: 0.01 };
    case 'armor':
      return { atk: 0, hp: 20, def: 2, critRate: 0 };
    case 'accessory':
      return { atk: 1, hp: 6, def: 0, critRate: 0.02 };
  }
}

let idCounter = 0;

export function rollEquipment(slot: EquipmentSlot, rarity: Rarity): EquipmentItem {
  idCounter += 1;
  const mult = RARITY_MULTIPLIER[rarity];
  const base = baseStatForSlot(slot);
  const name = SLOT_NAMES[slot][RARITY_ORDER.indexOf(rarity)];
  return {
    id: `${Date.now()}-${idCounter}`,
    slot,
    rarity,
    name,
    stats: {
      atk: Math.round(base.atk * mult),
      hp: Math.round(base.hp * mult),
      def: Math.round(base.def * mult),
      critRate: Number((base.critRate * mult).toFixed(3)),
    },
  };
}
