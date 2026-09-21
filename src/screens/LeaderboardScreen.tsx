import { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  FlatList,
  RefreshControl,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';

import { isFirebaseConfigured } from '../services/firebase';
import { fetchTopScores, LeaderboardEntry, submitScore } from '../services/leaderboard';
import { useAuthStore } from '../state/useAuthStore';
import { useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

export function LeaderboardScreen() {
  const user = useAuthStore((s) => s.user);
  const { highestStageCleared, heroPower } = useGameStore();
  const [entries, setEntries] = useState<LeaderboardEntry[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!isFirebaseConfigured) return;
    setLoading(true);
    setError(null);
    try {
      const top = await fetchTopScores();
      setEntries(top);
    } catch (e) {
      setError('랭킹을 불러오지 못했어요. Firestore 규칙/설정을 확인해주세요.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleSubmit = async () => {
    if (!user || !isFirebaseConfigured) return;
    await submitScore({
      uid: user.uid,
      displayName: user.displayName ?? '익명 모험가',
      power: heroPower(),
      highestStageCleared,
    });
    load();
  };

  if (!isFirebaseConfigured) {
    return (
      <View style={styles.container}>
        <Text style={styles.notice}>
          Firebase가 설정되지 않아 랭킹을 표시할 수 없습니다. app.json extra.firebase를
          채운 뒤 Firestore에 leaderboard 컬렉션을 사용하세요.
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.headerRow}>
        <Text style={styles.title}>랭킹</Text>
        <TouchableOpacity style={styles.submitButton} onPress={handleSubmit}>
          <Text style={styles.submitButtonText}>내 기록 갱신</Text>
        </TouchableOpacity>
      </View>

      {error && <Text style={styles.errorText}>{error}</Text>}

      <FlatList
        data={entries}
        keyExtractor={(item) => item.uid}
        refreshControl={<RefreshControl refreshing={loading} onRefresh={load} />}
        renderItem={({ item, index }) => (
          <View
            style={[
              styles.row,
              item.uid === user?.uid && styles.rowMine,
            ]}
          >
            <Text style={styles.rank}>#{index + 1}</Text>
            <View style={styles.rowInfo}>
              <Text style={styles.name} numberOfLines={1}>
                {item.displayName}
              </Text>
              <Text style={styles.stageText}>스테이지 {item.highestStageCleared}</Text>
            </View>
            <Text style={styles.power}>{item.power.toLocaleString()}</Text>
          </View>
        )}
        ListEmptyComponent={
          loading ? (
            <ActivityIndicator color={colors.primary} style={{ marginTop: 20 }} />
          ) : (
            <Text style={styles.notice}>아직 랭킹 기록이 없어요</Text>
          )
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background, padding: 16, gap: 12 },
  headerRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  title: { color: colors.text, fontSize: 22, fontWeight: '800' },
  submitButton: {
    backgroundColor: colors.primary,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  submitButtonText: { color: colors.text, fontWeight: '700', fontSize: 12 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 12,
    marginBottom: 8,
    gap: 10,
  },
  rowMine: { borderWidth: 1, borderColor: colors.primary },
  rank: { color: colors.textMuted, fontWeight: '800', width: 36 },
  rowInfo: { flex: 1 },
  name: { color: colors.text, fontWeight: '700' },
  stageText: { color: colors.textMuted, fontSize: 11 },
  power: { color: colors.gold, fontWeight: '800' },
  notice: { color: colors.textMuted, textAlign: 'center', marginTop: 20, lineHeight: 20 },
  errorText: { color: colors.danger, fontSize: 12 },
});
