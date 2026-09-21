import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { ActivityIndicator, Text, View } from 'react-native';

import { BattleScreen } from '../screens/BattleScreen';
import { GachaScreen } from '../screens/GachaScreen';
import { HomeScreen } from '../screens/HomeScreen';
import { LeaderboardScreen } from '../screens/LeaderboardScreen';
import { LoginScreen } from '../screens/LoginScreen';
import { useAuthStore } from '../state/useAuthStore';
import { colors } from '../theme/colors';

const Tab = createBottomTabNavigator();

const TAB_ICON: Record<string, string> = {
  홈: '🏠',
  전투: '⚔️',
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

  if (!user) {
    return <LoginScreen />;
  }

  return (
    <NavigationContainer>
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
        <Tab.Screen name="뽑기" component={GachaScreen} />
        <Tab.Screen name="랭킹" component={LeaderboardScreen} />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
