import { ActivityIndicator, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

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
        <View style={styles.warningBox}>
          <Text style={styles.warningText}>
            Firebase 설정이 아직 연결되지 않았습니다. app.json의 extra.firebase 값을 실제
            프로젝트 값으로 채워주세요. 지금은 로그인 없이 아래 버튼으로 넘어갈 수 없습니다.
          </Text>
        </View>
      )}

      <TouchableOpacity
        style={[styles.button, !request && styles.buttonDisabled]}
        disabled={!request}
        onPress={() => promptAsync()}
      >
        {request ? (
          <Text style={styles.buttonText}>Google로 로그인</Text>
        ) : (
          <ActivityIndicator color={colors.text} />
        )}
      </TouchableOpacity>
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
  title: { color: colors.text, fontSize: 32, fontWeight: '800' },
  subtitle: { color: colors.textMuted, fontSize: 14, marginBottom: 24 },
  button: {
    backgroundColor: colors.primary,
    paddingHorizontal: 28,
    paddingVertical: 14,
    borderRadius: 12,
  },
  buttonDisabled: { opacity: 0.5 },
  buttonText: { color: colors.text, fontWeight: '700', fontSize: 16 },
  warningBox: {
    backgroundColor: colors.surfaceAlt,
    borderRadius: 12,
    padding: 16,
    marginBottom: 8,
  },
  warningText: { color: colors.textMuted, fontSize: 12, lineHeight: 18 },
});
