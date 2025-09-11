import React, { useEffect, useRef } from 'react';
import {
  View,
  Modal,
  Animated,
  TouchableWithoutFeedback,
  StyleSheet,
  Dimensions,
  PanResponder,
  StatusBar,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../contexts/ThemeContext';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');

interface SlideUpModalProps {
  visible: boolean;
  onClose: () => void;
  children: React.ReactNode;
  height?: number;
  enableSwipeToClose?: boolean;
  showOverlay?: boolean;
  animationDuration?: number;
  onModalShow?: () => void;
  onModalHide?: () => void;
}

export const SlideUpModal: React.FC<SlideUpModalProps> = ({
  visible,
  onClose,
  children,
  height = SCREEN_HEIGHT * 0.6,
  enableSwipeToClose = true,
  showOverlay = true,
  animationDuration = 300,
  onModalShow,
  onModalHide,
}) => {
  const { theme } = useTheme();
  const insets = useSafeAreaInsets();
  
  const translateY = useRef(new Animated.Value(height)).current;
  const overlayOpacity = useRef(new Animated.Value(0)).current;
  
  const actualHeight = height + insets.bottom;

  useEffect(() => {
    if (visible) {
      // Animate in
      Animated.parallel([
        Animated.timing(translateY, {
          toValue: 0,
          duration: animationDuration,
          useNativeDriver: true,
        }),
        Animated.timing(overlayOpacity, {
          toValue: 1,
          duration: animationDuration,
          useNativeDriver: true,
        }),
      ]).start(() => {
        onModalShow?.();
      });
    } else {
      // Animate out
      Animated.parallel([
        Animated.timing(translateY, {
          toValue: actualHeight,
          duration: animationDuration,
          useNativeDriver: true,
        }),
        Animated.timing(overlayOpacity, {
          toValue: 0,
          duration: animationDuration,
          useNativeDriver: true,
        }),
      ]).start(() => {
        onModalHide?.();
      });
    }
  }, [visible, actualHeight, animationDuration, translateY, overlayOpacity, onModalShow, onModalHide]);

  const panResponder = PanResponder.create({
    onStartShouldSetPanResponder: () => enableSwipeToClose,
    onMoveShouldSetPanResponder: (_, gestureState) => {
      return enableSwipeToClose && gestureState.dy > 0 && Math.abs(gestureState.dy) > Math.abs(gestureState.dx);
    },

    onPanResponderMove: (_, gestureState) => {
      if (gestureState.dy > 0) {
        translateY.setValue(gestureState.dy);
      }
    },

    onPanResponderRelease: (_, gestureState) => {
      const shouldClose = gestureState.dy > actualHeight * 0.3 || gestureState.vy > 0.5;
      
      if (shouldClose) {
        onClose();
      } else {
        // Snap back to open position
        Animated.spring(translateY, {
          toValue: 0,
          tension: 100,
          friction: 8,
          useNativeDriver: true,
        }).start();
      }
    },
  });

  return (
    <Modal
      visible={visible}
      transparent
      animationType="none"
      statusBarTranslucent
      onRequestClose={onClose}
    >
      <StatusBar backgroundColor="rgba(0,0,0,0.5)" barStyle="light-content" />
      
      <View style={styles.container}>
        {showOverlay && (
          <TouchableWithoutFeedback onPress={onClose}>
            <Animated.View
              style={[
                styles.overlay,
                {
                  opacity: overlayOpacity,
                },
              ]}
            />
          </TouchableWithoutFeedback>
        )}
        
        <Animated.View
          style={[
            styles.modal,
            {
              height: actualHeight,
              backgroundColor: theme.colors.background,
              borderTopColor: theme.colors.border,
              transform: [{ translateY }],
            },
          ]}
          {...(enableSwipeToClose ? panResponder.panHandlers : {})}
        >
          {enableSwipeToClose && (
            <View style={styles.dragIndicatorContainer}>
              <View
                style={[
                  styles.dragIndicator,
                  { backgroundColor: theme.colors.textSecondary },
                ]}
              />
            </View>
          )}
          
          <View style={[styles.content, { paddingBottom: insets.bottom }]}>
            {children}
          </View>
        </Animated.View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modal: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    borderTopWidth: StyleSheet.hairlineWidth,
    shadowOffset: {
      width: 0,
      height: -2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 16,
    elevation: 16,
  },
  dragIndicatorContainer: {
    alignItems: 'center',
    paddingTop: 8,
    paddingBottom: 4,
  },
  dragIndicator: {
    width: 36,
    height: 4,
    borderRadius: 2,
    opacity: 0.5,
  },
  content: {
    flex: 1,
    paddingHorizontal: 16,
  },
});

export default SlideUpModal;