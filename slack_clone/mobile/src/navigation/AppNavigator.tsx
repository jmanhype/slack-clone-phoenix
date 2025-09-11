import React, { useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { useSelector, useDispatch } from 'react-redux';
import { useColorScheme } from 'react-native';

import { RootState, AppDispatch } from '@store/index';
import { getCurrentUser } from '@store/slices/authSlice';
import { RootStackParamList } from '@types/index';

import SplashScreen from '@screens/SplashScreen';
import AuthNavigator from './AuthNavigator';
import MainNavigator from './MainNavigator';

import { lightTheme, darkTheme } from '@utils/theme';

const Stack = createNativeStackNavigator<RootStackParamList>();

const AppNavigator: React.FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const { isAuthenticated, token } = useSelector((state: RootState) => state.auth);
  const { theme } = useSelector((state: RootState) => state.settings);
  const systemColorScheme = useColorScheme();
  
  const [isInitialized, setIsInitialized] = React.useState(false);

  // Determine which theme to use
  const currentTheme = React.useMemo(() => {
    if (theme === 'system') {
      return systemColorScheme === 'dark' ? darkTheme : lightTheme;
    }
    return theme === 'dark' ? darkTheme : lightTheme;
  }, [theme, systemColorScheme]);

  useEffect(() => {
    const initializeApp = async () => {
      if (token && !isAuthenticated) {
        try {
          await dispatch(getCurrentUser()).unwrap();
        } catch (error) {
          console.error('Failed to get current user:', error);
        }
      }
      setIsInitialized(true);
    };

    initializeApp();
  }, [dispatch, token, isAuthenticated]);

  if (!isInitialized) {
    return (
      <NavigationContainer theme={currentTheme}>
        <Stack.Navigator screenOptions={{ headerShown: false }}>
          <Stack.Screen name="Splash" component={SplashScreen} />
        </Stack.Navigator>
      </NavigationContainer>
    );
  }

  return (
    <NavigationContainer theme={currentTheme}>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {isAuthenticated ? (
          <Stack.Screen name="Main" component={MainNavigator} />
        ) : (
          <Stack.Screen name="Auth" component={AuthNavigator} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};

export default AppNavigator;