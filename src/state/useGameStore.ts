import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import { calculateOfflineGold, simulateBattle } from '../game/combat';
import { pullGacha as rollGacha } from '../game/gacha';
import { applyExp, totalStats, powerScore } from '../game/hero';
import { getStage, STAGES } from '../game/stages';
import { EquipmentItem, EquipmentSlot } from '../game/types';

type EquippedMap = Record<EquipmentSlot, EquipmentItem | null>;

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

  fightCurrentStage: () => { won: boolean; goldEarned: number; expEarned: number };
  pullGacha: () => EquipmentItem | null;
  equipItem: (item: EquipmentItem) => void;
  unequipItem: (slot: EquipmentSlot) => void;
  addGems: (amount: number) => void;
  claimOfflineGold: () => void;
  syncOfflineProgress: () => void;
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

      heroPower: () => {
        const s = get();
        const equippedList = Object.values(s.equipped).filter(
          (i): i is EquipmentItem => i !== null
        );
        return powerScore(totalStats(s.heroLevel, equippedList));
      },

      fightCurrentStage: () => {
        const s = get();
        const stage = getStage(s.currentStage);
        const equippedList = Object.values(s.equipped).filter(
          (i): i is EquipmentItem => i !== null
        );
        const stats = totalStats(s.heroLevel, equippedList);
        const result = simulateBattle(stats, stage);

        const { level, exp } = applyExp({ level: s.heroLevel, exp: s.heroExp }, result.expEarned);
        const nextStage =
          result.won && s.currentStage < STAGES.length ? s.currentStage + 1 : s.currentStage;

        set({
          gold: s.gold + result.goldEarned,
          heroLevel: level,
          heroExp: exp,
          currentStage: nextStage,
          highestStageCleared: result.won
            ? Math.max(s.highestStageCleared, s.currentStage)
            : s.highestStageCleared,
        });

        return { won: result.won, goldEarned: result.goldEarned, expEarned: result.expEarned };
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
      }),
    }
  )
);
