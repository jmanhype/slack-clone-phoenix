import React, { useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ActivityIndicator,
  Animated,
  Dimensions,
} from 'react-native';
import { useTheme } from '@react-navigation/native';

const { width, height } = Dimensions.get('window');

const SplashScreen: React.FC = () => {
  const theme = useTheme();
  const fadeAnim = new Animated.Value(0);
  const scaleAnim = new Animated.Value(0.8);

  useEffect(() => {
    Animated.parallel([
      Animated.timing(fadeAnim, {
        toValue: 1,
        duration: 1000,
        useNativeDriver: true,
      }),
      Animated.spring(scaleAnim, {
        toValue: 1,
        tension: 50,
        friction: 7,
        useNativeDriver: true,
      }),
    ]).start();
  }, []);

  const styles = StyleSheet.create({
    container: {
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      backgroundColor: theme.colors.background,
    },
    logoContainer: {
      alignItems: 'center',
      marginBottom: 40,
    },
    logo: {
      fontSize: 48,
      fontWeight: 'bold',
      color: theme.colors.primary,
      marginBottom: 16,
    },
    subtitle: {
      fontSize: 16,
      color: theme.colors.text,
      opacity: 0.7,
      textAlign: 'center',
    },
    loadingContainer: {
      marginTop: 40,
    },
  });

  return (
    <View style={styles.container}>
      <Animated.View
        style={[
          styles.logoContainer,
          {
            opacity: fadeAnim,
            transform: [{ scale: scaleAnim }],
          },
        ]}
      >
        <Text style={styles.logo}>💬</Text>
        <Text style={styles.subtitle}>SlackClone</Text>
      </Animated.View>
      
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color={theme.colors.primary} />
      </View>
    </View>
  );
};

export default SplashScreen;