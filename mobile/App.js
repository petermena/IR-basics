import React from 'react';
import { StatusBar } from 'expo-status-bar';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { Ionicons } from '@expo/vector-icons';
import { colors } from './src/theme';

import ChatScreen from './src/screens/ChatScreen';
import EmailScreen from './src/screens/EmailScreen';
import ReservationScreen from './src/screens/ReservationScreen';
import TaskScreen from './src/screens/TaskScreen';

const Tab = createBottomTabNavigator();

const tabIcons = {
  Chat: { focused: 'chatbubbles', unfocused: 'chatbubbles-outline' },
  Email: { focused: 'mail', unfocused: 'mail-outline' },
  Reservations: { focused: 'restaurant', unfocused: 'restaurant-outline' },
  Tasks: { focused: 'checkbox', unfocused: 'checkbox-outline' },
};

export default function App() {
  return (
    <NavigationContainer
      theme={{
        dark: true,
        colors: {
          primary: colors.accent,
          background: colors.bgPrimary,
          card: colors.bgSecondary,
          text: colors.textPrimary,
          border: colors.border,
          notification: colors.accent,
        },
        fonts: {
          regular: { fontFamily: 'System', fontWeight: '400' },
          medium: { fontFamily: 'System', fontWeight: '500' },
          bold: { fontFamily: 'System', fontWeight: '700' },
          heavy: { fontFamily: 'System', fontWeight: '900' },
        },
      }}
    >
      <StatusBar style="light" />
      <Tab.Navigator
        screenOptions={({ route }) => ({
          tabBarIcon: ({ focused, color, size }) => {
            const icons = tabIcons[route.name];
            const iconName = focused ? icons.focused : icons.unfocused;
            return <Ionicons name={iconName} size={size} color={color} />;
          },
          tabBarActiveTintColor: colors.accent,
          tabBarInactiveTintColor: colors.textMuted,
          tabBarStyle: {
            backgroundColor: colors.bgSecondary,
            borderTopColor: colors.border,
            paddingBottom: 4,
            height: 88,
          },
          tabBarLabelStyle: {
            fontSize: 11,
            fontWeight: '500',
          },
          headerStyle: {
            backgroundColor: colors.bgSecondary,
            borderBottomColor: colors.border,
            borderBottomWidth: 1,
            shadowOpacity: 0,
            elevation: 0,
          },
          headerTintColor: colors.textPrimary,
          headerTitleStyle: {
            fontWeight: '600',
            fontSize: 17,
          },
        })}
      >
        <Tab.Screen
          name="Chat"
          component={ChatScreen}
          options={{ headerTitle: 'Aria' }}
        />
        <Tab.Screen
          name="Email"
          component={EmailScreen}
          options={{ headerTitle: 'Email Assistant' }}
        />
        <Tab.Screen
          name="Reservations"
          component={ReservationScreen}
          options={{ headerTitle: 'Reservations' }}
        />
        <Tab.Screen
          name="Tasks"
          component={TaskScreen}
          options={{ headerTitle: 'Tasks' }}
        />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
