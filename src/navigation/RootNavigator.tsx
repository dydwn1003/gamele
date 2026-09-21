import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { ActivityIndicator, Text, View } from 'react-native';

import { BattleScreen } from '../screens/BattleScreen';
import { DungeonScreen } from '../screens/DungeonScreen';
import { GachaScreen } from '../screens/GachaScreen';
import { HomeScreen } from '../screens/HomeScreen';
import { LeaderboardScreen } from '../screens/LeaderboardScreen';
import { LoginScreen } from '../screens/LoginScreen';
import { isFirebaseConfigured } from '../services/firebase';
import { useAuthStore } from '../state/useAuthStore';
import { colors } from '../theme/colors';

const Tab = createBottomTabNavigator();

const TAB_ICON: Record<string, string> = {
  홈: '🏠',
  전투: '⚔️',
  던전: '🐉',
  뽑기: '🎁',
  랭킹: '🏆',
};

export function RootNavigator() {
  const { user, initializing } = useAuthStore();

  if (initializing) {
    return (
      <View style={{ flex: 1, backgroundColor: colors.background, alignItems: 'center', justifyContent: 'center' }}>
        <ActivityIndicator color={colors.primary} size="large" />
      </View>
    );
  }

  // Firebase isn't wired up yet in this environment — skip the login gate so
  // the game loop can still be played/tested locally. Once app.json's
  // extra.firebase/googleAuth are filled in, this falls back to real auth.
  if (!user && isFirebaseConfigured) {
    return <LoginScreen />;
  }

  return (
    <NavigationContainer>
      {!isFirebaseConfigured && (
        <View style={styles.testBanner}>
          <Text style={styles.testBannerText}>
            테스트 모드 · Firebase 미설정 (로그인/랭킹 비활성)
          </Text>
        </View>
      )}
      <Tab.Navigator
        screenOptions={({ route }) => ({
          headerShown: false,
          tabBarActiveTintColor: colors.primary,
          tabBarInactiveTintColor: colors.textMuted,
          tabBarStyle: { backgroundColor: colors.surface, borderTopColor: colors.surfaceAlt },
          tabBarIcon: () => <Text>{TAB_ICON[route.name]}</Text>,
        })}
      >
        <Tab.Screen name="홈" component={HomeScreen} />
        <Tab.Screen name="전투" component={BattleScreen} />
        <Tab.Screen name="던전" component={DungeonScreen} />
        <Tab.Screen name="뽑기" component={GachaScreen} />
        <Tab.Screen name="랭킹" component={LeaderboardScreen} />
      </Tab.Navigator>
    </NavigationContainer>
  );
}

const styles = {
  testBanner: {
    backgroundColor: colors.rarity.legendary,
    paddingVertical: 6,
    alignItems: 'center' as const,
  },
  testBannerText: {
    color: colors.background,
    fontSize: 11,
    fontWeight: '700' as const,
  },
};
