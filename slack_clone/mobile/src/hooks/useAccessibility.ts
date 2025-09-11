import { useCallback, useRef, useEffect } from 'react';
import { 
  AccessibilityInfo, 
  Platform, 
  Dimensions,
  findNodeHandle,
  UIManager,
} from 'react-native';

export interface AccessibilityState {
  isScreenReaderEnabled: boolean;
  isReduceMotionEnabled: boolean;
  isReduceTransparencyEnabled: boolean;
  isBoldTextEnabled: boolean;
  isGrayscaleEnabled: boolean;
  isInvertColorsEnabled: boolean;
  announceForAccessibility: (message: string) => void;
  focusOn: (ref: any) => void;
}

export const useAccessibility = (): AccessibilityState => {
  const isScreenReaderEnabled = useRef(false);
  const isReduceMotionEnabled = useRef(false);
  const isReduceTransparencyEnabled = useRef(false);
  const isBoldTextEnabled = useRef(false);
  const isGrayscaleEnabled = useRef(false);
  const isInvertColorsEnabled = useRef(false);

  useEffect(() => {
    // Check if screen reader is enabled
    AccessibilityInfo.isScreenReaderEnabled().then(enabled => {
      isScreenReaderEnabled.current = enabled;
    });

    // Check if reduce motion is enabled
    AccessibilityInfo.isReduceMotionEnabled().then(enabled => {
      isReduceMotionEnabled.current = enabled;
    });

    if (Platform.OS === 'ios') {
      // iOS specific accessibility checks
      AccessibilityInfo.isReduceTransparencyEnabled().then(enabled => {
        isReduceTransparencyEnabled.current = enabled;
      });

      AccessibilityInfo.isBoldTextEnabled().then(enabled => {
        isBoldTextEnabled.current = enabled;
      });

      AccessibilityInfo.isGrayscaleEnabled().then(enabled => {
        isGrayscaleEnabled.current = enabled;
      });

      AccessibilityInfo.isInvertColorsEnabled().then(enabled => {
        isInvertColorsEnabled.current = enabled;
      });
    }

    // Listen for changes
    const screenReaderListener = AccessibilityInfo.addEventListener(
      'screenReaderChanged',
      enabled => {
        isScreenReaderEnabled.current = enabled;
      }
    );

    const reduceMotionListener = AccessibilityInfo.addEventListener(
      'reduceMotionChanged',
      enabled => {
        isReduceMotionEnabled.current = enabled;
      }
    );

    let reduceTransparencyListener: any;
    let boldTextListener: any;
    let grayscaleListener: any;
    let invertColorsListener: any;

    if (Platform.OS === 'ios') {
      reduceTransparencyListener = AccessibilityInfo.addEventListener(
        'reduceTransparencyChanged',
        enabled => {
          isReduceTransparencyEnabled.current = enabled;
        }
      );

      boldTextListener = AccessibilityInfo.addEventListener(
        'boldTextChanged',
        enabled => {
          isBoldTextEnabled.current = enabled;
        }
      );

      grayscaleListener = AccessibilityInfo.addEventListener(
        'grayscaleChanged',
        enabled => {
          isGrayscaleEnabled.current = enabled;
        }
      );

      invertColorsListener = AccessibilityInfo.addEventListener(
        'invertColorsChanged',
        enabled => {
          isInvertColorsEnabled.current = enabled;
        }
      );
    }

    return () => {
      screenReaderListener?.remove();
      reduceMotionListener?.remove();
      reduceTransparencyListener?.remove();
      boldTextListener?.remove();
      grayscaleListener?.remove();
      invertColorsListener?.remove();
    };
  }, []);

  const announceForAccessibility = useCallback((message: string) => {
    AccessibilityInfo.announceForAccessibility(message);
  }, []);

  const focusOn = useCallback((ref: any) => {
    if (ref?.current) {
      const node = findNodeHandle(ref.current);
      if (node) {
        AccessibilityInfo.setAccessibilityFocus(node);
      }
    }
  }, []);

  return {
    isScreenReaderEnabled: isScreenReaderEnabled.current,
    isReduceMotionEnabled: isReduceMotionEnabled.current,
    isReduceTransparencyEnabled: isReduceTransparencyEnabled.current,
    isBoldTextEnabled: isBoldTextEnabled.current,
    isGrayscaleEnabled: isGrayscaleEnabled.current,
    isInvertColorsEnabled: isInvertColorsEnabled.current,
    announceForAccessibility,
    focusOn,
  };
};

export interface AccessibilityProps {
  accessibilityLabel?: string;
  accessibilityHint?: string;
  accessibilityRole?: 'button' | 'text' | 'image' | 'header' | 'link' | 'search' | 'menu' | 'menuitem' | 'tab' | 'tablist' | 'timer' | 'list' | 'listitem' | 'alert' | 'checkbox' | 'radio' | 'radiogroup' | 'switch' | 'textbox' | 'toolbar' | 'progressbar' | 'slider' | 'spinbutton' | 'summary' | 'grid' | 'gridcell' | 'columnheader' | 'rowheader' | 'combobox' | 'scrollbar' | 'tabpanel';
  accessibilityState?: {
    disabled?: boolean;
    selected?: boolean;
    checked?: boolean | 'mixed';
    busy?: boolean;
    expanded?: boolean;
  };
  accessibilityValue?: {
    min?: number;
    max?: number;
    now?: number;
    text?: string;
  };
  accessibilityActions?: Array<{
    name: 'activate' | 'increment' | 'decrement' | 'longpress' | 'escape' | string;
    label?: string;
  }>;
  onAccessibilityAction?: (event: { nativeEvent: { actionName: string } }) => void;
}

export const getMessageAccessibilityProps = (
  message: any,
  isOwn: boolean,
  reactions?: any[],
  hasThreadReplies?: boolean
): AccessibilityProps => {
  const senderName = isOwn ? 'You' : message.user?.display_name || message.user?.username;
  const timestamp = new Date(message.inserted_at).toLocaleTimeString();
  const content = message.content || 'Message with attachment';
  
  let accessibilityLabel = `Message from ${senderName} at ${timestamp}: ${content}`;
  
  if (reactions && reactions.length > 0) {
    const reactionText = reactions.map(r => `${r.emoji} ${r.count}`).join(', ');
    accessibilityLabel += `. Reactions: ${reactionText}`;
  }
  
  if (hasThreadReplies) {
    accessibilityLabel += '. Has thread replies';
  }

  const actions: AccessibilityProps['accessibilityActions'] = [
    { name: 'activate', label: 'Open message actions' },
  ];

  if (!isOwn) {
    actions.push({ name: 'longpress', label: 'Reply to message' });
  } else {
    actions.push({ name: 'longpress', label: 'Edit or delete message' });
  }

  return {
    accessibilityLabel,
    accessibilityRole: 'button',
    accessibilityHint: 'Double tap to open message actions, long press for quick actions',
    accessibilityActions: actions,
  };
};

export const getChannelAccessibilityProps = (
  channel: any,
  unreadCount?: number,
  hasNotifications?: boolean
): AccessibilityProps => {
  let accessibilityLabel = `Channel ${channel.name}`;
  
  if (channel.description) {
    accessibilityLabel += `, ${channel.description}`;
  }
  
  if (unreadCount && unreadCount > 0) {
    accessibilityLabel += `, ${unreadCount} unread messages`;
  }
  
  if (hasNotifications) {
    accessibilityLabel += ', has notifications';
  }

  return {
    accessibilityLabel,
    accessibilityRole: 'button',
    accessibilityHint: 'Double tap to open channel',
    accessibilityState: {
      selected: false,
    },
  };
};

export const getUserAccessibilityProps = (
  user: any,
  isOnline?: boolean,
  customStatus?: string
): AccessibilityProps => {
  let accessibilityLabel = `User ${user.display_name || user.username}`;
  
  if (isOnline !== undefined) {
    accessibilityLabel += `, ${isOnline ? 'online' : 'offline'}`;
  }
  
  if (customStatus) {
    accessibilityLabel += `, status: ${customStatus}`;
  }

  return {
    accessibilityLabel,
    accessibilityRole: 'button',
    accessibilityHint: 'Double tap to view user profile',
  };
};

export const getInputAccessibilityProps = (
  placeholder: string,
  value: string,
  hasAttachments?: boolean,
  isRecording?: boolean
): AccessibilityProps => {
  let accessibilityLabel = placeholder;
  
  if (value) {
    accessibilityLabel = `Message input, current text: ${value}`;
  }
  
  if (hasAttachments) {
    accessibilityLabel += ', has attachments';
  }
  
  if (isRecording) {
    accessibilityLabel += ', recording voice message';
  }

  const actions: AccessibilityProps['accessibilityActions'] = [
    { name: 'activate', label: 'Focus input field' },
  ];

  if (value) {
    actions.push({ name: 'escape', label: 'Clear input' });
  }

  return {
    accessibilityLabel,
    accessibilityRole: 'textbox',
    accessibilityHint: 'Type your message here',
    accessibilityActions: actions,
    accessibilityState: {
      busy: isRecording,
    },
  };
};

export const getButtonAccessibilityProps = (
  label: string,
  hint?: string,
  disabled?: boolean,
  pressed?: boolean
): AccessibilityProps => {
  return {
    accessibilityLabel: label,
    accessibilityHint: hint || `Double tap to ${label.toLowerCase()}`,
    accessibilityRole: 'button',
    accessibilityState: {
      disabled: disabled || false,
      selected: pressed || false,
    },
  };
};

export const getListAccessibilityProps = (
  itemCount: number,
  currentIndex?: number
): AccessibilityProps => {
  let accessibilityLabel = `List with ${itemCount} items`;
  
  if (currentIndex !== undefined) {
    accessibilityLabel += `, currently on item ${currentIndex + 1}`;
  }

  return {
    accessibilityLabel,
    accessibilityRole: 'list',
    accessibilityHint: 'Swipe up or down to navigate items',
  };
};

export const getModalAccessibilityProps = (
  title: string,
  isVisible: boolean
): AccessibilityProps => {
  return {
    accessibilityLabel: `${title} modal`,
    accessibilityRole: 'alert',
    accessibilityViewIsModal: isVisible,
    accessibilityHint: 'Swipe down to close modal',
  };
};

export const useAccessibilityFocus = () => {
  const focusTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  const setAccessibilityFocus = useCallback((ref: any, delay: number = 100) => {
    if (focusTimeoutRef.current) {
      clearTimeout(focusTimeoutRef.current);
    }

    focusTimeoutRef.current = setTimeout(() => {
      if (ref?.current) {
        const node = findNodeHandle(ref.current);
        if (node) {
          AccessibilityInfo.setAccessibilityFocus(node);
        }
      }
    }, delay);
  }, []);

  const clearAccessibilityFocus = useCallback(() => {
    if (focusTimeoutRef.current) {
      clearTimeout(focusTimeoutRef.current);
      focusTimeoutRef.current = null;
    }
  }, []);

  useEffect(() => {
    return () => {
      if (focusTimeoutRef.current) {
        clearTimeout(focusTimeoutRef.current);
      }
    };
  }, []);

  return { setAccessibilityFocus, clearAccessibilityFocus };
};

export const useAccessibilityAnnouncement = () => {
  const announcementTimeoutRef = useRef<NodeJS.Timeout | null>(null);

  const announce = useCallback((message: string, delay: number = 0) => {
    if (announcementTimeoutRef.current) {
      clearTimeout(announcementTimeoutRef.current);
    }

    announcementTimeoutRef.current = setTimeout(() => {
      AccessibilityInfo.announceForAccessibility(message);
    }, delay);
  }, []);

  const clearAnnouncement = useCallback(() => {
    if (announcementTimeoutRef.current) {
      clearTimeout(announcementTimeoutRef.current);
      announcementTimeoutRef.current = null;
    }
  }, []);

  useEffect(() => {
    return () => {
      if (announcementTimeoutRef.current) {
        clearTimeout(announcementTimeoutRef.current);
      }
    };
  }, []);

  return { announce, clearAnnouncement };
};

export const getAccessibleTextSize = (baseSize: number, isBoldTextEnabled: boolean): number => {
  let size = baseSize;
  
  if (isBoldTextEnabled) {
    size += 2; // Increase size when bold text is enabled
  }
  
  return size;
};

export const getAccessibleColors = (
  normalColor: string,
  highContrastColor: string,
  isHighContrastEnabled: boolean
): string => {
  return isHighContrastEnabled ? highContrastColor : normalColor;
};

export default {
  useAccessibility,
  useAccessibilityFocus,
  useAccessibilityAnnouncement,
  getMessageAccessibilityProps,
  getChannelAccessibilityProps,
  getUserAccessibilityProps,
  getInputAccessibilityProps,
  getButtonAccessibilityProps,
  getListAccessibilityProps,
  getModalAccessibilityProps,
  getAccessibleTextSize,
  getAccessibleColors,
};