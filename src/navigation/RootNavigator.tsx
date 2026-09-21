import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { ActivityIndicator, Text, View } from 'react-native';

import { ClassSelectScreen } from '../screens/ClassSelectScreen';
import { DungeonScreen } from '../screens/DungeonScreen';
import { FarmScreen } from '../screens/FarmScreen';
import { FieldScreen } from '../screens/FieldScreen';
import { GachaScreen } from '../screens/GachaScreen';
import { HomeScreen } from '../screens/HomeScreen';
import { LeaderboardScreen } from '../screens/LeaderboardScreen';
import { LoginScreen } from '../screens/LoginScreen';
import { isFirebaseConfigured } from '../services/firebase';
import { useAuthStore } from '../state/useAuthStore';
import { useGameStore } from '../state/useGameStore';
import { colors } from '../theme/colors';

const Tab = createBottomTabNavigator();

const TAB_ICON: Record<string, string> = {
  홈: '🏠',
  사냥: '🏹',
  농장: '🌾',
  던전: '🐉',
  뽑기: '🎁',
  랭킹: '🏆',
};

export function RootNavigator() {
  const { user, initializing } = useAuthStore();
  const classId = useGameStore((s) => s.classId);

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

  if (!classId) {
    return <ClassSelectScreen />;
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
          tabBarActiveTintColor: colors.frame.gold,
          tabBarInactiveTintColor: colors.textMuted,
          tabBarStyle: styles.tabBar,
          tabBarItemStyle: styles.tabBarItem,
          tabBarIcon: ({ focused }) => (
            <View style={[styles.tabIconBubble, focused && styles.tabIconBubbleActive]}>
              <Text style={styles.tabIconText}>{TAB_ICON[route.name]}</Text>
            </View>
          ),
        })}
      >
        <Tab.Screen name="홈" component={HomeScreen} />
        <Tab.Screen name="사냥" component={FieldScreen} />
        <Tab.Screen name="농장" component={FarmScreen} />
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
  tabBar: {
    backgroundColor: colors.surface,
    borderTopWidth: 0,
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    height: 68,
    paddingTop: 8,
    shadowColor: '#000',
    shadowOpacity: 0.25,
    shadowRadius: 10,
    shadowOffset: { width: 0, height: -4 },
    elevation: 12,
  },
  tabBarItem: { paddingTop: 2 },
  tabIconBubble: {
    width: 34,
    height: 34,
    borderRadius: 17,
    alignItems: 'center' as const,
    justifyContent: 'center' as const,
  },
  tabIconBubbleActive: {
    backgroundColor: colors.frame.wood,
    borderWidth: 1.5,
    borderColor: colors.frame.gold,
  },
  tabIconText: { fontSize: 17 },
};
