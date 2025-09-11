import { useState, useEffect } from 'react';
import ReactNativeBiometrics from 'react-native-biometrics';
import { Alert, Platform } from 'react-native';

interface BiometricResult {
  success: boolean;
  message?: string;
}

interface BiometricSupport {
  available: boolean;
  type: 'TouchID' | 'FaceID' | 'Biometrics' | null;
}

export const useBiometricAuth = () => {
  const [biometricSupport, setBiometricSupport] = useState<BiometricSupport>({
    available: false,
    type: null,
  });

  const rnBiometrics = new ReactNativeBiometrics();

  useEffect(() => {
    checkBiometricSupport();
  }, []);

  const checkBiometricSupport = async (): Promise<BiometricSupport> => {
    try {
      const { available, biometryType } = await rnBiometrics.isSensorAvailable();
      
      const support: BiometricSupport = {
        available,
        type: biometryType as 'TouchID' | 'FaceID' | 'Biometrics' | null,
      };
      
      setBiometricSupport(support);
      return support;
    } catch (error) {
      console.error('Error checking biometric support:', error);
      return { available: false, type: null };
    }
  };

  const authenticateWithBiometric = async (
    promptMessage?: string
  ): Promise<BiometricResult> => {
    try {
      const { available } = await rnBiometrics.isSensorAvailable();
      
      if (!available) {
        return {
          success: false,
          message: 'Biometric authentication is not available on this device',
        };
      }

      const message = promptMessage || getDefaultPromptMessage();

      const { success } = await rnBiometrics.simplePrompt({
        promptMessage: message,
        cancelButtonText: 'Cancel',
      });

      if (success) {
        return { success: true, message: 'Authentication successful' };
      } else {
        return { success: false, message: 'Authentication was cancelled or failed' };
      }
    } catch (error: any) {
      console.error('Biometric authentication error:', error);
      return {
        success: false,
        message: error.message || 'Biometric authentication failed',
      };
    }
  };

  const createBiometricKeys = async (keyName: string = 'biometric_key'): Promise<BiometricResult> => {
    try {
      const { available } = await rnBiometrics.isSensorAvailable();
      
      if (!available) {
        return {
          success: false,
          message: 'Biometric authentication is not available',
        };
      }

      const { keysExist } = await rnBiometrics.biometricKeysExist();
      
      if (keysExist) {
        return { success: true, message: 'Biometric keys already exist' };
      }

      const { publicKey } = await rnBiometrics.createKeys(keyName);
      
      return { 
        success: true, 
        message: 'Biometric keys created successfully',
      };
    } catch (error: any) {
      console.error('Error creating biometric keys:', error);
      return {
        success: false,
        message: error.message || 'Failed to create biometric keys',
      };
    }
  };

  const deleteBiometricKeys = async (): Promise<BiometricResult> => {
    try {
      const { keysDeleted } = await rnBiometrics.deleteKeys();
      
      return {
        success: keysDeleted,
        message: keysDeleted 
          ? 'Biometric keys deleted successfully' 
          : 'No biometric keys to delete',
      };
    } catch (error: any) {
      console.error('Error deleting biometric keys:', error);
      return {
        success: false,
        message: error.message || 'Failed to delete biometric keys',
      };
    }
  };

  const signWithBiometric = async (
    payload: string,
    promptMessage?: string
  ): Promise<BiometricResult & { signature?: string }> => {
    try {
      const { available } = await rnBiometrics.isSensorAvailable();
      
      if (!available) {
        return {
          success: false,
          message: 'Biometric authentication is not available',
        };
      }

      const { keysExist } = await rnBiometrics.biometricKeysExist();
      
      if (!keysExist) {
        return {
          success: false,
          message: 'Biometric keys do not exist. Please set up biometric authentication first.',
        };
      }

      const message = promptMessage || getDefaultPromptMessage();
      
      const { success, signature } = await rnBiometrics.createSignature({
        promptMessage: message,
        payload,
        cancelButtonText: 'Cancel',
      });

      if (success && signature) {
        return { success: true, signature, message: 'Signature created successfully' };
      } else {
        return { success: false, message: 'Failed to create signature' };
      }
    } catch (error: any) {
      console.error('Error signing with biometric:', error);
      return {
        success: false,
        message: error.message || 'Failed to sign with biometric',
      };
    }
  };

  const getDefaultPromptMessage = (): string => {
    const { type } = biometricSupport;
    
    switch (type) {
      case 'TouchID':
        return 'Use Touch ID to authenticate';
      case 'FaceID':
        return 'Use Face ID to authenticate';
      case 'Biometrics':
        return 'Use biometric authentication';
      default:
        return 'Authenticate to continue';
    }
  };

  const getBiometricTypeLabel = (): string => {
    const { type, available } = biometricSupport;
    
    if (!available) return 'Not Available';
    
    switch (type) {
      case 'TouchID':
        return 'Touch ID';
      case 'FaceID':
        return 'Face ID';
      case 'Biometrics':
        return Platform.OS === 'android' ? 'Fingerprint' : 'Biometric';
      default:
        return 'Biometric';
    }
  };

  const showBiometricPrompt = (
    title: string,
    message: string,
    onSuccess: () => void,
    onError?: (error: string) => void
  ): void => {
    Alert.alert(
      title,
      message,
      [
        {
          text: 'Cancel',
          style: 'cancel',
        },
        {
          text: 'Use Biometric',
          onPress: async () => {
            const result = await authenticateWithBiometric();
            if (result.success) {
              onSuccess();
            } else {
              onError?.(result.message || 'Authentication failed');
            }
          },
        },
      ]
    );
  };

  return {
    biometricSupport,
    checkBiometricSupport,
    authenticateWithBiometric,
    createBiometricKeys,
    deleteBiometricKeys,
    signWithBiometric,
    getBiometricTypeLabel,
    showBiometricPrompt,
  };
};