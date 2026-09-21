import { ClassId, EquipmentItem, EquipmentSlot, Rarity, StatBlock } from './types';

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

const RARITY_ADJECTIVE: Record<Rarity, string> = {
  normal: '',
  rare: '정예의 ',
  epic: '영웅의 ',
  legendary: '전설의 ',
};

/** Per-class flavor label for each slot, shown in UI (an archer's "offhand" is a quiver, a mage's is a grimoire, etc). */
export const SLOT_LABEL_BY_CLASS: Record<ClassId, Record<EquipmentSlot, string>> = {
  warrior: { weapon: '무기', armor: '갑옷', offhand: '방패', shoes: '신발', ring: '반지', necklace: '목걸이' },
  rogue: { weapon: '무기', armor: '경갑', offhand: '보조무기', shoes: '신발', ring: '반지', necklace: '목걸이' },
  archer: { weapon: '무기', armor: '경갑', offhand: '화살통', shoes: '신발', ring: '반지', necklace: '목걸이' },
  mage: { weapon: '무기', armor: '로브', offhand: '마도서', shoes: '신발', ring: '반지', necklace: '목걸이' },
};

const NAME_POOL: Record<ClassId, Record<EquipmentSlot, string[]>> = {
  warrior: {
    weapon: ['장검', '대검'],
    armor: ['판금 갑옷', '기사의 흉갑'],
    offhand: ['철제 방패', '수호의 방패'],
    shoes: ['강철 부츠', '전투화'],
    ring: ['용맹의 반지', '철의 인장'],
    necklace: ['용기의 목걸이', '전쟁 펜던트'],
  },
  rogue: {
    weapon: ['쌍단검', '곡도'],
    armor: ['가죽 갑옷', '그림자 슈트'],
    offhand: ['보조 단검', '독침'],
    shoes: ['그림자 신발', '신속의 부츠'],
    ring: ['암살자의 반지', '독니 반지'],
    necklace: ['그림자 목걸이', '잠행의 펜던트'],
  },
  archer: {
    weapon: ['장궁', '단궁'],
    armor: ['사냥꾼 조끼', '바람의 로브'],
    offhand: ['정밀 화살통', '매의 깃털 화살통'],
    shoes: ['추적자의 신발', '바람의 부츠'],
    ring: ['조준의 반지', '매의 눈 반지'],
    necklace: ['바람의 목걸이', '사냥꾼 펜던트'],
  },
  mage: {
    weapon: ['지팡이', '룬 완드'],
    armor: ['현자의 로브', '비전 로브'],
    offhand: ['고대 마도서', '수정 구슬'],
    shoes: ['비전의 신발', '현자의 슬리퍼'],
    ring: ['마력의 반지', '원소의 반지'],
    necklace: ['비전 목걸이', '현자의 펜던트'],
  },
};

function baseStatForSlot(classId: ClassId, slot: EquipmentSlot): StatBlock {
  switch (slot) {
    case 'weapon':
      return classId === 'mage'
        ? { atk: 6, hp: 0, def: 0, critRate: 0.005 }
        : { atk: 5, hp: 0, def: 0, critRate: 0.01 };
    case 'armor':
      return { atk: 0, hp: 24, def: 2.4, critRate: 0 };
    case 'offhand':
      if (classId === 'warrior') return { atk: 0, hp: 12, def: 3, critRate: 0 };
      if (classId === 'mage') return { atk: 3, hp: 6, def: 0, critRate: 0.01 };
      return { atk: 2, hp: 4, def: 0, critRate: 0.025 }; // rogue/archer: crit-focused
    case 'shoes':
      return { atk: 0, hp: 8, def: 0.6, critRate: 0.01 };
    case 'ring':
      return { atk: 2, hp: 0, def: 0, critRate: 0.015 };
    case 'necklace':
      return { atk: 1, hp: 10, def: 0, critRate: 0.005 };
  }
}

let idCounter = 0;

export function rollEquipment(classId: ClassId, slot: EquipmentSlot, rarity: Rarity): EquipmentItem {
  idCounter += 1;
  const mult = RARITY_MULTIPLIER[rarity];
  const base = baseStatForSlot(classId, slot);
  const variants = NAME_POOL[classId][slot];
  const variant = variants[Math.floor(Math.random() * variants.length)];
  return {
    id: `${Date.now()}-${idCounter}`,
    slot,
    rarity,
    classId,
    name: `${RARITY_ADJECTIVE[rarity]}${variant}`,
    enhanceLevel: 0,
    stats: {
      atk: Math.round(base.atk * mult),
      hp: Math.round(base.hp * mult),
      def: Math.round(base.def * mult * 10) / 10,
      critRate: Number((base.critRate * mult).toFixed(3)),
    },
  };
}

export const ENHANCE_MAX_LEVEL = 10;
export const ENHANCE_BONUS_PER_LEVEL = 0.08;

export function enhanceMultiplier(level: number): number {
  return 1 + level * ENHANCE_BONUS_PER_LEVEL;
}

export function enhanceCost(item: Pick<EquipmentItem, 'rarity' | 'enhanceLevel'>): number {
  return Math.round(30 * RARITY_MULTIPLIER[item.rarity] * Math.pow(1.5, item.enhanceLevel));
}

/** An item's stats after applying its enhancement level bonus. */
export function effectiveItemStats(item: EquipmentItem): StatBlock {
  const mult = enhanceMultiplier(item.enhanceLevel);
  return {
    atk: item.stats.atk * mult,
    hp: item.stats.hp * mult,
    def: item.stats.def * mult,
    critRate: item.stats.critRate * mult,
  };
}
