import { useCallback, useRef } from 'react';
import { PanResponder, Animated, Dimensions, PanResponderGestureState } from 'react-native';
import { Gesture, GestureDetector } from 'react-native-gesture-handler';
import Haptics from 'react-native-haptic-feedback';

const { width: SCREEN_WIDTH } = Dimensions.get('window');

export interface SwipeGestureConfig {
  threshold?: number;
  velocity?: number;
  enableHaptics?: boolean;
  direction?: 'horizontal' | 'vertical' | 'all';
}

export interface SwipeActions {
  onSwipeLeft?: () => void;
  onSwipeRight?: () => void;
  onSwipeUp?: () => void;
  onSwipeDown?: () => void;
}

export const useSwipeGesture = (
  actions: SwipeActions,
  config: SwipeGestureConfig = {}
) => {
  const {
    threshold = 50,
    velocity = 0.5,
    enableHaptics = true,
    direction = 'all',
  } = config;

  const { onSwipeLeft, onSwipeRight, onSwipeUp, onSwipeDown } = actions;

  const panGesture = Gesture.Pan()
    .onEnd((event) => {
      const { translationX, translationY, velocityX, velocityY } = event;
      
      // Check horizontal swipes
      if ((direction === 'horizontal' || direction === 'all') && 
          Math.abs(translationX) > threshold || Math.abs(velocityX) > velocity) {
        
        if (enableHaptics) {
          Haptics.trigger('impactLight');
        }

        if (translationX > 0 && onSwipeRight) {
          onSwipeRight();
        } else if (translationX < 0 && onSwipeLeft) {
          onSwipeLeft();
        }
      }

      // Check vertical swipes
      if ((direction === 'vertical' || direction === 'all') &&
          Math.abs(translationY) > threshold || Math.abs(velocityY) > velocity) {
        
        if (enableHaptics) {
          Haptics.trigger('impactLight');
        }

        if (translationY > 0 && onSwipeDown) {
          onSwipeDown();
        } else if (translationY < 0 && onSwipeUp) {
          onSwipeUp();
        }
      }
    });

  return { panGesture };
};

export interface LongPressGestureConfig {
  minDuration?: number;
  enableHaptics?: boolean;
  maxDistance?: number;
}

export const useLongPressGesture = (
  onLongPress: () => void,
  config: LongPressGestureConfig = {}
) => {
  const {
    minDuration = 500,
    enableHaptics = true,
    maxDistance = 10,
  } = config;

  const longPressGesture = Gesture.LongPress()
    .minDuration(minDuration)
    .maxDistance(maxDistance)
    .onStart(() => {
      if (enableHaptics) {
        Haptics.trigger('impactMedium');
      }
      onLongPress();
    });

  return { longPressGesture };
};

export interface DoubleTapGestureConfig {
  maxDelay?: number;
  maxDistance?: number;
  enableHaptics?: boolean;
}

export const useDoubleTapGesture = (
  onDoubleTap: () => void,
  config: DoubleTapGestureConfig = {}
) => {
  const {
    maxDelay = 300,
    maxDistance = 10,
    enableHaptics = true,
  } = config;

  const doubleTapGesture = Gesture.Tap()
    .numberOfTaps(2)
    .maxDelay(maxDelay)
    .maxDistance(maxDistance)
    .onStart(() => {
      if (enableHaptics) {
        Haptics.trigger('selection');
      }
      onDoubleTap();
    });

  return { doubleTapGesture };
};

export interface PinchGestureConfig {
  minScale?: number;
  maxScale?: number;
  enableHaptics?: boolean;
}

export const usePinchGesture = (
  onPinchStart?: (scale: number) => void,
  onPinchUpdate?: (scale: number) => void,
  onPinchEnd?: (scale: number) => void,
  config: PinchGestureConfig = {}
) => {
  const { minScale = 0.5, maxScale = 3.0, enableHaptics = true } = config;
  const scale = useRef(new Animated.Value(1)).current;

  const pinchGesture = Gesture.Pinch()
    .onBegin(() => {
      if (enableHaptics) {
        Haptics.trigger('impactLight');
      }
      onPinchStart?.(1);
    })
    .onUpdate((event) => {
      const clampedScale = Math.max(minScale, Math.min(maxScale, event.scale));
      scale.setValue(clampedScale);
      onPinchUpdate?.(clampedScale);
    })
    .onEnd((event) => {
      const finalScale = Math.max(minScale, Math.min(maxScale, event.scale));
      
      // Animate to final scale
      Animated.spring(scale, {
        toValue: finalScale,
        useNativeDriver: true,
      }).start();
      
      onPinchEnd?.(finalScale);
    });

  return { pinchGesture, scale };
};

export interface DragGestureConfig {
  bounds?: {
    left?: number;
    right?: number;
    top?: number;
    bottom?: number;
  };
  snapPoints?: { x?: number[]; y?: number[] };
  enableHaptics?: boolean;
}

export const useDragGesture = (
  onDragStart?: (x: number, y: number) => void,
  onDragUpdate?: (x: number, y: number) => void,
  onDragEnd?: (x: number, y: number) => void,
  config: DragGestureConfig = {}
) => {
  const { bounds, snapPoints, enableHaptics = true } = config;
  const translateX = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(0)).current;

  const applyBounds = (value: number, min?: number, max?: number) => {
    if (min !== undefined && value < min) return min;
    if (max !== undefined && value > max) return max;
    return value;
  };

  const findSnapPoint = (value: number, points?: number[]) => {
    if (!points) return value;
    
    return points.reduce((closest, point) => {
      return Math.abs(point - value) < Math.abs(closest - value) ? point : closest;
    });
  };

  const panGesture = Gesture.Pan()
    .onBegin(() => {
      if (enableHaptics) {
        Haptics.trigger('selection');
      }
      onDragStart?.(0, 0);
    })
    .onUpdate((event) => {
      const x = applyBounds(event.translationX, bounds?.left, bounds?.right);
      const y = applyBounds(event.translationY, bounds?.top, bounds?.bottom);
      
      translateX.setValue(x);
      translateY.setValue(y);
      onDragUpdate?.(x, y);
    })
    .onEnd((event) => {
      let finalX = event.translationX;
      let finalY = event.translationY;

      // Apply bounds
      finalX = applyBounds(finalX, bounds?.left, bounds?.right);
      finalY = applyBounds(finalY, bounds?.top, bounds?.bottom);

      // Apply snap points
      if (snapPoints) {
        finalX = findSnapPoint(finalX, snapPoints.x);
        finalY = findSnapPoint(finalY, snapPoints.y);
      }

      // Animate to final position
      Animated.parallel([
        Animated.spring(translateX, {
          toValue: finalX,
          useNativeDriver: true,
        }),
        Animated.spring(translateY, {
          toValue: finalY,
          useNativeDriver: true,
        }),
      ]).start();

      onDragEnd?.(finalX, finalY);
    });

  const resetPosition = useCallback(() => {
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
  }, [translateX, translateY]);

  return { panGesture, translateX, translateY, resetPosition };
};

export interface MessageSwipeGestureConfig {
  replyThreshold?: number;
  editThreshold?: number;
  deleteThreshold?: number;
  enableHaptics?: boolean;
}

export const useMessageSwipeGesture = (
  onReply?: () => void,
  onEdit?: () => void,
  onDelete?: () => void,
  config: MessageSwipeGestureConfig = {}
) => {
  const {
    replyThreshold = 80,
    editThreshold = 120,
    deleteThreshold = 160,
    enableHaptics = true,
  } = config;

  const translateX = useRef(new Animated.Value(0)).current;
  const actionTriggered = useRef(false);

  const panGesture = Gesture.Pan()
    .activeOffsetX([-10, 10])
    .onUpdate((event) => {
      const { translationX } = event;
      
      // Limit swipe distance
      const limitedX = Math.max(-deleteThreshold * 1.2, Math.min(replyThreshold * 1.2, translationX));
      translateX.setValue(limitedX);

      // Haptic feedback at thresholds
      if (enableHaptics && !actionTriggered.current) {
        if (Math.abs(translationX) > replyThreshold) {
          Haptics.trigger('impactLight');
          actionTriggered.current = true;
        }
      }
    })
    .onEnd((event) => {
      const { translationX } = event;
      actionTriggered.current = false;

      // Reset animation
      Animated.spring(translateX, {
        toValue: 0,
        tension: 150,
        friction: 8,
        useNativeDriver: true,
      }).start();

      // Trigger actions based on swipe distance
      if (translationX > replyThreshold && onReply) {
        if (enableHaptics) Haptics.trigger('impactMedium');
        onReply();
      } else if (translationX < -deleteThreshold && onDelete) {
        if (enableHaptics) Haptics.trigger('notificationWarning');
        onDelete();
      } else if (translationX < -editThreshold && onEdit) {
        if (enableHaptics) Haptics.trigger('impactMedium');
        onEdit();
      }
    });

  const getActionIcon = useCallback((translateValue: number) => {
    if (translateValue > replyThreshold) return 'reply';
    if (translateValue < -deleteThreshold) return 'delete';
    if (translateValue < -editThreshold) return 'edit';
    return null;
  }, [replyThreshold, editThreshold, deleteThreshold]);

  const getActionColor = useCallback((translateValue: number) => {
    if (translateValue > replyThreshold) return '#007AFF';
    if (translateValue < -deleteThreshold) return '#FF3B30';
    if (translateValue < -editThreshold) return '#FF9500';
    return '#8E8E93';
  }, [replyThreshold, editThreshold, deleteThreshold]);

  return {
    panGesture,
    translateX,
    getActionIcon,
    getActionColor,
  };
};

export interface PullToRefreshGestureConfig {
  threshold?: number;
  maxDistance?: number;
  enableHaptics?: boolean;
}

export const usePullToRefreshGesture = (
  onRefresh: () => Promise<void>,
  config: PullToRefreshGestureConfig = {}
) => {
  const {
    threshold = 80,
    maxDistance = 150,
    enableHaptics = true,
  } = config;

  const translateY = useRef(new Animated.Value(0)).current;
  const refreshing = useRef(false);

  const panGesture = Gesture.Pan()
    .activeOffsetY([0, 10])
    .onUpdate((event) => {
      if (event.translationY > 0 && !refreshing.current) {
        const limited = Math.min(event.translationY, maxDistance);
        translateY.setValue(limited);
      }
    })
    .onEnd(async (event) => {
      if (event.translationY > threshold && !refreshing.current) {
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
          
          // Animate back to start
          Animated.timing(translateY, {
            toValue: 0,
            duration: 300,
            useNativeDriver: true,
          }).start();
        }
      } else {
        // Snap back to start
        Animated.spring(translateY, {
          toValue: 0,
          useNativeDriver: true,
        }).start();
      }
    });

  return {
    panGesture,
    translateY,
    isRefreshing: refreshing.current,
  };
};

export interface PageSwipeGestureConfig {
  threshold?: number;
  velocity?: number;
  enableHaptics?: boolean;
}

export const usePageSwipeGesture = (
  onSwipeLeft: () => void,
  onSwipeRight: () => void,
  config: PageSwipeGestureConfig = {}
) => {
  const {
    threshold = SCREEN_WIDTH * 0.3,
    velocity = 500,
    enableHaptics = true,
  } = config;

  const translateX = useRef(new Animated.Value(0)).current;

  const panGesture = Gesture.Pan()
    .onUpdate((event) => {
      translateX.setValue(event.translationX);
    })
    .onEnd((event) => {
      const { translationX, velocityX } = event;
      const shouldNavigate = Math.abs(translationX) > threshold || Math.abs(velocityX) > velocity;

      if (shouldNavigate) {
        if (enableHaptics) {
          Haptics.trigger('impactMedium');
        }

        if (translationX > 0) {
          onSwipeRight();
        } else {
          onSwipeLeft();
        }
      }

      // Reset position
      Animated.spring(translateX, {
        toValue: 0,
        useNativeDriver: true,
      }).start();
    });

  return { panGesture, translateX };
};

export default {
  useSwipeGesture,
  useLongPressGesture,
  useDoubleTapGesture,
  usePinchGesture,
  useDragGesture,
  useMessageSwipeGesture,
  usePullToRefreshGesture,
  usePageSwipeGesture,
};