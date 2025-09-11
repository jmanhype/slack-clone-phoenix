import { Platform, Dimensions, StatusBar } from 'react-native';
import DeviceInfo from 'react-native-device-info';

export const isIOS = Platform.OS === 'ios';
export const isAndroid = Platform.OS === 'android';

export const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');
export const { width: WINDOW_WIDTH, height: WINDOW_HEIGHT } = Dimensions.get('screen');

// Device type detection
export const getDeviceType = async (): Promise<'phone' | 'tablet' | 'tv' | 'desktop' | 'unknown'> => {
  try {
    return await DeviceInfo.getDeviceType();
  } catch (error) {
    console.error('Failed to get device type:', error);
    return 'unknown';
  }
};

// Check if device is a tablet
export const isTablet = (): boolean => {
  const aspectRatio = SCREEN_WIDTH / SCREEN_HEIGHT;
  const minDimension = Math.min(SCREEN_WIDTH, SCREEN_HEIGHT);
  
  // Tablet heuristics
  return minDimension >= 600 && (aspectRatio > 0.6 && aspectRatio < 1.4);
};

// Get status bar height
export const getStatusBarHeight = (): number => {
  if (isAndroid) {
    return StatusBar.currentHeight || 0;
  }
  
  // iOS status bar heights
  if (SCREEN_HEIGHT >= 812) {
    return 44; // iPhone X and newer
  }
  return 20; // Older iPhones
};

// Get bottom safe area height
export const getBottomSafeAreaHeight = (): number => {
  if (isAndroid) {
    return 0;
  }
  
  // iPhone X and newer have bottom safe area
  if (SCREEN_HEIGHT >= 812) {
    return 34;
  }
  return 0;
};

// Check if device has notch/dynamic island
export const hasNotch = (): boolean => {
  if (isAndroid) {
    return getStatusBarHeight() > 24;
  }
  
  // iOS devices with notch/dynamic island
  return SCREEN_HEIGHT >= 812;
};

// Platform-specific styling
export const platformStyles = {
  shadow: isIOS
    ? {
        shadowOffset: { width: 0, height: 2 },
        shadowOpacity: 0.1,
        shadowRadius: 8,
      }
    : {
        elevation: 4,
      },
  
  card: isIOS
    ? {
        shadowOffset: { width: 0, height: 1 },
        shadowOpacity: 0.05,
        shadowRadius: 4,
      }
    : {
        elevation: 2,
      },
  
  input: isIOS
    ? {
        paddingVertical: 12,
        fontSize: 16,
      }
    : {
        paddingVertical: 8,
        fontSize: 14,
      },
  
  button: {
    height: isIOS ? 44 : 48,
    borderRadius: isIOS ? 8 : 4,
  },
  
  header: {
    height: isIOS ? 44 : 56,
  },
  
  tabBar: {
    height: isIOS ? 49 : 56,
    paddingBottom: getBottomSafeAreaHeight(),
  },
};

// Platform-specific colors
export const platformColors = {
  primary: isIOS ? '#007AFF' : '#2196F3',
  success: isIOS ? '#34C759' : '#4CAF50',
  warning: isIOS ? '#FF9500' : '#FF9800',
  error: isIOS ? '#FF3B30' : '#F44336',
  
  separator: isIOS ? '#C6C6C8' : '#E0E0E0',
  background: isIOS ? '#F2F2F7' : '#FAFAFA',
  surface: isIOS ? '#FFFFFF' : '#FFFFFF',
  
  text: isIOS ? '#000000' : '#212121',
  textSecondary: isIOS ? '#8E8E93' : '#757575',
  textTertiary: isIOS ? '#C7C7CC' : '#9E9E9E',
};

// Platform-specific animations
export const platformAnimations = {
  timing: isIOS ? 350 : 250,
  easing: isIOS ? 'ease-out' : 'ease-in-out',
  
  spring: {
    tension: isIOS ? 200 : 150,
    friction: isIOS ? 8 : 7,
  },
  
  modal: {
    duration: isIOS ? 300 : 250,
  },
};

// Haptic feedback patterns
export const hapticPatterns = {
  light: isIOS ? 'impactLight' : 'virtualKey',
  medium: isIOS ? 'impactMedium' : 'keyboardPress',
  heavy: isIOS ? 'impactHeavy' : 'contextClick',
  
  success: isIOS ? 'notificationSuccess' : 'confirm',
  warning: isIOS ? 'notificationWarning' : 'virtualKey',
  error: isIOS ? 'notificationError' : 'reject',
};

// Typography scaling
export const getScaledFontSize = (baseSize: number): number => {
  const scale = isIOS ? 1 : 0.95; // Android typically needs slightly smaller fonts
  return Math.round(baseSize * scale);
};

// Check if device supports biometrics
export const getBiometryType = async (): Promise<string | null> => {
  try {
    return await DeviceInfo.supportedAbis();
  } catch (error) {
    console.error('Failed to get biometry type:', error);
    return null;
  }
};

// Memory and performance utilities
export const getDevicePerformanceClass = async (): Promise<'low' | 'medium' | 'high'> => {
  try {
    const totalMemory = await DeviceInfo.getTotalMemory();
    const memoryGB = totalMemory / (1024 * 1024 * 1024);
    
    if (memoryGB >= 6) return 'high';
    if (memoryGB >= 3) return 'medium';
    return 'low';
  } catch (error) {
    console.error('Failed to get device performance class:', error);
    return 'medium';
  }
};

// Network type detection
export const getConnectionType = async (): Promise<string> => {
  try {
    // This would typically use @react-native-community/netinfo
    // For now, return a placeholder
    return 'wifi';
  } catch (error) {
    console.error('Failed to get connection type:', error);
    return 'unknown';
  }
};

// Battery optimization
export const isBatteryOptimizationEnabled = async (): Promise<boolean> => {
  if (isIOS) return false; // iOS doesn't have battery optimization settings
  
  try {
    // This would typically use a native module
    return false;
  } catch (error) {
    console.error('Failed to check battery optimization:', error);
    return false;
  }
};

// Platform-specific keyboard behavior
export const keyboardBehavior = isIOS ? 'padding' : 'height';

// Safe area insets (fallback values)
export const safeAreaInsets = {
  top: getStatusBarHeight(),
  bottom: getBottomSafeAreaHeight(),
  left: 0,
  right: 0,
};

// Platform-specific image formats
export const supportedImageFormats = isIOS 
  ? ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif']
  : ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];

// Platform-specific video formats
export const supportedVideoFormats = isIOS
  ? ['mp4', 'mov', 'm4v', '3gp']
  : ['mp4', '3gp', 'webm', 'mkv'];

// Platform-specific audio formats
export const supportedAudioFormats = isIOS
  ? ['mp3', 'wav', 'aac', 'm4a', 'caf']
  : ['mp3', 'wav', 'aac', 'ogg', 'flac'];

// File size limits (in bytes)
export const fileSizeLimits = {
  image: 10 * 1024 * 1024, // 10MB
  video: 100 * 1024 * 1024, // 100MB
  audio: 50 * 1024 * 1024, // 50MB
  document: 25 * 1024 * 1024, // 25MB
};

// Platform-specific permissions
export const platformPermissions = {
  camera: isIOS ? 'ios.permission.CAMERA' : 'android.permission.CAMERA',
  microphone: isIOS ? 'ios.permission.MICROPHONE' : 'android.permission.RECORD_AUDIO',
  storage: isIOS ? null : 'android.permission.WRITE_EXTERNAL_STORAGE',
  location: isIOS ? 'ios.permission.LOCATION_WHEN_IN_USE' : 'android.permission.ACCESS_FINE_LOCATION',
  notifications: isIOS ? 'ios.permission.NOTIFICATIONS' : 'android.permission.POST_NOTIFICATIONS',
};

// Device info utilities
export const getDeviceInfo = async () => {
  try {
    const [
      deviceId,
      systemName,
      systemVersion,
      brand,
      model,
      deviceType,
      totalMemory,
      totalDiskCapacity,
    ] = await Promise.all([
      DeviceInfo.getDeviceId(),
      DeviceInfo.getSystemName(),
      DeviceInfo.getSystemVersion(),
      DeviceInfo.getBrand(),
      DeviceInfo.getModel(),
      DeviceInfo.getDeviceType(),
      DeviceInfo.getTotalMemory(),
      DeviceInfo.getTotalDiskCapacity(),
    ]);

    return {
      deviceId,
      systemName,
      systemVersion,
      brand,
      model,
      deviceType,
      totalMemory: Math.round(totalMemory / (1024 * 1024 * 1024)), // GB
      totalDiskCapacity: Math.round(totalDiskCapacity / (1024 * 1024 * 1024)), // GB
      screenWidth: SCREEN_WIDTH,
      screenHeight: SCREEN_HEIGHT,
      isTablet: isTablet(),
      hasNotch: hasNotch(),
    };
  } catch (error) {
    console.error('Failed to get device info:', error);
    return null;
  }
};

// Performance monitoring
export const shouldReduceAnimations = async (): Promise<boolean> => {
  try {
    const performanceClass = await getDevicePerformanceClass();
    return performanceClass === 'low';
  } catch (error) {
    return false;
  }
};

export const shouldReduceImageQuality = async (): Promise<boolean> => {
  try {
    const performanceClass = await getDevicePerformanceClass();
    const totalMemory = await DeviceInfo.getTotalMemory();
    const memoryGB = totalMemory / (1024 * 1024 * 1024);
    
    return performanceClass === 'low' || memoryGB < 2;
  } catch (error) {
    return false;
  }
};

// Responsive design utilities
export const getResponsiveValue = <T>(phone: T, tablet: T): T => {
  return isTablet() ? tablet : phone;
};

export const getResponsiveFontSize = (baseSize: number): number => {
  const scaleFactor = isTablet() ? 1.1 : 1.0;
  return Math.round(baseSize * scaleFactor);
};

export const getResponsivePadding = (basePadding: number): number => {
  const scaleFactor = isTablet() ? 1.5 : 1.0;
  return Math.round(basePadding * scaleFactor);
};

export default {
  isIOS,
  isAndroid,
  SCREEN_WIDTH,
  SCREEN_HEIGHT,
  getDeviceType,
  isTablet,
  getStatusBarHeight,
  getBottomSafeAreaHeight,
  hasNotch,
  platformStyles,
  platformColors,
  platformAnimations,
  hapticPatterns,
  getScaledFontSize,
  getBiometryType,
  getDevicePerformanceClass,
  getConnectionType,
  isBatteryOptimizationEnabled,
  keyboardBehavior,
  safeAreaInsets,
  supportedImageFormats,
  supportedVideoFormats,
  supportedAudioFormats,
  fileSizeLimits,
  platformPermissions,
  getDeviceInfo,
  shouldReduceAnimations,
  shouldReduceImageQuality,
  getResponsiveValue,
  getResponsiveFontSize,
  getResponsivePadding,
};