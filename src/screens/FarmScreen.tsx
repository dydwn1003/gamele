import { useEffect, useState } from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';

import { CurrencyBar } from '../components/CurrencyBar';
import { Panel } from '../components/rpg/Panel';
import { RPGStatBar } from '../components/rpg/RPGStatBar';
import { SectionHeader } from '../components/rpg/SectionHeader';
import { CROPS, getCrop, growthProgress, isReady } from '../game/farm';
import { useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

function formatRemaining(ms: number): string {
  const totalSec = Math.max(0, Math.ceil(ms / 1000));
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}

export function FarmScreen() {
  const { gold, gems, farmPlots, plantSeed, harvestPlot } = useGameStore();
  const [selectedCrop, setSelectedCrop] = useState(CROPS[0].id);
  const [now, setNow] = useState(Date.now());

  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);

  const handlePlotPress = (index: number) => {
    const plot = farmPlots[index];
    if (!plot.cropId) {
      plantSeed(index, selectedCrop);
    } else if (isReady(plot, now)) {
      harvestPlot(index);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.title}>농장</Text>
        <CurrencyBar gold={gold} gems={gems} />
      </View>

      <Panel style={{ gap: 10 }}>
        <SectionHeader title="심을 씨앗 선택" />
        <View style={styles.seedRow}>
          {CROPS.map((crop) => {
            const selected = crop.id === selectedCrop;
            const affordable = gold >= crop.seedCost;
            return (
              <TouchableOpacity
                key={crop.id}
                style={[
                  styles.seedButton,
                  selected && styles.seedButtonSelected,
                  !affordable && styles.seedButtonDisabled,
                ]}
                onPress={() => setSelectedCrop(crop.id)}
              >
                <Text style={styles.seedIcon}>{crop.icon}</Text>
                <Text style={styles.seedName}>{crop.name}</Text>
                <Text style={styles.seedCost}>{crop.seedCost}G</Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </Panel>

      <View style={styles.grid}>
        {farmPlots.map((plot, i) => {
          if (!plot.cropId) {
            return (
              <TouchableOpacity key={i} style={styles.plot} onPress={() => handlePlotPress(i)}>
                <Text style={styles.plotEmptyIcon}>🟫</Text>
                <Text style={styles.plotLabel}>빈 밭</Text>
              </TouchableOpacity>
            );
          }
          const crop = getCrop(plot.cropId);
          const ready = isReady(plot, now);
          const progress = growthProgress(plot, now);
          const remaining = plot.plantedAt !== null ? crop.growMs - (now - plot.plantedAt) : 0;
          return (
            <TouchableOpacity
              key={i}
              style={[styles.plot, ready && styles.plotReady]}
              onPress={() => handlePlotPress(i)}
              disabled={!ready}
            >
              <Text style={styles.plotCropIcon}>{ready ? crop.icon : '🌱'}</Text>
              {ready ? (
                <Text style={styles.plotReadyLabel}>수확하기</Text>
              ) : (
                <>
                  <RPGStatBar progress={progress} color={colors.success} height={8} />
                  <Text style={styles.plotLabel}>{formatRemaining(remaining)}</Text>
                </>
              )}
            </TouchableOpacity>
          );
        })}
      </View>

      <Text style={styles.hint}>빈 밭을 눌러 씨앗을 심고, 다 자라면 눌러서 수확하세요</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, padding: 16, gap: 12 },
  headerRow: { gap: 10 },
  title: { color: colors.text, fontSize: 22, fontWeight: '800' },
  seedRow: { flexDirection: 'row', gap: 8 },
  seedButton: {
    flex: 1,
    backgroundColor: colors.frame.wood,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.frame.goldDark,
    paddingVertical: 8,
    alignItems: 'center',
  },
  seedButtonSelected: { borderColor: colors.frame.gold, borderWidth: 2, backgroundColor: colors.surfaceAlt },
  seedButtonDisabled: { opacity: 0.4 },
  seedIcon: { fontSize: 20 },
  seedName: { color: colors.text, fontSize: 11, fontWeight: '700', marginTop: 2 },
  seedCost: { color: colors.gold, fontSize: 10, fontWeight: '700' },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  plot: {
    width: '30%',
    aspectRatio: 1,
    backgroundColor: colors.frame.wood,
    borderRadius: 12,
    borderWidth: 1.5,
    borderColor: colors.frame.goldDark,
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    padding: 8,
  },
  plotReady: { borderColor: colors.success, borderWidth: 2, backgroundColor: colors.surfaceAlt },
  plotEmptyIcon: { fontSize: 22, opacity: 0.5 },
  plotCropIcon: { fontSize: 28 },
  plotLabel: { color: colors.textMuted, fontSize: 10, fontWeight: '700' },
  plotReadyLabel: { color: colors.success, fontSize: 11, fontWeight: '800' },
  hint: { color: colors.textMuted, fontSize: 11, textAlign: 'center', marginTop: 4 },
});
