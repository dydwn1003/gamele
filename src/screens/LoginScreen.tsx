import { ActivityIndicator, StyleSheet, Text, View } from 'react-native';

import { Panel } from '../components/rpg/Panel';
import { RPGButton } from '../components/rpg/RPGButton';
import { useGoogleSignIn } from '../services/googleAuth';
import { isFirebaseConfigured } from '../services/firebase';
import { colors } from '../theme/colors';

export function LoginScreen() {
  const { request, promptAsync } = useGoogleSignIn();

  return (
    <View style={styles.container}>
      <Text style={styles.title}>영웅 키우기</Text>
      <Text style={styles.subtitle}>자동전투로 성장하고, 랭킹에 도전하세요</Text>

      {!isFirebaseConfigured && (
        <Panel style={{ marginBottom: 8 }}>
          <Text style={styles.warningText}>
            Firebase 설정이 아직 연결되지 않았습니다. app.json의 extra.firebase 값을 실제
            프로젝트 값으로 채워주세요. 지금은 로그인 없이 아래 버튼으로 넘어갈 수 없습니다.
          </Text>
        </Panel>
      )}

      <RPGButton disabled={!request} onPress={() => promptAsync()} style={{ paddingHorizontal: 16 }}>
        {request ? 'Google로 로그인' : <ActivityIndicator color={colors.text} />}
      </RPGButton>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.background,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
    gap: 16,
  },
  title: { color: colors.frame.gold, fontSize: 32, fontWeight: '800' },
  subtitle: { color: colors.textMuted, fontSize: 14, marginBottom: 24 },
  warningText: { color: colors.textMuted, fontSize: 12, lineHeight: 18 },
});
