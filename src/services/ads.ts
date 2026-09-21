/**
 * Rewarded-ad stub. Swap this out for `react-native-google-mobile-ads` once
 * an AdMob app/unit ID exists and the project has moved to an EAS dev client
 * (rewarded ads need a native module, so they can't run in Expo Go).
 */
export async function showRewardedAd(): Promise<{ rewarded: boolean }> {
  console.warn('[ads] showRewardedAd() is a stub — wire up AdMob before shipping.');
  return { rewarded: true };
}
