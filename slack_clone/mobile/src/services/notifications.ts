import messaging, { FirebaseMessagingTypes } from '@react-native-firebase/messaging';
import notifee, { AndroidImportance, AuthorizationStatus } from '@notifee/react-native';
import { Platform } from 'react-native';
import { store } from '../store';
import { addMessage } from '../store/slices/messagesSlice';
import { updateChannelLastMessage } from '../store/slices/channelsSlice';

export interface NotificationPayload {
  type: 'message' | 'mention' | 'dm' | 'channel_invite' | 'workspace_invite';
  channelId?: string;
  workspaceId?: string;
  senderId?: string;
  messageId?: string;
  title: string;
  body: string;
  data?: Record<string, any>;
}

export interface NotificationSettings {
  enabled: boolean;
  sound: boolean;
  vibration: boolean;
  badge: boolean;
  mentions: boolean;
  directMessages: boolean;
  channels: boolean;
  workspaceInvites: boolean;
  quietHours: {
    enabled: boolean;
    start: string; // HH:mm format
    end: string;   // HH:mm format
  };
  dndEnabled: boolean;
  dndEndTime?: Date;
}

class NotificationService {
  private isInitialized = false;
  private fcmToken: string | null = null;
  private unsubscribeForeground: (() => void) | null = null;
  private unsubscribeBackground: (() => void) | null = null;

  async initialize(): Promise<boolean> {
    try {
      // Request permission
      const hasPermission = await this.requestPermission();
      if (!hasPermission) {
        console.warn('Notification permission denied');
        return false;
      }

      // Get FCM token
      this.fcmToken = await messaging().getToken();
      console.log('FCM Token:', this.fcmToken);

      // Create notification channels (Android)
      await this.createNotificationChannels();

      // Set up message handlers
      this.setupMessageHandlers();

      // Handle token refresh
      messaging().onTokenRefresh(this.onTokenRefresh);

      this.isInitialized = true;
      return true;
    } catch (error) {
      console.error('Failed to initialize notifications:', error);
      return false;
    }
  }

  private async requestPermission(): Promise<boolean> {
    try {
      if (Platform.OS === 'ios') {
        const authStatus = await messaging().requestPermission();
        return authStatus === messaging.AuthorizationStatus.AUTHORIZED ||
               authStatus === messaging.AuthorizationStatus.PROVISIONAL;
      } else {
        // Android - use notifee for more control
        const settings = await notifee.requestPermission();
        return settings.authorizationStatus === AuthorizationStatus.AUTHORIZED;
      }
    } catch (error) {
      console.error('Failed to request notification permission:', error);
      return false;
    }
  }

  private async createNotificationChannels() {
    if (Platform.OS !== 'android') return;

    try {
      // Create channels for different notification types
      const channels = [
        {
          id: 'messages',
          name: 'Messages',
          description: 'Direct messages and channel messages',
          importance: AndroidImportance.HIGH,
          sound: 'default',
          vibration: true,
        },
        {
          id: 'mentions',
          name: 'Mentions',
          description: 'When you are mentioned in a message',
          importance: AndroidImportance.HIGH,
          sound: 'mention',
          vibration: true,
        },
        {
          id: 'invites',
          name: 'Invitations',
          description: 'Workspace and channel invitations',
          importance: AndroidImportance.DEFAULT,
          sound: 'default',
          vibration: false,
        },
        {
          id: 'system',
          name: 'System',
          description: 'System notifications and updates',
          importance: AndroidImportance.LOW,
          sound: 'none',
          vibration: false,
        },
      ];

      for (const channel of channels) {
        await notifee.createChannel(channel);
      }
    } catch (error) {
      console.error('Failed to create notification channels:', error);
    }
  }

  private setupMessageHandlers() {
    // Foreground messages
    this.unsubscribeForeground = messaging().onMessage(this.handleForegroundMessage);

    // Background/quit state messages
    this.unsubscribeBackground = messaging().setBackgroundMessageHandler(this.handleBackgroundMessage);

    // Handle notification press
    messaging().onNotificationOpenedApp(this.handleNotificationPress);

    // Check if app was opened from notification (cold start)
    messaging().getInitialNotification().then(this.handleNotificationPress);
  }

  private handleForegroundMessage = async (remoteMessage: FirebaseMessagingTypes.RemoteMessage) => {
    console.log('Foreground message received:', remoteMessage);

    try {
      const payload = this.parseNotificationPayload(remoteMessage);
      
      // Update Redux store if it's a message
      if (payload.type === 'message' && payload.channelId && remoteMessage.data?.message) {
        const message = JSON.parse(remoteMessage.data.message);
        store.dispatch(addMessage({ channelId: payload.channelId, message }));
        store.dispatch(updateChannelLastMessage({ 
          channelId: payload.channelId, 
          lastMessage: message 
        }));
      }

      // Show in-app notification
      await this.showLocalNotification(payload);
    } catch (error) {
      console.error('Error handling foreground message:', error);
    }
  };

  private handleBackgroundMessage = async (remoteMessage: FirebaseMessagingTypes.RemoteMessage) => {
    console.log('Background message received:', remoteMessage);

    try {
      const payload = this.parseNotificationPayload(remoteMessage);
      
      // Store message for when app becomes active
      if (payload.type === 'message' && payload.channelId && remoteMessage.data?.message) {
        // Could store in async storage for later sync
      }

      // Show system notification
      await this.showLocalNotification(payload, true);
    } catch (error) {
      console.error('Error handling background message:', error);
    }
  };

  private handleNotificationPress = (remoteMessage: FirebaseMessagingTypes.RemoteMessage | null) => {
    if (!remoteMessage) return;

    console.log('Notification pressed:', remoteMessage);

    try {
      const payload = this.parseNotificationPayload(remoteMessage);
      
      // Navigate to appropriate screen
      this.navigateFromNotification(payload);
    } catch (error) {
      console.error('Error handling notification press:', error);
    }
  };

  private parseNotificationPayload(remoteMessage: FirebaseMessagingTypes.RemoteMessage): NotificationPayload {
    const { data, notification } = remoteMessage;
    
    return {
      type: (data?.type as any) || 'message',
      channelId: data?.channelId,
      workspaceId: data?.workspaceId,
      senderId: data?.senderId,
      messageId: data?.messageId,
      title: notification?.title || 'New notification',
      body: notification?.body || '',
      data: data || {},
    };
  }

  private async showLocalNotification(payload: NotificationPayload, isBackground = false) {
    try {
      // Check if notifications should be shown
      const settings = await this.getNotificationSettings();
      if (!this.shouldShowNotification(payload, settings)) {
        return;
      }

      const channelId = this.getChannelId(payload.type);
      
      await notifee.displayNotification({
        id: payload.messageId || `${Date.now()}`,
        title: payload.title,
        body: payload.body,
        android: {
          channelId,
          smallIcon: 'ic_notification',
          importance: payload.type === 'mention' ? AndroidImportance.HIGH : AndroidImportance.DEFAULT,
          pressAction: {
            id: 'default',
            launchActivity: 'default',
          },
          actions: payload.type === 'message' ? [
            {
              title: 'Reply',
              pressAction: {
                id: 'reply',
                launchActivity: 'default',
              },
              input: {
                placeholder: 'Type a reply...',
                choices: ['👍', '😀', '❤️'],
              },
            },
            {
              title: 'Mark as Read',
              pressAction: { id: 'mark_read' },
            },
          ] : undefined,
        },
        ios: {
          categoryId: payload.type,
          sound: settings.sound ? 'default' : undefined,
          criticalVolume: payload.type === 'mention' ? 1.0 : 0.8,
          interruptionLevel: payload.type === 'mention' ? 'critical' : 'active',
        },
        data: payload.data,
      });
    } catch (error) {
      console.error('Failed to show local notification:', error);
    }
  }

  private getChannelId(type: NotificationPayload['type']): string {
    switch (type) {
      case 'mention': return 'mentions';
      case 'dm': return 'messages';
      case 'message': return 'messages';
      case 'channel_invite':
      case 'workspace_invite': return 'invites';
      default: return 'system';
    }
  }

  private shouldShowNotification(payload: NotificationPayload, settings: NotificationSettings): boolean {
    if (!settings.enabled) return false;
    if (settings.dndEnabled && settings.dndEndTime && new Date() < settings.dndEndTime) return false;

    // Check quiet hours
    if (settings.quietHours.enabled) {
      const now = new Date();
      const currentTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
      const { start, end } = settings.quietHours;
      
      if (this.isInQuietHours(currentTime, start, end)) {
        return false;
      }
    }

    // Check type-specific settings
    switch (payload.type) {
      case 'mention': return settings.mentions;
      case 'dm': return settings.directMessages;
      case 'message': return settings.channels;
      case 'channel_invite':
      case 'workspace_invite': return settings.workspaceInvites;
      default: return true;
    }
  }

  private isInQuietHours(current: string, start: string, end: string): boolean {
    if (start === end) return false; // No quiet hours set
    
    const currentMinutes = this.timeToMinutes(current);
    const startMinutes = this.timeToMinutes(start);
    const endMinutes = this.timeToMinutes(end);

    if (startMinutes <= endMinutes) {
      // Same day range (e.g., 09:00 - 17:00)
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Overnight range (e.g., 22:00 - 06:00)
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  private timeToMinutes(time: string): number {
    const [hours, minutes] = time.split(':').map(Number);
    return hours * 60 + minutes;
  }

  private navigateFromNotification(payload: NotificationPayload) {
    // This would integrate with your navigation system
    // For now, we'll just log the action
    console.log('Navigate from notification:', payload);
    
    // Example navigation logic:
    // if (payload.type === 'message' && payload.channelId) {
    //   navigationRef.navigate('Chat', { channelId: payload.channelId });
    // }
  }

  private onTokenRefresh = async (token: string) => {
    console.log('FCM Token refreshed:', token);
    this.fcmToken = token;
    // Send updated token to your backend
    await this.sendTokenToBackend(token);
  };

  // Public methods

  async getToken(): Promise<string | null> {
    if (!this.isInitialized) {
      await this.initialize();
    }
    return this.fcmToken;
  }

  async sendTokenToBackend(token?: string): Promise<void> {
    try {
      const fcmToken = token || this.fcmToken;
      if (!fcmToken) return;

      // Send token to your backend API
      // await api.post('/notifications/token', { token: fcmToken });
      console.log('Token sent to backend:', fcmToken);
    } catch (error) {
      console.error('Failed to send token to backend:', error);
    }
  }

  async updateNotificationSettings(settings: Partial<NotificationSettings>): Promise<void> {
    try {
      const currentSettings = await this.getNotificationSettings();
      const newSettings = { ...currentSettings, ...settings };
      
      // Store in secure storage
      // await SecureStorage.setItem('notification_settings', JSON.stringify(newSettings));
      
      // Update backend preferences
      // await api.put('/user/notification-settings', newSettings);
    } catch (error) {
      console.error('Failed to update notification settings:', error);
    }
  }

  async getNotificationSettings(): Promise<NotificationSettings> {
    try {
      // Get from secure storage or return defaults
      // const stored = await SecureStorage.getItem('notification_settings');
      // if (stored) return JSON.parse(stored);

      // Default settings
      return {
        enabled: true,
        sound: true,
        vibration: true,
        badge: true,
        mentions: true,
        directMessages: true,
        channels: true,
        workspaceInvites: true,
        quietHours: {
          enabled: false,
          start: '22:00',
          end: '08:00',
        },
        dndEnabled: false,
      };
    } catch (error) {
      console.error('Failed to get notification settings:', error);
      throw error;
    }
  }

  async setBadgeCount(count: number): Promise<void> {
    try {
      await notifee.setBadgeCount(count);
    } catch (error) {
      console.error('Failed to set badge count:', error);
    }
  }

  async clearBadge(): Promise<void> {
    try {
      await notifee.setBadgeCount(0);
    } catch (error) {
      console.error('Failed to clear badge:', error);
    }
  }

  async cancelNotification(notificationId: string): Promise<void> {
    try {
      await notifee.cancelNotification(notificationId);
    } catch (error) {
      console.error('Failed to cancel notification:', error);
    }
  }

  async cancelAllNotifications(): Promise<void> {
    try {
      await notifee.cancelAllNotifications();
    } catch (error) {
      console.error('Failed to cancel all notifications:', error);
    }
  }

  async scheduleNotification(payload: NotificationPayload, date: Date): Promise<string> {
    try {
      const notificationId = await notifee.createTriggerNotification(
        {
          title: payload.title,
          body: payload.body,
          data: payload.data,
          android: {
            channelId: this.getChannelId(payload.type),
          },
        },
        {
          type: notifee.TriggerType.TIMESTAMP,
          timestamp: date.getTime(),
        }
      );

      return notificationId;
    } catch (error) {
      console.error('Failed to schedule notification:', error);
      throw error;
    }
  }

  destroy(): void {
    if (this.unsubscribeForeground) {
      this.unsubscribeForeground();
      this.unsubscribeForeground = null;
    }
    
    if (this.unsubscribeBackground) {
      this.unsubscribeBackground();
      this.unsubscribeBackground = null;
    }

    this.isInitialized = false;
  }
}

export const notificationService = new NotificationService();
export default notificationService;