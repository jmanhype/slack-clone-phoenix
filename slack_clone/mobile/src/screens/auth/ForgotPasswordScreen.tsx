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
import Icon from 'react-native-vector-icons/MaterialIcons';

import { AuthStackParamList } from '@types/index';

type ForgotPasswordScreenNavigationProp = NativeStackNavigationProp<AuthStackParamList, 'ForgotPassword'>;

const ForgotPasswordScreen: React.FC = () => {
  const theme = useTheme();
  const navigation = useNavigation<ForgotPasswordScreenNavigationProp>();

  const [email, setEmail] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [emailSent, setEmailSent] = useState(false);
  const [emailError, setEmailError] = useState('');

  const shakeAnim = useRef(new Animated.Value(0)).current;
  const emailInputRef = useRef<TextInput>(null);

  const validateEmail = (email: string): boolean => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const validateForm = (): boolean => {
    if (!email.trim()) {
      setEmailError('Email is required');
      shakeAnimation();
      return false;
    }
    
    if (!validateEmail(email)) {
      setEmailError('Please enter a valid email address');
      shakeAnimation();
      return false;
    }
    
    setEmailError('');
    return true;
  };

  const shakeAnimation = () => {
    Animated.sequence([
      Animated.timing(shakeAnim, { toValue: 10, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -10, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 10, duration: 50, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 0, duration: 50, useNativeDriver: true }),
    ]).start();
  };

  const handleSendResetEmail = async () => {
    if (!validateForm()) {
      return;
    }

    setIsLoading(true);

    try {
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // In a real app, you would make an API call here
      // await apiService.requestPasswordReset(email);
      
      setEmailSent(true);
      Alert.alert(
        'Email Sent',
        `Password reset instructions have been sent to ${email}`,
        [{ text: 'OK', onPress: () => navigation.goBack() }]
      );
    } catch (error: any) {
      Alert.alert('Error', error.message || 'Failed to send reset email. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleBackToLogin = () => {
    navigation.goBack();
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
    backButton: {
      position: 'absolute',
      top: 60,
      left: 24,
      width: 40,
      height: 40,
      borderRadius: 20,
      backgroundColor: theme.colors.card,
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1,
    },
    headerContainer: {
      alignItems: 'center',
      marginBottom: 40,
      marginTop: 60,
    },
    icon: {
      fontSize: 64,
      marginBottom: 24,
    },
    title: {
      fontSize: 28,
      fontWeight: 'bold',
      color: theme.colors.text,
      marginBottom: 12,
      textAlign: 'center',
    },
    subtitle: {
      fontSize: 16,
      color: theme.colors.text,
      opacity: 0.7,
      textAlign: 'center',
      lineHeight: 22,
      paddingHorizontal: 20,
    },
    formContainer: {
      marginBottom: 32,
    },
    inputContainer: {
      marginBottom: 24,
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
    inputWrapperSuccess: {
      borderColor: theme.colors.primary,
    },
    input: {
      flex: 1,
      height: 48,
      fontSize: 16,
      color: theme.colors.text,
    },
    inputIcon: {
      marginRight: 8,
    },
    errorText: {
      fontSize: 12,
      color: theme.colors.notification,
      marginTop: 8,
    },
    successText: {
      fontSize: 12,
      color: theme.colors.primary,
      marginTop: 8,
    },
    sendButton: {
      backgroundColor: theme.colors.primary,
      height: 48,
      borderRadius: 8,
      justifyContent: 'center',
      alignItems: 'center',
      marginBottom: 24,
    },
    sendButtonDisabled: {
      backgroundColor: theme.colors.border,
    },
    sendButtonText: {
      fontSize: 16,
      fontWeight: '600',
      color: '#FFFFFF',
    },
    backToLoginButton: {
      alignItems: 'center',
    },
    backToLoginText: {
      fontSize: 14,
      color: theme.colors.primary,
      fontWeight: '500',
    },
    helpContainer: {
      marginTop: 32,
      paddingTop: 24,
      borderTopWidth: 1,
      borderTopColor: theme.colors.border,
      alignItems: 'center',
    },
    helpText: {
      fontSize: 14,
      color: theme.colors.text,
      opacity: 0.7,
      textAlign: 'center',
      lineHeight: 20,
    },
    supportLink: {
      color: theme.colors.primary,
      textDecorationLine: 'underline',
    },
    successContainer: {
      alignItems: 'center',
      padding: 20,
      backgroundColor: theme.colors.card,
      borderRadius: 12,
      marginBottom: 24,
    },
    successIcon: {
      marginBottom: 12,
    },
    successTitle: {
      fontSize: 18,
      fontWeight: '600',
      color: theme.colors.text,
      marginBottom: 8,
      textAlign: 'center',
    },
    successMessage: {
      fontSize: 14,
      color: theme.colors.text,
      opacity: 0.8,
      textAlign: 'center',
      lineHeight: 20,
    },
  });

  return (
    <KeyboardAvoidingView 
      style={styles.container} 
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
    >
      <TouchableOpacity style={styles.backButton} onPress={handleBackToLogin}>
        <Icon name="arrow-back" size={20} color={theme.colors.text} />
      </TouchableOpacity>

      <ScrollView 
        contentContainerStyle={styles.scrollContainer}
        keyboardShouldPersistTaps="handled"
      >
        <Animated.View style={{ transform: [{ translateX: shakeAnim }] }}>
          <View style={styles.headerContainer}>
            <Text style={styles.icon}>🔐</Text>
            <Text style={styles.title}>Forgot Password?</Text>
            <Text style={styles.subtitle}>
              Don't worry! Enter your email address and we'll send you instructions to reset your password.
            </Text>
          </View>

          {emailSent && (
            <View style={styles.successContainer}>
              <Icon 
                name="check-circle" 
                size={48} 
                color={theme.colors.primary} 
                style={styles.successIcon}
              />
              <Text style={styles.successTitle}>Email Sent!</Text>
              <Text style={styles.successMessage}>
                Check your inbox for password reset instructions
              </Text>
            </View>
          )}

          <View style={styles.formContainer}>
            <View style={styles.inputContainer}>
              <Text style={styles.label}>Email Address</Text>
              <View style={[
                styles.inputWrapper, 
                emailError && styles.inputWrapperError,
                emailSent && styles.inputWrapperSuccess
              ]}>
                <Icon 
                  name="email" 
                  size={20} 
                  color={theme.colors.text + '80'} 
                  style={styles.inputIcon}
                />
                <TextInput
                  ref={emailInputRef}
                  style={styles.input}
                  placeholder="Enter your email address"
                  placeholderTextColor={theme.colors.text + '80'}
                  value={email}
                  onChangeText={setEmail}
                  keyboardType="email-address"
                  autoCapitalize="none"
                  autoComplete="email"
                  returnKeyType="send"
                  onSubmitEditing={handleSendResetEmail}
                  editable={!emailSent}
                />
              </View>
              {emailError ? (
                <Text style={styles.errorText}>{emailError}</Text>
              ) : emailSent ? (
                <Text style={styles.successText}>Reset email sent successfully</Text>
              ) : null}
            </View>
          </View>

          <TouchableOpacity
            style={[styles.sendButton, (isLoading || emailSent) && styles.sendButtonDisabled]}
            onPress={handleSendResetEmail}
            disabled={isLoading || emailSent}
          >
            {isLoading ? (
              <ActivityIndicator color="#FFFFFF" />
            ) : (
              <Text style={styles.sendButtonText}>
                {emailSent ? 'Email Sent' : 'Send Reset Email'}
              </Text>
            )}
          </TouchableOpacity>

          <TouchableOpacity style={styles.backToLoginButton} onPress={handleBackToLogin}>
            <Text style={styles.backToLoginText}>Back to Sign In</Text>
          </TouchableOpacity>

          <View style={styles.helpContainer}>
            <Text style={styles.helpText}>
              Still having trouble? Contact our{' '}
              <Text style={styles.supportLink}>support team</Text>
              {' '}for assistance.
            </Text>
          </View>
        </Animated.View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
};

export default ForgotPasswordScreen;