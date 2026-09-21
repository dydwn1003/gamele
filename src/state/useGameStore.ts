import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import { getBoss } from '../game/bosses';
import { calculateOfflineGold, simulateBattle } from '../game/combat';
import { pullBossReward, pullGacha as rollGacha } from '../game/gacha';
import { applyExp, totalStats, powerScore } from '../game/hero';
import { getStage, STAGES } from '../game/stages';
import { EquipmentItem, EquipmentSlot } from '../game/types';

type EquippedMap = Record<EquipmentSlot, EquipmentItem | null>;

export const MAX_BOSS_TICKETS = 3;
export const BOSS_TICKET_REFILL_MS = 3 * 60 * 60 * 1000; // one ticket every 3h

interface GameState {
  gold: number;
  gems: number;
  heroLevel: number;
  heroExp: number;
  currentStage: number;
  highestStageCleared: number;
  inventory: EquipmentItem[];
  equipped: EquippedMap;
  lastActiveAt: number;
  pendingOfflineGold: number;
  bossTickets: number;
  lastTicketRefillAt: number;

  gainKillReward: (gold: number, exp: number) => void;
  advanceStage: () => void;
  fightBoss: (chapter: number) => {
    won: boolean;
    goldEarned: number;
    gemsEarned: number;
    item: EquipmentItem | null;
  } | null;
  pullGacha: () => EquipmentItem | null;
  equipItem: (item: EquipmentItem) => void;
  unequipItem: (slot: EquipmentSlot) => void;
  addGems: (amount: number) => void;
  claimOfflineGold: () => void;
  syncOfflineProgress: () => void;
  syncBossTickets: () => void;
  heroPower: () => number;
}

const INITIAL_EQUIPPED: EquippedMap = { weapon: null, armor: null, accessory: null };

export const useGameStore = create<GameState>()(
  persist(
    (set, get) => ({
      gold: 0,
      gems: 100,
      heroLevel: 1,
      heroExp: 0,
      currentStage: 1,
      highestStageCleared: 0,
      inventory: [],
      equipped: INITIAL_EQUIPPED,
      lastActiveAt: Date.now(),
      pendingOfflineGold: 0,
      bossTickets: MAX_BOSS_TICKETS,
      lastTicketRefillAt: Date.now(),

      heroPower: () => {
        const s = get();
        const equippedList = Object.values(s.equipped).filter(
          (i): i is EquipmentItem => i !== null
        );
        return powerScore(totalStats(s.heroLevel, equippedList));
      },

      gainKillReward: (gold, exp) => {
        const s = get();
        const { level, exp: newExp } = applyExp({ level: s.heroLevel, exp: s.heroExp }, exp);
        set({ gold: s.gold + gold, heroLevel: level, heroExp: newExp });
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
        if (s.bossTickets <= 0) return null;

        const boss = getBoss(chapter);
        const equippedList = Object.values(s.equipped).filter(
          (i): i is EquipmentItem => i !== null
        );
        const stats = totalStats(s.heroLevel, equippedList);
        const result = simulateBattle(stats, boss);
        const { level, exp } = applyExp({ level: s.heroLevel, exp: s.heroExp }, result.expEarned);

        const goldEarned = result.won ? boss.goldReward : Math.round(boss.goldReward * 0.15);
        const gemsEarned = result.won ? boss.gemReward : 0;
        const item = result.won ? pullBossReward(boss.guaranteedRarity) : null;

        set({
          gold: s.gold + goldEarned,
          gems: s.gems + gemsEarned,
          heroLevel: level,
          heroExp: exp,
          bossTickets: s.bossTickets - 1,
          inventory: item ? [...s.inventory, item] : s.inventory,
        });

        return { won: result.won, goldEarned, gemsEarned, item };
      },

      pullGacha: () => {
        const s = get();
        const GACHA_COST = 50;
        if (s.gems < GACHA_COST) return null;
        const item = rollGacha();
        set({ gems: s.gems - GACHA_COST, inventory: [...s.inventory, item] });
        return item;
      },

      equipItem: (item) => {
        set((s) => ({ equipped: { ...s.equipped, [item.slot]: item } }));
      },

      unequipItem: (slot) => {
        set((s) => ({ equipped: { ...s.equipped, [slot]: null } }));
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
      name: 'gamele-save',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (s) => ({
        gold: s.gold,
        gems: s.gems,
        heroLevel: s.heroLevel,
        heroExp: s.heroExp,
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
