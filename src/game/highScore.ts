import AsyncStorage from '@react-native-async-storage/async-storage';

const KEY = 'gamele:high-score';

export async function loadHighScore(): Promise<number> {
  try {
    const raw = await AsyncStorage.getItem(KEY);
    return raw ? parseInt(raw, 10) || 0 : 0;
  } catch {
    return 0;
  }
}

export async function saveHighScore(score: number): Promise<void> {
  try {
    await AsyncStorage.setItem(KEY, String(score));
  } catch {
    // best-effort persistence only
  }
}
