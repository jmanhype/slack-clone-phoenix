import { useRef, useCallback, useEffect } from 'react';
import { 
  Animated, 
  Easing, 
  PanResponder, 
  Dimensions, 
  PanResponderGestureState,
  GestureResponderEvent,
} from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Haptics from 'react-native-haptic-feedback';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

// Animation presets
export const ANIMATION_PRESETS = {
  gentle: { duration: 250, easing: Easing.out(Easing.cubic) },
  smooth: { duration: 350, easing: Easing.bezier(0.25, 0.46, 0.45, 0.94) },
  bouncy: { duration: 400, easing: Easing.bounce },
  spring: { duration: 300, easing: Easing.elastic(1) },
  quick: { duration: 150, easing: Easing.out(Easing.quad) },
};

export interface UseSlideAnimationProps {
  duration?: number;
  easing?: Animated.EasingFunction;
  useNativeDriver?: boolean;
}

export const useSlideAnimation = (props: UseSlideAnimationProps = {}) => {
  const slideAnim = useRef(new Animated.Value(0)).current;
  const {
    duration = ANIMATION_PRESETS.smooth.duration,
    easing = ANIMATION_PRESETS.smooth.easing,
    useNativeDriver = true,
  } = props;

  const slideIn = useCallback((fromDirection: 'left' | 'right' | 'up' | 'down' = 'right') => {
    const startValue = fromDirection === 'left' ? -SCREEN_WIDTH : 
                      fromDirection === 'right' ? SCREEN_WIDTH :
                      fromDirection === 'up' ? -SCREEN_HEIGHT : SCREEN_HEIGHT;
    
    slideAnim.setValue(startValue);
    
    return Animated.timing(slideAnim, {
      toValue: 0,
      duration,
      easing,
      useNativeDriver,
    });
  }, [slideAnim, duration, easing, useNativeDriver]);

  const slideOut = useCallback((toDirection: 'left' | 'right' | 'up' | 'down' = 'left') => {
    const endValue = toDirection === 'left' ? -SCREEN_WIDTH : 
                     toDirection === 'right' ? SCREEN_WIDTH :
                     toDirection === 'up' ? -SCREEN_HEIGHT : SCREEN_HEIGHT;
    
    return Animated.timing(slideAnim, {
      toValue: endValue,
      duration,
      easing,
      useNativeDriver,
    });
  }, [slideAnim, duration, easing, useNativeDriver]);

  return { slideAnim, slideIn, slideOut };
};

export interface UseFadeAnimationProps extends UseSlideAnimationProps {
  initialValue?: number;
}

export const useFadeAnimation = (props: UseFadeAnimationProps = {}) => {
  const fadeAnim = useRef(new Animated.Value(props.initialValue || 0)).current;
  const {
    duration = ANIMATION_PRESETS.smooth.duration,
    easing = ANIMATION_PRESETS.smooth.easing,
    useNativeDriver = true,
  } = props;

  const fadeIn = useCallback(() => {
    return Animated.timing(fadeAnim, {
      toValue: 1,
      duration,
      easing,
      useNativeDriver,
    });
  }, [fadeAnim, duration, easing, useNativeDriver]);

  const fadeOut = useCallback(() => {
    return Animated.timing(fadeAnim, {
      toValue: 0,
      duration,
      easing,
      useNativeDriver,
    });
  }, [fadeAnim, duration, easing, useNativeDriver]);

  const fadeToValue = useCallback((toValue: number) => {
    return Animated.timing(fadeAnim, {
      toValue,
      duration,
      easing,
      useNativeDriver,
    });
  }, [fadeAnim, duration, easing, useNativeDriver]);

  return { fadeAnim, fadeIn, fadeOut, fadeToValue };
};

export interface UseScaleAnimationProps extends UseSlideAnimationProps {
  initialScale?: number;
}

export const useScaleAnimation = (props: UseScaleAnimationProps = {}) => {
  const scaleAnim = useRef(new Animated.Value(props.initialScale || 1)).current;
  const {
    duration = ANIMATION_PRESETS.gentle.duration,
    easing = ANIMATION_PRESETS.gentle.easing,
    useNativeDriver = true,
  } = props;

  const scaleIn = useCallback(() => {
    scaleAnim.setValue(0);
    return Animated.timing(scaleAnim, {
      toValue: 1,
      duration,
      easing,
      useNativeDriver,
    });
  }, [scaleAnim, duration, easing, useNativeDriver]);

  const scaleOut = useCallback(() => {
    return Animated.timing(scaleAnim, {
      toValue: 0,
      duration,
      easing,
      useNativeDriver,
    });
  }, [scaleAnim, duration, easing, useNativeDriver]);

  const pulse = useCallback((scale = 1.1) => {
    return Animated.sequence([
      Animated.timing(scaleAnim, {
        toValue: scale,
        duration: duration / 2,
        easing,
        useNativeDriver,
      }),
      Animated.timing(scaleAnim, {
        toValue: 1,
        duration: duration / 2,
        easing,
        useNativeDriver,
      }),
    ]);
  }, [scaleAnim, duration, easing, useNativeDriver]);

  return { scaleAnim, scaleIn, scaleOut, pulse };
};

export interface UseSpringAnimationProps {
  tension?: number;
  friction?: number;
  useNativeDriver?: boolean;
}

export const useSpringAnimation = (props: UseSpringAnimationProps = {}) => {
  const springAnim = useRef(new Animated.Value(0)).current;
  const {
    tension = 100,
    friction = 8,
    useNativeDriver = true,
  } = props;

  const springTo = useCallback((toValue: number) => {
    return Animated.spring(springAnim, {
      toValue,
      tension,
      friction,
      useNativeDriver,
    });
  }, [springAnim, tension, friction, useNativeDriver]);

  const resetSpring = useCallback(() => {
    springAnim.setValue(0);
  }, [springAnim]);

  return { springAnim, springTo, resetSpring };
};

export interface UseSwipeGestureProps {
  onSwipeLeft?: () => void;
  onSwipeRight?: () => void;
  onSwipeUp?: () => void;
  onSwipeDown?: () => void;
  threshold?: number;
  enableHaptics?: boolean;
}

export const useSwipeGesture = (props: UseSwipeGestureProps) => {
  const translateX = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(0)).current;
  const {
    onSwipeLeft,
    onSwipeRight,
    onSwipeUp,
    onSwipeDown,
    threshold = 50,
    enableHaptics = true,
  } = props;

  const panResponder = PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: (_, gestureState) => {
      return Math.abs(gestureState.dx) > 10 || Math.abs(gestureState.dy) > 10;
    },

    onPanResponderMove: (_, gestureState) => {
      translateX.setValue(gestureState.dx);
      translateY.setValue(gestureState.dy);
    },

    onPanResponderRelease: (_, gestureState) => {
      const { dx, dy } = gestureState;
      
      // Reset animations
      Animated.parallel([
        Animated.spring(translateX, {
          toValue: 0,
          useNativeDriver: true,
        }),
        Animated.spring(translateY, {
          toValue: 0,
          useNativeDriver: true,
        }),
      ]).start();

      // Check for swipe gestures
      if (Math.abs(dx) > threshold) {
        if (enableHaptics) {
          Haptics.trigger('impactLight');
        }
        
        if (dx > 0 && onSwipeRight) {
          onSwipeRight();
        } else if (dx < 0 && onSwipeLeft) {
          onSwipeLeft();
        }
      }

      if (Math.abs(dy) > threshold) {
        if (enableHaptics) {
          Haptics.trigger('impactLight');
        }
        
        if (dy > 0 && onSwipeDown) {
          onSwipeDown();
        } else if (dy < 0 && onSwipeUp) {
          onSwipeUp();
        }
      }
    },
  });

  return {
    panResponder,
    translateX,
    translateY,
    resetTransform: () => {
      translateX.setValue(0);
      translateY.setValue(0);
    },
  };
};

export interface UsePullToRefreshProps {
  onRefresh: () => Promise<void>;
  threshold?: number;
  enableHaptics?: boolean;
}

export const usePullToRefresh = (props: UsePullToRefreshProps) => {
  const { onRefresh, threshold = 80, enableHaptics = true } = props;
  const translateY = useRef(new Animated.Value(0)).current;
  const refreshing = useRef(false);

  const panResponder = PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: (_, gestureState) => gestureState.dy > 0,

    onPanResponderMove: (_, gestureState) => {
      if (gestureState.dy > 0) {
        translateY.setValue(Math.min(gestureState.dy, threshold * 1.5));
      }
    },

    onPanResponderRelease: async (_, gestureState) => {
      if (gestureState.dy > threshold && !refreshing.current) {
        refreshing.current = true;
        
        if (enableHaptics) {
          Haptics.trigger('impactMedium');
        }

        // Animate to refresh position
        Animated.timing(translateY, {
          toValue: threshold,
          duration: 200,
          useNativeDriver: true,
        }).start();

        try {
          await onRefresh();
        } finally {
          refreshing.current = false;
          
          // Animate back to start position
          Animated.timing(translateY, {
            toValue: 0,
            duration: 300,
            easing: Easing.out(Easing.cubic),
            useNativeDriver: true,
          }).start();
        }
      } else {
        // Animate back to start position
        Animated.spring(translateY, {
          toValue: 0,
          useNativeDriver: true,
        }).start();
      }
    },
  });

  return {
    panResponder,
    translateY,
    isRefreshing: refreshing.current,
  };
};

export interface UseMessageSwipeProps {
  onReply?: () => void;
  onEdit?: () => void;
  onDelete?: () => void;
  enableHaptics?: boolean;
}

export const useMessageSwipe = (props: UseMessageSwipeProps) => {
  const { onReply, onEdit, onDelete, enableHaptics = true } = props;
  const translateX = useRef(new Animated.Value(0)).current;
  const actionTriggered = useRef(false);

  const REPLY_THRESHOLD = 80;
  const EDIT_THRESHOLD = 120;
  const DELETE_THRESHOLD = 160;

  const panResponder = PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: (_, gestureState) => Math.abs(gestureState.dx) > 10,

    onPanResponderMove: (_, gestureState) => {
      const { dx } = gestureState;
      
      // Limit swipe distance
      const limitedDx = Math.max(-DELETE_THRESHOLD * 1.2, Math.min(REPLY_THRESHOLD * 1.2, dx));
      translateX.setValue(limitedDx);

      // Haptic feedback at thresholds
      if (enableHaptics && !actionTriggered.current) {
        if (Math.abs(dx) > REPLY_THRESHOLD) {
          Haptics.trigger('impactLight');
          actionTriggered.current = true;
        }
      }
    },

    onPanResponderRelease: (_, gestureState) => {
      const { dx } = gestureState;
      actionTriggered.current = false;

      // Reset animation
      Animated.spring(translateX, {
        toValue: 0,
        tension: 150,
        friction: 8,
        useNativeDriver: true,
      }).start();

      // Trigger actions based on swipe distance
      if (dx > REPLY_THRESHOLD && onReply) {
        if (enableHaptics) Haptics.trigger('impactMedium');
        onReply();
      } else if (dx < -DELETE_THRESHOLD && onDelete) {
        if (enableHaptics) Haptics.trigger('notificationWarning');
        onDelete();
      } else if (dx < -EDIT_THRESHOLD && onEdit) {
        if (enableHaptics) Haptics.trigger('impactMedium');
        onEdit();
      }
    },
  });

  const getActionIcon = (translateValue: number) => {
    if (translateValue > REPLY_THRESHOLD) return 'reply';
    if (translateValue < -DELETE_THRESHOLD) return 'delete';
    if (translateValue < -EDIT_THRESHOLD) return 'edit';
    return null;
  };

  const getActionColor = (translateValue: number) => {
    if (translateValue > REPLY_THRESHOLD) return '#007AFF';
    if (translateValue < -DELETE_THRESHOLD) return '#FF3B30';
    if (translateValue < -EDIT_THRESHOLD) return '#FF9500';
    return '#8E8E93';
  };

  return {
    panResponder,
    translateX,
    getActionIcon: (value: number) => getActionIcon(value),
    getActionColor: (value: number) => getActionColor(value),
  };
};

export interface UseKeyboardAnimationProps {
  extraHeight?: number;
}

export const useKeyboardAnimation = (props: UseKeyboardAnimationProps = {}) => {
  const keyboardHeight = useRef(new Animated.Value(0)).current;
  const { extraHeight = 0 } = props;

  useEffect(() => {
    const showListener = Animated.timing(keyboardHeight, {
      toValue: extraHeight,
      duration: 250,
      useNativeDriver: false,
    });

    const hideListener = Animated.timing(keyboardHeight, {
      toValue: 0,
      duration: 250,
      useNativeDriver: false,
    });

    return () => {
      showListener.stop();
      hideListener.stop();
    };
  }, [keyboardHeight, extraHeight]);

  return { keyboardHeight };
};

export const useStaggeredAnimation = (count: number, delay: number = 100) => {
  const animatedValues = useRef(
    Array(count).fill(0).map(() => new Animated.Value(0))
  ).current;

  const startStaggeredAnimation = useCallback((
    toValue: number = 1,
    duration: number = 300
  ) => {
    const animations = animatedValues.map((animValue, index) =>
      Animated.timing(animValue, {
        toValue,
        duration,
        delay: index * delay,
        useNativeDriver: true,
      })
    );

    return Animated.parallel(animations);
  }, [animatedValues, delay]);

  const resetAnimation = useCallback(() => {
    animatedValues.forEach(animValue => animValue.setValue(0));
  }, [animatedValues]);

  return { animatedValues, startStaggeredAnimation, resetAnimation };
};

export const useShakeAnimation = () => {
  const shakeAnim = useRef(new Animated.Value(0)).current;

  const shake = useCallback(() => {
    const shakeAnimation = Animated.sequence([
      Animated.timing(shakeAnim, { toValue: 10, duration: 100, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: -10, duration: 100, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 10, duration: 100, useNativeDriver: true }),
      Animated.timing(shakeAnim, { toValue: 0, duration: 100, useNativeDriver: true }),
    ]);

    shakeAnimation.start();
    
    // Haptic feedback
    Haptics.trigger('notificationError');
  }, [shakeAnim]);

  return { shakeAnim, shake };
};

export default {
  useSlideAnimation,
  useFadeAnimation,
  useScaleAnimation,
  useSpringAnimation,
  useSwipeGesture,
  usePullToRefresh,
  useMessageSwipe,
  useKeyboardAnimation,
  useStaggeredAnimation,
  useShakeAnimation,
  ANIMATION_PRESETS,
};