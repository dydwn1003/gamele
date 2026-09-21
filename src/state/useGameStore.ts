import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import { getBoss } from '../game/bosses';
import { calculateOfflineGold, simulateBattle } from '../game/combat';
import { enhanceCost, ENHANCE_MAX_LEVEL } from '../game/equipment';
import { pullBossReward, pullGacha as rollGacha, pullGachaTen as rollGachaTen } from '../game/gacha';
import {
  applyExp,
  CLASS_AUTO_WEIGHTS,
  STAT_POINTS_PER_LEVEL,
  totalStats,
  powerScore,
} from '../game/hero';
import { getStage, STAGES } from '../game/stages';
import { ClassId, EquipmentItem, EquipmentSlot, PrimaryStats } from '../game/types';

type EquippedMap = Record<EquipmentSlot, EquipmentItem | null>;

export const MAX_BOSS_TICKETS = 3;
export const BOSS_TICKET_REFILL_MS = 3 * 60 * 60 * 1000; // one ticket every 3h
export const RESPEC_GOLD_COST = 150;

const INITIAL_EQUIPPED: EquippedMap = {
  weapon: null,
  armor: null,
  offhand: null,
  shoes: null,
  ring: null,
  necklace: null,
};
const ZERO_STATS: PrimaryStats = { str: 0, agi: 0, int: 0, vit: 0 };

interface GameState {
  classId: ClassId | null;
  gold: number;
  gems: number;
  heroLevel: number;
  heroExp: number;
  statPoints: number;
  allocatedStats: PrimaryStats;
  currentStage: number;
  highestStageCleared: number;
  inventory: EquipmentItem[];
  equipped: EquippedMap;
  lastActiveAt: number;
  pendingOfflineGold: number;
  bossTickets: number;
  lastTicketRefillAt: number;

  chooseClass: (classId: ClassId) => void;
  gainKillReward: (gold: number, exp: number) => void;
  advanceStage: () => void;
  fightBoss: (chapter: number) => {
    won: boolean;
    goldEarned: number;
    gemsEarned: number;
    item: EquipmentItem | null;
  } | null;
  pullGacha: () => EquipmentItem | null;
  pullGachaTen: () => EquipmentItem[] | null;
  equipItem: (item: EquipmentItem) => void;
  unequipItem: (slot: EquipmentSlot) => void;
  enhanceItem: (itemId: string) => boolean;
  allocateStat: (stat: keyof PrimaryStats, amount?: number) => void;
  autoAllocateStats: () => void;
  respecStats: () => boolean;
  addGems: (amount: number) => void;
  claimOfflineGold: () => void;
  syncOfflineProgress: () => void;
  syncBossTickets: () => void;
  heroPower: () => number;
}

function equippedList(equipped: EquippedMap): EquipmentItem[] {
  return Object.values(equipped).filter((i): i is EquipmentItem => i !== null);
}

export const useGameStore = create<GameState>()(
  persist(
    (set, get) => ({
      classId: null,
      gold: 0,
      gems: 100,
      heroLevel: 1,
      heroExp: 0,
      statPoints: 0,
      allocatedStats: ZERO_STATS,
      currentStage: 1,
      highestStageCleared: 0,
      inventory: [],
      equipped: INITIAL_EQUIPPED,
      lastActiveAt: Date.now(),
      pendingOfflineGold: 0,
      bossTickets: MAX_BOSS_TICKETS,
      lastTicketRefillAt: Date.now(),

      chooseClass: (classId) => {
        if (get().classId) return; // one-time choice
        set({ classId });
      },

      heroPower: () => {
        const s = get();
        if (!s.classId) return 0;
        return powerScore(totalStats(s.classId, s.heroLevel, s.allocatedStats, equippedList(s.equipped)));
      },

      gainKillReward: (gold, exp) => {
        const s = get();
        const before = s.heroLevel;
        const { level, exp: newExp } = applyExp({ level: s.heroLevel, exp: s.heroExp }, exp);
        const levelsGained = level - before;
        set({
          gold: s.gold + gold,
          heroLevel: level,
          heroExp: newExp,
          statPoints: s.statPoints + levelsGained * STAT_POINTS_PER_LEVEL,
        });
      },

      advanceStage: () => {
        const s = get();
        const nextStage = Math.min(s.currentStage + 1, STAGES.length);
        set({
          currentStage: nextStage,
          highestStageCleared: Math.max(s.highestStageCleared, s.currentStage),
        });
      },

      fightBoss: (chapter) => {
        const s = get();
        if (s.bossTickets <= 0 || !s.classId) return null;

        const boss = getBoss(chapter);
        const stats = totalStats(s.classId, s.heroLevel, s.allocatedStats, equippedList(s.equipped));
        const result = simulateBattle(stats, boss);
        const before = s.heroLevel;
        const { level, exp } = applyExp({ level: s.heroLevel, exp: s.heroExp }, result.expEarned);
        const levelsGained = level - before;

        const goldEarned = result.won ? boss.goldReward : Math.round(boss.goldReward * 0.15);
        const gemsEarned = result.won ? boss.gemReward : 0;
        const item = result.won ? pullBossReward(s.classId, boss.guaranteedRarity) : null;

        set({
          gold: s.gold + goldEarned,
          gems: s.gems + gemsEarned,
          heroLevel: level,
          heroExp: exp,
          statPoints: s.statPoints + levelsGained * STAT_POINTS_PER_LEVEL,
          bossTickets: s.bossTickets - 1,
          inventory: item ? [...s.inventory, item] : s.inventory,
        });

        return { won: result.won, goldEarned, gemsEarned, item };
      },

      pullGacha: () => {
        const s = get();
        if (!s.classId || s.gems < 50) return null;
        const item = rollGacha(s.classId);
        set({ gems: s.gems - 50, inventory: [...s.inventory, item] });
        return item;
      },

      pullGachaTen: () => {
        const s = get();
        const COST = 450;
        if (!s.classId || s.gems < COST) return null;
        const items = rollGachaTen(s.classId);
        set({ gems: s.gems - COST, inventory: [...s.inventory, ...items] });
        return items;
      },

      equipItem: (item) => {
        const s = get();
        if (item.classId !== s.classId) return;
        set({ equipped: { ...s.equipped, [item.slot]: item } });
      },

      unequipItem: (slot) => {
        set((s) => ({ equipped: { ...s.equipped, [slot]: null } }));
      },

      enhanceItem: (itemId) => {
        const s = get();
        const item = s.inventory.find((i) => i.id === itemId);
        if (!item || item.enhanceLevel >= ENHANCE_MAX_LEVEL) return false;
        const cost = enhanceCost(item);
        if (s.gold < cost) return false;

        const upgraded: EquipmentItem = { ...item, enhanceLevel: item.enhanceLevel + 1 };
        const inventory = s.inventory.map((i) => (i.id === itemId ? upgraded : i));
        const equipped = { ...s.equipped };
        if (equipped[item.slot]?.id === itemId) equipped[item.slot] = upgraded;

        set({ gold: s.gold - cost, inventory, equipped });
        return true;
      },

      allocateStat: (stat, amount = 1) => {
        const s = get();
        const spend = Math.min(amount, s.statPoints);
        if (spend <= 0) return;
        set({
          statPoints: s.statPoints - spend,
          allocatedStats: { ...s.allocatedStats, [stat]: s.allocatedStats[stat] + spend },
        });
      },

      autoAllocateStats: () => {
        const s = get();
        if (s.statPoints <= 0 || !s.classId) return;
        const weights = CLASS_AUTO_WEIGHTS[s.classId];
        const next = { ...s.allocatedStats };
        for (let i = 0; i < s.statPoints; i++) {
          const roll = Math.random();
          let acc = 0;
          let chosen: keyof PrimaryStats = 'vit';
          for (const key of ['str', 'agi', 'int', 'vit'] as const) {
            acc += weights[key];
            if (roll <= acc) {
              chosen = key;
              break;
            }
          }
          next[chosen] += 1;
        }
        set({ allocatedStats: next, statPoints: 0 });
      },

      respecStats: () => {
        const s = get();
        if (s.gold < RESPEC_GOLD_COST) return false;
        const refunded = s.allocatedStats.str + s.allocatedStats.agi + s.allocatedStats.int + s.allocatedStats.vit;
        set({
          gold: s.gold - RESPEC_GOLD_COST,
          allocatedStats: ZERO_STATS,
          statPoints: s.statPoints + refunded,
        });
        return true;
      },

      addGems: (amount) => set((s) => ({ gems: s.gems + amount })),

      syncOfflineProgress: () => {
        const s = get();
        const elapsed = Date.now() - s.lastActiveAt;
        const stage = getStage(Math.max(1, s.highestStageCleared));
        const earned = calculateOfflineGold(stage.idleGoldPerSec, elapsed);
        set({ pendingOfflineGold: s.pendingOfflineGold + earned, lastActiveAt: Date.now() });
      },

      claimOfflineGold: () => {
        const s = get();
        set({ gold: s.gold + s.pendingOfflineGold, pendingOfflineGold: 0 });
      },

      syncBossTickets: () => {
        const s = get();
        if (s.bossTickets >= MAX_BOSS_TICKETS) {
          set({ lastTicketRefillAt: Date.now() });
          return;
        }
        const elapsed = Date.now() - s.lastTicketRefillAt;
        const gained = Math.floor(elapsed / BOSS_TICKET_REFILL_MS);
        if (gained <= 0) return;
        set({
          bossTickets: Math.min(MAX_BOSS_TICKETS, s.bossTickets + gained),
          lastTicketRefillAt: s.lastTicketRefillAt + gained * BOSS_TICKET_REFILL_MS,
        });
      },
    }),
    {
      name: 'gamele-save-v2',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (s) => ({
        classId: s.classId,
        gold: s.gold,
        gems: s.gems,
        heroLevel: s.heroLevel,
        heroExp: s.heroExp,
        statPoints: s.statPoints,
        allocatedStats: s.allocatedStats,
        currentStage: s.currentStage,
        highestStageCleared: s.highestStageCleared,
        inventory: s.inventory,
        equipped: s.equipped,
        lastActiveAt: s.lastActiveAt,
        pendingOfflineGold: s.pendingOfflineGold,
        bossTickets: s.bossTickets,
        lastTicketRefillAt: s.lastTicketRefillAt,
      }),
    }
  )
);
