import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { AuthStackParamList } from '@types/index';

import LoginScreen from '@screens/auth/LoginScreen';
import RegisterScreen from '@screens/auth/RegisterScreen';
import ForgotPasswordScreen from '@screens/auth/ForgotPasswordScreen';
import BiometricSetupScreen from '@screens/auth/BiometricSetupScreen';

const Stack = createNativeStackNavigator<AuthStackParamList>();

const AuthNavigator: React.FC = () => {
  return (
    <Stack.Navigator
      initialRouteName="Login"
      screenOptions={{
        headerShown: false,
        gestureEnabled: true,
        animation: 'slide_from_right',
      }}
    >
      <Stack.Screen name="Login" component={LoginScreen} />
      <Stack.Screen name="Register" component={RegisterScreen} />
      <Stack.Screen name="ForgotPassword" component={ForgotPasswordScreen} />
      <Stack.Screen name="BiometricSetup" component={BiometricSetupScreen} />
    </Stack.Navigator>
  );
};

export default AuthNavigator;