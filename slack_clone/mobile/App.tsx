import React, { useEffect, useRef } from 'react';
import {
  StatusBar,
  AppState,
  AppStateStatus,
  Linking,
  Platform,
} from 'react-native';
import { NavigationContainer, NavigationContainerRef } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createDrawerNavigator } from '@react-navigation/drawer';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import Icon from 'react-native-vector-icons/Ionicons';

// Store
import { store, persistor } from './src/store';

// Contexts
import { ThemeProvider } from './src/contexts/ThemeContext';

// Services
import { socketService } from './src/services/socket';
import { notificationService } from './src/services/notifications';
import { backgroundSyncService } from './src/services/backgroundSync';

// Screens - Auth
import LoginScreen from './src/screens/auth/LoginScreen';
import RegisterScreen from './src/screens/auth/RegisterScreen';
import ForgotPasswordScreen from './src/screens/auth/ForgotPasswordScreen';

// Screens - Main
import WorkspaceListScreen from './src/screens/main/WorkspaceListScreen';
import ChannelListScreen from './src/screens/main/ChannelListScreen';
import ChatScreen from './src/screens/main/ChatScreen';
import ProfileScreen from './src/screens/main/ProfileScreen';
import SettingsScreen from './src/screens/main/SettingsScreen';
import NotificationsScreen from './src/screens/main/NotificationsScreen';

// Components
import LoadingSpinner from './src/components/LoadingSpinner';

// Types
import { RootStackParamList, AuthStackParamList, MainTabParamList } from './src/types';

// Utils
import { isIOS } from './src/utils/platform';

// Navigation setup
const RootStack = createNativeStackNavigator<RootStackParamList>();
const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const MainTab = createBottomTabNavigator<MainTabParamList>();
const Drawer = createDrawerNavigator();

// Auth Navigator
const AuthNavigator = () => {
  return (
    <AuthStack.Navigator
      screenOptions={{
        headerShown: false,
        gestureEnabled: true,
        animation: 'slide_from_right',
      }}
    >
      <AuthStack.Screen name="Login" component={LoginScreen} />
      <AuthStack.Screen name="Register" component={RegisterScreen} />
      <AuthStack.Screen name="ForgotPassword" component={ForgotPasswordScreen} />
    </AuthStack.Navigator>
  );
};

// Main Tab Navigator
const MainTabNavigator = () => {
  return (
    <MainTab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: string;

          switch (route.name) {
            case 'Workspaces':
              iconName = focused ? 'business' : 'business-outline';
              break;
            case 'Channels':
              iconName = focused ? 'chatbubbles' : 'chatbubbles-outline';
              break;
            case 'Chat':
              iconName = focused ? 'chatbubble' : 'chatbubble-outline';
              break;
            case 'Profile':
              iconName = focused ? 'person' : 'person-outline';
              break;
            default:
              iconName = 'help-outline';
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#007AFF',
        tabBarInactiveTintColor: '#8E8E93',
        tabBarStyle: {
          backgroundColor: '#FFFFFF',
          borderTopWidth: 0.5,
          borderTopColor: '#C6C6C8',
          paddingBottom: isIOS ? 20 : 8,
          height: isIOS ? 84 : 68,
        },
        tabBarLabelStyle: {
          fontSize: 12,
          fontWeight: '500',
        },
      })}
    >
      <MainTab.Screen 
        name="Workspaces" 
        component={WorkspaceListScreen}
        options={{ tabBarLabel: 'Workspaces' }}
      />
      <MainTab.Screen 
        name="Channels" 
        component={ChannelListScreen}
        options={{ tabBarLabel: 'Channels' }}
      />
      <MainTab.Screen 
        name="Chat" 
        component={ChatScreen}
        options={{ tabBarLabel: 'Chat' }}
      />
      <MainTab.Screen 
        name="Profile" 
        component={ProfileScreen}
        options={{ tabBarLabel: 'Profile' }}
      />
    </MainTab.Navigator>
  );
};

// Main App Component
const App: React.FC = () => {
  const navigationRef = useRef<NavigationContainerRef<RootStackParamList>>(null);
  const appState = useRef(AppState.currentState);

  useEffect(() => {
    // Initialize services
    const initializeServices = async () => {
      try {
        // Initialize notifications
        await notificationService.initialize();
        
        // Initialize background sync
        await backgroundSyncService.initialize();
        
        console.log('Services initialized successfully');
      } catch (error) {
        console.error('Failed to initialize services:', error);
      }
    };

    initializeServices();

    // Handle app state changes
    const handleAppStateChange = (nextAppState: AppStateStatus) => {
      if (appState.current.match(/inactive|background/) && nextAppState === 'active') {
        // App has come to the foreground
        console.log('App has come to the foreground');
        
        // Sync any pending messages
        backgroundSyncService.syncNow();
        
        // Clear notification badge
        notificationService.clearBadge();
      } else if (nextAppState === 'background') {
        // App has gone to the background
        console.log('App has gone to the background');
        
        // Disconnect socket to save battery
        socketService.disconnect();
      }

      appState.current = nextAppState;
    };

    const subscription = AppState.addEventListener('change', handleAppStateChange);

    // Handle deep links
    const handleDeepLink = (url: string) => {
      console.log('Deep link received:', url);
      
      // Parse the URL and navigate accordingly
      // Example: slack://workspace/123/channel/456
      const parsedUrl = new URL(url);
      
      if (parsedUrl.pathname.includes('workspace') && parsedUrl.pathname.includes('channel')) {
        const pathParts = parsedUrl.pathname.split('/');
        const workspaceId = pathParts[2];
        const channelId = pathParts[4];
        
        if (navigationRef.current && workspaceId && channelId) {
          navigationRef.current.navigate('Main', {
            screen: 'Chat',
            params: { channelId, workspaceId },
          });
        }
      }
    };

    // Listen for deep links when app is already open
    const linkingSubscription = Linking.addEventListener('url', (event) => {
      handleDeepLink(event.url);
    });

    // Check for initial deep link when app is opened from closed state
    Linking.getInitialURL().then((url) => {
      if (url) {
        handleDeepLink(url);
      }
    });

    // Cleanup
    return () => {
      subscription?.remove();
      linkingSubscription?.remove();
      
      // Cleanup services
      socketService.disconnect();
      notificationService.destroy();
      backgroundSyncService.destroy();
    };
  }, []);

  // Linking configuration for deep links
  const linking = {
    prefixes: ['slack://', 'https://slack-clone.yourdomain.com'],
    config: {
      screens: {
        Auth: {
          screens: {
            Login: 'login',
            Register: 'register',
            ForgotPassword: 'forgot-password',
          },
        },
        Main: {
          screens: {
            Workspaces: 'workspaces',
            Channels: 'channels',
            Chat: 'chat/:channelId/:workspaceId',
            Profile: 'profile',
          },
        },
      },
    },
  };

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <Provider store={store}>
        <PersistGate loading={<LoadingSpinner />} persistor={persistor}>
          <SafeAreaProvider>
            <ThemeProvider>
              <StatusBar
                barStyle="light-content"
                backgroundColor="transparent"
                translucent
              />
              
              <NavigationContainer ref={navigationRef} linking={linking}>
                <RootStack.Navigator
                  screenOptions={{
                    headerShown: false,
                    gestureEnabled: true,
                    animation: Platform.select({
                      ios: 'default',
                      android: 'slide_from_right',
                    }),
                  }}
                >
                  <RootStack.Screen name="Auth" component={AuthNavigator} />
                  <RootStack.Screen name="Main" component={MainTabNavigator} />
                  
                  {/* Modal screens */}
                  <RootStack.Group screenOptions={{ presentation: 'modal' }}>
                    <RootStack.Screen 
                      name="Settings" 
                      component={SettingsScreen}
                      options={{
                        headerShown: true,
                        title: 'Settings',
                        headerStyle: {
                          backgroundColor: '#FFFFFF',
                        },
                        headerTitleStyle: {
                          color: '#000000',
                          fontSize: 18,
                          fontWeight: '600',
                        },
                        headerTintColor: '#007AFF',
                      }}
                    />
                    <RootStack.Screen 
                      name="Notifications" 
                      component={NotificationsScreen}
                      options={{
                        headerShown: true,
                        title: 'Notifications',
                        headerStyle: {
                          backgroundColor: '#FFFFFF',
                        },
                        headerTitleStyle: {
                          color: '#000000',
                          fontSize: 18,
                          fontWeight: '600',
                        },
                        headerTintColor: '#007AFF',
                      }}
                    />
                  </RootStack.Group>
                </RootStack.Navigator>
              </NavigationContainer>
            </ThemeProvider>
          </SafeAreaProvider>
        </PersistGate>
      </Provider>
    </GestureHandlerRootView>
  );
};

export default App;