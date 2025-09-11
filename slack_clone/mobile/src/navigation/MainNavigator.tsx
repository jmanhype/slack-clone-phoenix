import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useTheme } from '@react-navigation/native';
import Icon from 'react-native-vector-icons/MaterialIcons';

import { MainTabParamList, HomeStackParamList } from '@types/index';

import HomeScreen from '@screens/main/HomeScreen';
import WorkspaceListScreen from '@screens/main/WorkspaceListScreen';
import ChannelListScreen from '@screens/main/ChannelListScreen';
import ChatScreen from '@screens/main/ChatScreen';
import ThreadScreen from '@screens/main/ThreadScreen';
import DirectMessagesScreen from '@screens/main/DirectMessagesScreen';
import ProfileScreen from '@screens/main/ProfileScreen';

const Tab = createBottomTabNavigator<MainTabParamList>();
const HomeStack = createNativeStackNavigator<HomeStackParamList>();

const HomeStackNavigator: React.FC = () => {
  return (
    <HomeStack.Navigator
      screenOptions={{
        headerShown: false,
        gestureEnabled: true,
        animation: 'slide_from_right',
      }}
    >
      <HomeStack.Screen name="WorkspaceList" component={WorkspaceListScreen} />
      <HomeStack.Screen name="ChannelList" component={ChannelListScreen} />
      <HomeStack.Screen name="Chat" component={ChatScreen} />
      <HomeStack.Screen 
        name="Thread" 
        component={ThreadScreen}
        options={{
          presentation: 'modal',
          animation: 'slide_from_bottom',
        }}
      />
    </HomeStack.Navigator>
  );
};

const MainNavigator: React.FC = () => {
  const theme = useTheme();

  return (
    <Tab.Navigator
      initialRouteName="Home"
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: theme.colors.primary,
        tabBarInactiveTintColor: theme.colors.text,
        tabBarStyle: {
          backgroundColor: theme.colors.card,
          borderTopColor: theme.colors.border,
          paddingBottom: 8,
          paddingTop: 8,
          height: 60,
        },
        tabBarLabelStyle: {
          fontSize: 12,
          fontWeight: '500',
        },
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: string;

          switch (route.name) {
            case 'Home':
              iconName = focused ? 'home' : 'home';
              break;
            case 'Channels':
              iconName = focused ? 'tag' : 'tag';
              break;
            case 'DirectMessages':
              iconName = focused ? 'message' : 'message';
              break;
            case 'Profile':
              iconName = focused ? 'person' : 'person-outline';
              break;
            default:
              iconName = 'help';
              break;
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
      })}
    >
      <Tab.Screen 
        name="Home" 
        component={HomeStackNavigator}
        options={{ tabBarLabel: 'Home' }}
      />
      <Tab.Screen 
        name="Channels" 
        component={HomeStackNavigator}
        options={{ tabBarLabel: 'Channels' }}
      />
      <Tab.Screen 
        name="DirectMessages" 
        component={DirectMessagesScreen}
        options={{ tabBarLabel: 'Messages' }}
      />
      <Tab.Screen 
        name="Profile" 
        component={ProfileScreen}
        options={{ tabBarLabel: 'Profile' }}
      />
    </Tab.Navigator>
  );
};

export default MainNavigator;