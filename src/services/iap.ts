/**
 * In-app purchase stub. Swap this out for RevenueCat (or `react-native-iap`
 * directly) once App Store Connect / Play Console products exist. Also
 * needs an EAS dev client — IAP requires native modules.
 */
export interface GemPack {
  id: string;
  gems: number;
  priceLabel: string;
}

export const GEM_PACKS: GemPack[] = [
  { id: 'gems_small', gems: 100, priceLabel: '₩1,200' },
  { id: 'gems_medium', gems: 550, priceLabel: '₩5,500' },
  { id: 'gems_large', gems: 1200, priceLabel: '₩11,000' },
];

export async function purchaseGemPack(packId: string): Promise<{ gems: number } | null> {
  const pack = GEM_PACKS.find((p) => p.id === packId);
  console.warn('[iap] purchaseGemPack() is a stub — wire up RevenueCat/react-native-iap.');
  return pack ? { gems: pack.gems } : null;
}
