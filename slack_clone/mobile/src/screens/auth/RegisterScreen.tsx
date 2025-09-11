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
import { registerUser, clearError } from '@store/slices/authSlice';

type RegisterScreenNavigationProp = NativeStackNavigationProp<AuthStackParamList, 'Register'>;

const RegisterScreen: React.FC = () => {
  const theme = useTheme();
  const navigation = useNavigation<RegisterScreenNavigationProp>();
  const dispatch = useDispatch<AppDispatch>();
  const { isLoading, error } = useSelector((state: RootState) => state.auth);

  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [acceptTerms, setAcceptTerms] = useState(false);

  const [nameError, setNameError] = useState('');
  const [emailError, setEmailError] = useState('');
  const [passwordError, setPasswordError] = useState('');
  const [confirmPasswordError, setConfirmPasswordError] = useState('');

  const shakeAnim = useRef(new Animated.Value(0)).current;
  const nameInputRef = useRef<TextInput>(null);
  const emailInputRef = useRef<TextInput>(null);
  const passwordInputRef = useRef<TextInput>(null);
  const confirmPasswordInputRef = useRef<TextInput>(null);

  const validateEmail = (email: string): boolean => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const validatePassword = (password: string): { isValid: boolean; message: string } => {
    if (password.length < 8) {
      return { isValid: false, message: 'Password must be at least 8 characters long' };
    }
    if (!/(?=.*[a-z])/.test(password)) {
      return { isValid: false, message: 'Password must contain at least one lowercase letter' };
    }
    if (!/(?=.*[A-Z])/.test(password)) {
      return { isValid: false, message: 'Password must contain at least one uppercase letter' };
    }
    if (!/(?=.*\d)/.test(password)) {
      return { isValid: false, message: 'Password must contain at least one number' };
    }
    return { isValid: true, message: '' };
  };

  const validateForm = (): boolean => {
    let isValid = true;

    // Name validation
    if (!name.trim()) {
      setNameError('Name is required');
      isValid = false;
    } else if (name.trim().length < 2) {
      setNameError('Name must be at least 2 characters long');
      isValid = false;
    } else {
      setNameError('');
    }

    // Email validation
    if (!email.trim()) {
      setEmailError('Email is required');
      isValid = false;
    } else if (!validateEmail(email)) {
      setEmailError('Please enter a valid email address');
      isValid = false;
    } else {
      setEmailError('');
    }

    // Password validation
    const passwordValidation = validatePassword(password);
    if (!passwordValidation.isValid) {
      setPasswordError(passwordValidation.message);
      isValid = false;
    } else {
      setPasswordError('');
    }

    // Confirm password validation
    if (!confirmPassword.trim()) {
      setConfirmPasswordError('Please confirm your password');
      isValid = false;
    } else if (password !== confirmPassword) {
      setConfirmPasswordError('Passwords do not match');
      isValid = false;
    } else {
      setConfirmPasswordError('');
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

  const handleRegister = async () => {
    dispatch(clearError());

    if (!validateForm()) {
      return;
    }

    if (!acceptTerms) {
      Alert.alert('Terms & Conditions', 'Please accept the terms and conditions to continue.');
      return;
    }

    try {
      await dispatch(registerUser({
        name: name.trim(),
        email: email.trim().toLowerCase(),
        password,
        password_confirmation: confirmPassword,
      })).unwrap();
      
      // Navigate to biometric setup after successful registration
      navigation.navigate('BiometricSetup');
    } catch (error: any) {
      Alert.alert('Registration Failed', error || 'Please check your information and try again.');
      shakeAnimation();
    }
  };

  const handleLogin = () => {
    navigation.navigate('Login');
  };

  const getPasswordStrengthColor = (): string => {
    if (password.length === 0) return theme.colors.border;
    const { isValid } = validatePassword(password);
    if (isValid) return theme.colors.primary;
    if (password.length >= 6) return '#FF9500';
    return theme.colors.notification;
  };

  const getPasswordStrengthText = (): string => {
    if (password.length === 0) return '';
    const { isValid } = validatePassword(password);
    if (isValid) return 'Strong';
    if (password.length >= 6) return 'Medium';
    return 'Weak';
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
      paddingVertical: 40,
    },
    headerContainer: {
      alignItems: 'center',
      marginBottom: 32,
    },
    logo: {
      fontSize: 48,
      marginBottom: 16,
    },
    title: {
      fontSize: 24,
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
    passwordStrengthContainer: {
      flexDirection: 'row',
      alignItems: 'center',
      marginTop: 4,
    },
    passwordStrengthBar: {
      flex: 1,
      height: 3,
      borderRadius: 1.5,
      marginRight: 8,
    },
    passwordStrengthText: {
      fontSize: 12,
      fontWeight: '500',
    },
    termsContainer: {
      flexDirection: 'row',
      alignItems: 'flex-start',
      marginBottom: 24,
    },
    checkbox: {
      width: 20,
      height: 20,
      borderRadius: 4,
      borderWidth: 2,
      borderColor: theme.colors.border,
      marginRight: 12,
      marginTop: 2,
      justifyContent: 'center',
      alignItems: 'center',
    },
    checkboxChecked: {
      backgroundColor: theme.colors.primary,
      borderColor: theme.colors.primary,
    },
    termsText: {
      flex: 1,
      fontSize: 14,
      color: theme.colors.text,
      opacity: 0.8,
      lineHeight: 20,
    },
    termsLink: {
      color: theme.colors.primary,
      textDecorationLine: 'underline',
    },
    registerButton: {
      backgroundColor: theme.colors.primary,
      height: 48,
      borderRadius: 8,
      justifyContent: 'center',
      alignItems: 'center',
      marginBottom: 24,
    },
    registerButtonDisabled: {
      backgroundColor: theme.colors.border,
    },
    registerButtonText: {
      fontSize: 16,
      fontWeight: '600',
      color: '#FFFFFF',
    },
    loginContainer: {
      flexDirection: 'row',
      justifyContent: 'center',
      alignItems: 'center',
    },
    loginText: {
      fontSize: 14,
      color: theme.colors.text,
      opacity: 0.7,
    },
    loginLink: {
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
            <Text style={styles.title}>Create Account</Text>
            <Text style={styles.subtitle}>Join the conversation</Text>
          </View>

          <View style={styles.formContainer}>
            <View style={styles.inputContainer}>
              <Text style={styles.label}>Full Name</Text>
              <View style={[styles.inputWrapper, nameError && styles.inputWrapperError]}>
                <TextInput
                  ref={nameInputRef}
                  style={styles.input}
                  placeholder="Enter your full name"
                  placeholderTextColor={theme.colors.text + '80'}
                  value={name}
                  onChangeText={setName}
                  autoCapitalize="words"
                  autoComplete="name"
                  returnKeyType="next"
                  onSubmitEditing={() => emailInputRef.current?.focus()}
                />
              </View>
              {nameError ? <Text style={styles.errorText}>{nameError}</Text> : null}
            </View>

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
                  placeholder="Create a strong password"
                  placeholderTextColor={theme.colors.text + '80'}
                  value={password}
                  onChangeText={setPassword}
                  secureTextEntry={!showPassword}
                  autoComplete="password-new"
                  returnKeyType="next"
                  onSubmitEditing={() => confirmPasswordInputRef.current?.focus()}
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
              {password.length > 0 && (
                <View style={styles.passwordStrengthContainer}>
                  <View 
                    style={[
                      styles.passwordStrengthBar, 
                      { backgroundColor: getPasswordStrengthColor() }
                    ]} 
                  />
                  <Text 
                    style={[
                      styles.passwordStrengthText, 
                      { color: getPasswordStrengthColor() }
                    ]}
                  >
                    {getPasswordStrengthText()}
                  </Text>
                </View>
              )}
              {passwordError ? <Text style={styles.errorText}>{passwordError}</Text> : null}
            </View>

            <View style={styles.inputContainer}>
              <Text style={styles.label}>Confirm Password</Text>
              <View style={[styles.inputWrapper, confirmPasswordError && styles.inputWrapperError]}>
                <TextInput
                  ref={confirmPasswordInputRef}
                  style={styles.input}
                  placeholder="Confirm your password"
                  placeholderTextColor={theme.colors.text + '80'}
                  value={confirmPassword}
                  onChangeText={setConfirmPassword}
                  secureTextEntry={!showConfirmPassword}
                  autoComplete="password-new"
                  returnKeyType="done"
                  onSubmitEditing={handleRegister}
                />
                <TouchableOpacity 
                  style={styles.eyeIcon}
                  onPress={() => setShowConfirmPassword(!showConfirmPassword)}
                >
                  <Icon 
                    name={showConfirmPassword ? 'visibility-off' : 'visibility'} 
                    size={20} 
                    color={theme.colors.text + '80'} 
                  />
                </TouchableOpacity>
              </View>
              {confirmPasswordError ? <Text style={styles.errorText}>{confirmPasswordError}</Text> : null}
            </View>
          </View>

          <View style={styles.termsContainer}>
            <TouchableOpacity 
              style={[styles.checkbox, acceptTerms && styles.checkboxChecked]}
              onPress={() => setAcceptTerms(!acceptTerms)}
            >
              {acceptTerms && <Icon name="check" size={12} color="#FFFFFF" />}
            </TouchableOpacity>
            <Text style={styles.termsText}>
              I agree to the{' '}
              <Text style={styles.termsLink}>Terms of Service</Text>
              {' '}and{' '}
              <Text style={styles.termsLink}>Privacy Policy</Text>
            </Text>
          </View>

          <TouchableOpacity
            style={[styles.registerButton, isLoading && styles.registerButtonDisabled]}
            onPress={handleRegister}
            disabled={isLoading}
          >
            {isLoading ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.registerButtonText}>Create Account</Text>
            )}
          </TouchableOpacity>

          <View style={styles.loginContainer}>
            <Text style={styles.loginText}>Already have an account?</Text>
            <TouchableOpacity onPress={handleLogin}>
              <Text style={styles.loginLink}>Sign In</Text>
            </TouchableOpacity>
          </View>
        </Animated.View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
};

export default RegisterScreen;