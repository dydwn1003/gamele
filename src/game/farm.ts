export interface CropConfig {
  id: string;
  name: string;
  icon: string;
  seedCost: number;
  growMs: number;
  sellPrice: number;
  expReward: number;
}

export const FARM_PLOT_COUNT = 6;

export const CROPS: CropConfig[] = [
  { id: 'wheat', name: '밀', icon: '🌾', seedCost: 5, growMs: 2 * 60 * 1000, sellPrice: 12, expReward: 2 },
  { id: 'carrot', name: '당근', icon: '🥕', seedCost: 12, growMs: 6 * 60 * 1000, sellPrice: 30, expReward: 5 },
  { id: 'tomato', name: '토마토', icon: '🍅', seedCost: 25, growMs: 15 * 60 * 1000, sellPrice: 68, expReward: 12 },
  { id: 'pumpkin', name: '호박', icon: '🎃', seedCost: 50, growMs: 40 * 60 * 1000, sellPrice: 150, expReward: 28 },
];

export function getCrop(cropId: string): CropConfig {
  return CROPS.find((c) => c.id === cropId) ?? CROPS[0];
}

export interface FarmPlot {
  cropId: string | null;
  plantedAt: number | null;
}

export function isReady(plot: FarmPlot, now: number): boolean {
  if (!plot.cropId || plot.plantedAt === null) return false;
  return now - plot.plantedAt >= getCrop(plot.cropId).growMs;
}

export function growthProgress(plot: FarmPlot, now: number): number {
  if (!plot.cropId || plot.plantedAt === null) return 0;
  const crop = getCrop(plot.cropId);
  return Math.min(1, (now - plot.plantedAt) / crop.growMs);
}
