import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  ActivityIndicator,
  Animated,
  Dimensions,
} from 'react-native';
import { useTheme, useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { useDispatch } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';

import { AuthStackParamList } from '@types/index';
import { AppDispatch } from '@store/index';
import { setBiometricEnabled } from '@store/slices/authSlice';
import { useBiometricAuth } from '@hooks/useBiometricAuth';

type BiometricSetupScreenNavigationProp = NativeStackNavigationProp<AuthStackParamList, 'BiometricSetup'>;

const { width, height } = Dimensions.get('window');

const BiometricSetupScreen: React.FC = () => {
  const theme = useTheme();
  const navigation = useNavigation<BiometricSetupScreenNavigationProp>();
  const dispatch = useDispatch<AppDispatch>();
  
  const {
    biometricSupport,
    checkBiometricSupport,
    createBiometricKeys,
    authenticateWithBiometric,
    getBiometricTypeLabel,
  } = useBiometricAuth();

  const [isLoading, setIsLoading] = useState(false);
  const [isSetupComplete, setIsSetupComplete] = useState(false);

  const fadeAnim = new Animated.Value(0);
  const scaleAnim = new Animated.Value(0.8);
  const slideAnim = new Animated.Value(50);

  useEffect(() => {
    checkBiometricSupport();
    
    // Entrance animation
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 800,
        useNativeDriver: true,
      }),
      Animated.spring(scaleAnim, {
        toValue: 1,
        tension: 50,
        friction: 7,
        useNativeDriver: true,
      }),
      Animated.timing(slideAnim, {
        toValue: 0,
        duration: 600,
        useNativeDriver: true,
      }),
    ]).start();
  }, []);

  const handleSetupBiometric = async () => {
    if (!biometricSupport.available) {
      Alert.alert(
        'Not Supported',
        'Biometric authentication is not available on this device.',
        [{ text: 'Continue', onPress: handleSkip }]
      );
      return;
    }

    setIsLoading(true);

    try {
      // Create biometric keys
      const createResult = await createBiometricKeys();
      
      if (!createResult.success) {
        Alert.alert('Setup Failed', createResult.message || 'Failed to set up biometric authentication.');
        setIsLoading(false);
        return;
      }

      // Test biometric authentication
      const authResult = await authenticateWithBiometric('Verify your identity to complete setup');
      
      if (authResult.success) {
        dispatch(setBiometricEnabled(true));
        setIsSetupComplete(true);
        
        // Success animation
        Animated.sequence([
          Animated.timing(scaleAnim, {
            toValue: 1.1,
            duration: 200,
            useNativeDriver: true,
          }),
          Animated.timing(scaleAnim, {
            toValue: 1,
            duration: 200,
            useNativeDriver: true,
          }),
        ]).start();

        setTimeout(() => {
          Alert.alert(
            'Setup Complete',
            'Biometric authentication has been successfully enabled.',
            [{ text: 'Continue', onPress: handleContinue }]
          );
        }, 500);
      } else {
        Alert.alert(
          'Authentication Failed',
          'Biometric authentication failed. You can try again or continue without it.',
          [
            { text: 'Try Again', onPress: handleSetupBiometric },
            { text: 'Skip', onPress: handleSkip, style: 'cancel' },
          ]
        );
      }
    } catch (error: any) {
      Alert.alert('Setup Error', error.message || 'An error occurred during setup.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleSkip = () => {
    dispatch(setBiometricEnabled(false));
    handleContinue();
  };

  const handleContinue = () => {
    navigation.reset({
      index: 0,
      routes: [{ name: 'Login' }],
    });
  };

  const getBiometricIcon = (): string => {
    if (!biometricSupport.available) return 'block';
    
    switch (biometricSupport.type) {
      case 'TouchID':
        return 'fingerprint';
      case 'FaceID':
        return 'face';
      case 'Biometrics':
        return 'fingerprint';
      default:
        return 'security';
    }
  };

  const getBiometricDescription = (): string => {
    if (!biometricSupport.available) {
      return 'Biometric authentication is not available on this device. You can still use your password to sign in.';
    }

    const typeLabel = getBiometricTypeLabel();
    return `Use ${typeLabel} for quick and secure access to your account. Your biometric data is stored securely on your device.`;
  };

  const styles = StyleSheet.create({
    container: {
      flex: 1,
      backgroundColor: theme.colors.background,
      paddingHorizontal: 24,
      paddingVertical: 40,
    },
    skipButton: {
      position: 'absolute',
      top: 60,
      right: 24,
      zIndex: 1,
    },
    skipButtonText: {
      fontSize: 16,
      color: theme.colors.text,
      opacity: 0.7,
    },
    contentContainer: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
    },
    iconContainer: {
      width: 120,
      height: 120,
      borderRadius: 60,
      backgroundColor: theme.colors.primary + '20',
      justifyContent: 'center',
      alignItems: 'center',
      marginBottom: 32,
    },
    title: {
      fontSize: 28,
      fontWeight: 'bold',
      color: theme.colors.text,
      textAlign: 'center',
      marginBottom: 16,
    },
    description: {
      fontSize: 16,
      color: theme.colors.text,
      opacity: 0.8,
      textAlign: 'center',
      lineHeight: 22,
      paddingHorizontal: 20,
      marginBottom: 48,
    },
    featuresContainer: {
      width: '100%',
      marginBottom: 48,
    },
    featureItem: {
      flexDirection: 'row',
      alignItems: 'center',
      paddingVertical: 12,
    },
    featureIcon: {
      width: 40,
      height: 40,
      borderRadius: 20,
      backgroundColor: theme.colors.primary + '20',
      justifyContent: 'center',
      alignItems: 'center',
      marginRight: 16,
    },
    featureText: {
      flex: 1,
      fontSize: 16,
      color: theme.colors.text,
      fontWeight: '500',
    },
    buttonsContainer: {
      width: '100%',
    },
    setupButton: {
      backgroundColor: theme.colors.primary,
      height: 48,
      borderRadius: 8,
      justifyContent: 'center',
      alignItems: 'center',
      marginBottom: 16,
      flexDirection: 'row',
    },
    setupButtonDisabled: {
      backgroundColor: theme.colors.border,
    },
    setupButtonText: {
      fontSize: 16,
      fontWeight: '600',
      color: '#FFFFFF',
      marginLeft: 8,
    },
    skipSetupButton: {
      height: 48,
      justifyContent: 'center',
      alignItems: 'center',
      borderWidth: 1,
      borderColor: theme.colors.border,
      borderRadius: 8,
    },
    skipSetupButtonText: {
      fontSize: 16,
      fontWeight: '500',
      color: theme.colors.text,
      opacity: 0.8,
    },
    successContainer: {
      alignItems: 'center',
      padding: 20,
    },
    successIcon: {
      marginBottom: 16,
    },
    successTitle: {
      fontSize: 24,
      fontWeight: 'bold',
      color: theme.colors.primary,
      marginBottom: 8,
      textAlign: 'center',
    },
    successMessage: {
      fontSize: 16,
      color: theme.colors.text,
      opacity: 0.8,
      textAlign: 'center',
    },
  });

  const features = [
    { icon: 'speed', text: 'Quick and easy sign-in' },
    { icon: 'security', text: 'Enhanced security' },
    { icon: 'privacy_tip', text: 'Data stays on your device' },
  ];

  return (
    <View style={styles.container}>
      <TouchableOpacity style={styles.skipButton} onPress={handleSkip}>
        <Text style={styles.skipButtonText}>Skip</Text>
      </TouchableOpacity>

      <Animated.View 
        style={[
          styles.contentContainer,
          {
            opacity: fadeAnim,
            transform: [
              { scale: scaleAnim },
              { translateY: slideAnim },
            ],
          },
        ]}
      >
        {isSetupComplete ? (
          <View style={styles.successContainer}>
            <Icon 
              name="check-circle" 
              size={80} 
              color={theme.colors.primary} 
              style={styles.successIcon}
            />
            <Text style={styles.successTitle}>All Set!</Text>
            <Text style={styles.successMessage}>
              {getBiometricTypeLabel()} authentication is now enabled
            </Text>
          </View>
        ) : (
          <>
            <View style={styles.iconContainer}>
              <Icon 
                name={getBiometricIcon()} 
                size={48} 
                color={theme.colors.primary} 
              />
            </View>

            <Text style={styles.title}>
              {biometricSupport.available ? `Set up ${getBiometricTypeLabel()}` : 'Biometric Setup'}
            </Text>
            
            <Text style={styles.description}>
              {getBiometricDescription()}
            </Text>

            {biometricSupport.available && (
              <View style={styles.featuresContainer}>
                {features.map((feature, index) => (
                  <Animated.View 
                    key={index}
                    style={[
                      styles.featureItem,
                      {
                        opacity: fadeAnim,
                        transform: [{
                          translateX: slideAnim,
                        }],
                      },
                    ]}
                  >
                    <View style={styles.featureIcon}>
                      <Icon name={feature.icon} size={20} color={theme.colors.primary} />
                    </View>
                    <Text style={styles.featureText}>{feature.text}</Text>
                  </Animated.View>
                ))}
              </View>
            )}

            <View style={styles.buttonsContainer}>
              {biometricSupport.available ? (
                <TouchableOpacity
                  style={[styles.setupButton, isLoading && styles.setupButtonDisabled]}
                  onPress={handleSetupBiometric}
                  disabled={isLoading}
                >
                  {isLoading ? (
                    <ActivityIndicator color="#FFFFFF" />
                  ) : (
                    <>
                      <Icon name={getBiometricIcon()} size={20} color="#FFFFFF" />
                      <Text style={styles.setupButtonText}>
                        Enable {getBiometricTypeLabel()}
                      </Text>
                    </>
                  )}
                </TouchableOpacity>
              ) : null}

              <TouchableOpacity style={styles.skipSetupButton} onPress={handleSkip}>
                <Text style={styles.skipSetupButtonText}>
                  {biometricSupport.available ? 'Maybe Later' : 'Continue'}
                </Text>
              </TouchableOpacity>
            </View>
          </>
        )}
      </Animated.View>
    </View>
  );
};

export default BiometricSetupScreen;