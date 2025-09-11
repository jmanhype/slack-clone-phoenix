import React, { useState, useRef } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  Alert,
  ActivityIndicator,
  Animated,
} from 'react-native';
import { useTheme, useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useDispatch, useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';

import { AuthStackParamList } from '@types/index';
import { RootState, AppDispatch } from '@store/index';
import { loginUser, clearError } from '@store/slices/authSlice';
import { useBiometricAuth } from '@hooks/useBiometricAuth';

type LoginScreenNavigationProp = NativeStackNavigationProp<AuthStackParamList, 'Login'>;

const LoginScreen: React.FC = () => {
  const theme = useTheme();
  const navigation = useNavigation<LoginScreenNavigationProp>();
  const dispatch = useDispatch<AppDispatch>();
  const { isLoading, error, biometricEnabled } = useSelector((state: RootState) => state.auth);
  const { checkBiometricSupport, authenticateWithBiometric } = useBiometricAuth();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [emailError, setEmailError] = useState('');
  const [passwordError, setPasswordError] = useState('');

  const shakeAnim = useRef(new Animated.Value(0)).current;
  const emailInputRef = useRef<TextInput>(null);
  const passwordInputRef = useRef<TextInput>(null);

  const validateEmail = (email: string): boolean => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const validateForm = (): boolean => {
    let isValid = true;
    
    if (!email.trim()) {
      setEmailError('Email is required');
      isValid = false;
    } else if (!validateEmail(email)) {
      setEmailError('Please enter a valid email address');
      isValid = false;
    } else {
      setEmailError('');
    }

    if (!password.trim()) {
      setPasswordError('Password is required');
      isValid = false;
    } else if (password.length < 6) {
      setPasswordError('Password must be at least 6 characters');
      isValid = false;
    } else {
      setPasswordError('');
    }

    if (!isValid) {
      shakeAnimation();
    }

    return isValid;
  };

  const shakeAnimation = () => {
    Animated.sequence([
      Animated.timing(shakeAnim, { toValue: 10, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -10, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 10, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 0, duration: 50, useNativeDriver: true }),
    ]).start();
  };

  const handleLogin = async () => {
    dispatch(clearError());
    
    if (!validateForm()) {
      return;
    }

    try {
      await dispatch(loginUser({ email: email.trim(), password })).unwrap();
    } catch (error: any) {
      Alert.alert('Login Failed', error || 'Please check your credentials and try again.');
      shakeAnimation();
    }
  };

  const handleBiometricLogin = async () => {
    if (!biometricEnabled) {
      Alert.alert('Biometric Login', 'Biometric authentication is not set up.');
      return;
    }

    try {
      const result = await authenticateWithBiometric();
      if (result.success) {
        // In a real app, you would retrieve stored credentials or token
        // For demo purposes, we'll show a message
        Alert.alert('Success', 'Biometric authentication successful');
      }
    } catch (error) {
      Alert.alert('Biometric Login Failed', 'Authentication failed. Please try again.');
    }
  };

  const handleForgotPassword = () => {
    navigation.navigate('ForgotPassword');
  };

  const handleRegister = () => {
    navigation.navigate('Register');
  };

  const styles = StyleSheet.create({
    container: {
      flex: 1,
      backgroundColor: theme.colors.background,
    },
    scrollContainer: {
      flexGrow: 1,
      justifyContent: 'center',
      paddingHorizontal: 24,
    },
    headerContainer: {
      alignItems: 'center',
      marginBottom: 40,
    },
    logo: {
      fontSize: 64,
      marginBottom: 16,
    },
    title: {
      fontSize: 28,
      fontWeight: 'bold',
      color: theme.colors.text,
      marginBottom: 8,
    },
    subtitle: {
      fontSize: 16,
      color: theme.colors.text,
      opacity: 0.7,
      textAlign: 'center',
    },
    formContainer: {
      marginBottom: 24,
    },
    inputContainer: {
      marginBottom: 16,
    },
    label: {
      fontSize: 14,
      fontWeight: '500',
      color: theme.colors.text,
      marginBottom: 8,
    },
    inputWrapper: {
      flexDirection: 'row',
      alignItems: 'center',
      backgroundColor: theme.colors.card,
      borderRadius: 8,
      borderWidth: 1,
      borderColor: theme.colors.border,
      paddingHorizontal: 12,
    },
    inputWrapperError: {
      borderColor: theme.colors.notification,
    },
    input: {
      flex: 1,
      height: 48,
      fontSize: 16,
      color: theme.colors.text,
    },
    eyeIcon: {
      padding: 8,
    },
    errorText: {
      fontSize: 12,
      color: theme.colors.notification,
      marginTop: 4,
    },
    loginButton: {
      backgroundColor: theme.colors.primary,
      height: 48,
      borderRadius: 8,
      justifyContent: 'center',
      alignItems: 'center',
      marginBottom: 16,
    },
    loginButtonDisabled: {
      backgroundColor: theme.colors.border,
    },
    loginButtonText: {
      fontSize: 16,
      fontWeight: '600',
      color: '#FFFFFF',
    },
    biometricButton: {
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'center',
      backgroundColor: theme.colors.card,
      height: 48,
      borderRadius: 8,
      borderWidth: 1,
      borderColor: theme.colors.border,
      marginBottom: 24,
    },
    biometricButtonText: {
      fontSize: 16,
      fontWeight: '500',
      color: theme.colors.text,
      marginLeft: 8,
    },
    forgotPassword: {
      alignItems: 'center',
      marginBottom: 32,
    },
    forgotPasswordText: {
      fontSize: 14,
      color: theme.colors.primary,
    },
    registerContainer: {
      flexDirection: 'row',
      justifyContent: 'center',
      alignItems: 'center',
    },
    registerText: {
      fontSize: 14,
      color: theme.colors.text,
      opacity: 0.7,
    },
    registerLink: {
      fontSize: 14,
      color: theme.colors.primary,
      fontWeight: '500',
      marginLeft: 4,
    },
  });

  return (
    <KeyboardAvoidingView 
      style={styles.container} 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <ScrollView 
        contentContainerStyle={styles.scrollContainer}
        keyboardShouldPersistTaps="handled"
      >
        <Animated.View style={{ transform: [{ translateX: shakeAnim }] }}>
          <View style={styles.headerContainer}>
            <Text style={styles.logo}>💬</Text>
            <Text style={styles.title}>Welcome Back</Text>
            <Text style={styles.subtitle}>Sign in to your account</Text>
          </View>

          <View style={styles.formContainer}>
            <View style={styles.inputContainer}>
              <Text style={styles.label}>Email</Text>
              <View style={[styles.inputWrapper, emailError && styles.inputWrapperError]}>
                <TextInput
                  ref={emailInputRef}
                  style={styles.input}
                  placeholder="Enter your email"
                  placeholderTextColor={theme.colors.text + '80'}
                  value={email}
                  onChangeText={setEmail}
                  keyboardType="email-address"
                  autoCapitalize="none"
                  autoComplete="email"
                  returnKeyType="next"
                  onSubmitEditing={() => passwordInputRef.current?.focus()}
                />
              </View>
              {emailError ? <Text style={styles.errorText}>{emailError}</Text> : null}
            </View>

            <View style={styles.inputContainer}>
              <Text style={styles.label}>Password</Text>
              <View style={[styles.inputWrapper, passwordError && styles.inputWrapperError]}>
                <TextInput
                  ref={passwordInputRef}
                  style={styles.input}
                  placeholder="Enter your password"
                  placeholderTextColor={theme.colors.text + '80'}
                  value={password}
                  onChangeText={setPassword}
                  secureTextEntry={!showPassword}
                  autoComplete="password"
                  returnKeyType="done"
                  onSubmitEditing={handleLogin}
                />
                <TouchableOpacity 
                  style={styles.eyeIcon}
                  onPress={() => setShowPassword(!showPassword)}
                >
                  <Icon 
                    name={showPassword ? 'visibility-off' : 'visibility'} 
                    size={20} 
                    color={theme.colors.text + '80'} 
                  />
                </TouchableOpacity>
              </View>
              {passwordError ? <Text style={styles.errorText}>{passwordError}</Text> : null}
            </View>
          </View>

          <TouchableOpacity
            style={[styles.loginButton, isLoading && styles.loginButtonDisabled]}
            onPress={handleLogin}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.loginButtonText}>Sign In</Text>
            )}
          </TouchableOpacity>

          {biometricEnabled && (
            <TouchableOpacity style={styles.biometricButton} onPress={handleBiometricLogin}>
              <Icon name="fingerprint" size={20} color={theme.colors.text} />
              <Text style={styles.biometricButtonText}>Sign in with Biometric</Text>
            </TouchableOpacity>
          )}

          <TouchableOpacity style={styles.forgotPassword} onPress={handleForgotPassword}>
            <Text style={styles.forgotPasswordText}>Forgot Password?</Text>
          </TouchableOpacity>

          <View style={styles.registerContainer}>
            <Text style={styles.registerText}>Don't have an account?</Text>
            <TouchableOpacity onPress={handleRegister}>
              <Text style={styles.registerLink}>Sign Up</Text>
            </TouchableOpacity>
          </View>
        </Animated.View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
};

export default LoginScreen;