import AsyncStorage from '@react-native-async-storage/async-storage';

const KEY = 'gamele:cat-save';

export interface CatSave {
  bondLevel: number;
  affection: number;
  fullness: number;
  metNpcIds: string[];
  collectedTreasureIds: number[];
}

const DEFAULT_SAVE: CatSave = {
  bondLevel: 0,
  affection: 60,
  fullness: 70,
  metNpcIds: [],
  collectedTreasureIds: [],
};

export async function loadCatSave(): Promise<CatSave> {
  try {
    const raw = await AsyncStorage.getItem(KEY);
    if (!raw) return DEFAULT_SAVE;
    const parsed = JSON.parse(raw);
    return {
      bondLevel: typeof parsed.bondLevel === 'number' ? parsed.bondLevel : DEFAULT_SAVE.bondLevel,
      affection: typeof parsed.affection === 'number' ? parsed.affection : DEFAULT_SAVE.affection,
      fullness: typeof parsed.fullness === 'number' ? parsed.fullness : DEFAULT_SAVE.fullness,
      metNpcIds: Array.isArray(parsed.metNpcIds) ? parsed.metNpcIds : DEFAULT_SAVE.metNpcIds,
      collectedTreasureIds: Array.isArray(parsed.collectedTreasureIds)
        ? parsed.collectedTreasureIds
        : DEFAULT_SAVE.collectedTreasureIds,
    };
  } catch {
    return DEFAULT_SAVE;
  }
}

export async function saveCatSave(save: CatSave): Promise<void> {
  try {
    await AsyncStorage.setItem(KEY, JSON.stringify(save));
  } catch {
    // best-effort persistence only
  }
}
