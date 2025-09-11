import { Socket, Channel } from 'phoenix';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { AppState, AppStateStatus } from 'react-native';
import NetInfo from '@react-native-community/netinfo';
import { Message, User, PresenceState } from '@types/index';

const SOCKET_URL = __DEV__ ? 'ws://localhost:4000/socket' : 'wss://your-production-url.com/socket';

export interface SocketEventCallbacks {
  onConnect?: () => void;
  onDisconnect?: () => void;
  onError?: (error: any) => void;
  onMessage?: (message: Message) => void;
  onMessageUpdated?: (message: Message) => void;
  onMessageDeleted?: (messageId: string) => void;
  onTypingStart?: (user: User) => void;
  onTypingStop?: (user: User) => void;
  onPresenceState?: (presences: PresenceState) => void;
  onPresenceDiff?: (diff: any) => void;
  onUserJoined?: (user: User) => void;
  onUserLeft?: (userId: string) => void;
  onReactionAdded?: (data: any) => void;
  onReactionRemoved?: (data: any) => void;
}

class SocketService {
  private socket: Socket | null = null;
  private channels: Map<string, Channel> = new Map();
  private callbacks: SocketEventCallbacks = {};
  private reconnectTimer: NodeJS.Timeout | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000;
  private isAppActive = true;
  private isConnected = false;
  private pendingMessages: Array<{ channelId: string; event: string; payload: any }> = [];

  constructor() {
    this.setupAppStateListener();
    this.setupNetworkListener();
  }

  private setupAppStateListener() {
    AppState.addEventListener('change', (nextAppState: AppStateStatus) => {
      this.isAppActive = nextAppState === 'active';
      
      if (this.isAppActive && this.socket && !this.isConnected) {
        this.reconnect();
      } else if (!this.isAppActive && this.socket && this.isConnected) {
        // Optionally disconnect when app goes to background
        // this.disconnect();
      }
    });
  }

  private setupNetworkListener() {
    NetInfo.addEventListener(state => {
      if (state.isConnected && !this.isConnected && this.socket) {
        this.reconnect();
      }
    });
  }

  async connect(token?: string): Promise<void> {
    try {
      const authToken = token || await AsyncStorage.getItem('@auth_token');
      
      if (!authToken) {
        throw new Error('No authentication token available');
      }

      if (this.socket) {
        this.disconnect();
      }

      this.socket = new Socket(SOCKET_URL, {
        params: { token: authToken },
        transport: WebSocket,
        heartbeatIntervalMs: 30000,
        rejoinAfterMs: (tries) => {
          return [1000, 2000, 5000][tries - 1] || 10000;
        },
        reconnectAfterMs: (tries) => {
          return [1000, 2000, 5000][tries - 1] || 10000;
        },
        logger: __DEV__ ? console.log : undefined,
      });

      this.socket.onOpen(() => {
        console.log('Socket connected');
        this.isConnected = true;
        this.reconnectAttempts = 0;
        this.callbacks.onConnect?.();
        this.flushPendingMessages();
      });

      this.socket.onClose(() => {
        console.log('Socket disconnected');
        this.isConnected = false;
        this.callbacks.onDisconnect?.();
        this.handleReconnection();
      });

      this.socket.onError((error) => {
        console.error('Socket error:', error);
        this.callbacks.onError?.(error);
      });

      this.socket.connect();

    } catch (error) {
      console.error('Failed to connect socket:', error);
      throw error;
    }
  }

  disconnect(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }

    this.channels.forEach(channel => channel.leave());
    this.channels.clear();

    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }

    this.isConnected = false;
    this.reconnectAttempts = 0;
  }

  private handleReconnection(): void {
    if (!this.isAppActive || this.reconnectAttempts >= this.maxReconnectAttempts) {
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1);

    this.reconnectTimer = setTimeout(() => {
      console.log(`Reconnecting... Attempt ${this.reconnectAttempts}`);
      this.reconnect();
    }, delay);
  }

  private async reconnect(): Promise<void> {
    try {
      await this.connect();
      
      // Rejoin all channels
      const channelIds = Array.from(this.channels.keys());
      this.channels.clear();
      
      for (const channelId of channelIds) {
        await this.joinChannel(channelId);
      }
    } catch (error) {
      console.error('Reconnection failed:', error);
      this.handleReconnection();
    }
  }

  async joinChannel(channelId: string): Promise<Channel | null> {
    if (!this.socket) {
      console.error('Socket not connected');
      return null;
    }

    if (this.channels.has(channelId)) {
      return this.channels.get(channelId)!;
    }

    const channel = this.socket.channel(`channel:${channelId}`, {});

    // Set up channel event handlers
    this.setupChannelHandlers(channel);

    try {
      await new Promise<void>((resolve, reject) => {
        channel.join()
          .receive('ok', () => {
            console.log(`Joined channel: ${channelId}`);
            this.channels.set(channelId, channel);
            resolve();
          })
          .receive('error', (error) => {
            console.error(`Failed to join channel ${channelId}:`, error);
            reject(error);
          })
          .receive('timeout', () => {
            console.error(`Timeout joining channel: ${channelId}`);
            reject(new Error('Join timeout'));
          });
      });

      return channel;
    } catch (error) {
      console.error('Error joining channel:', error);
      return null;
    }
  }

  leaveChannel(channelId: string): void {
    const channel = this.channels.get(channelId);
    if (channel) {
      channel.leave();
      this.channels.delete(channelId);
    }
  }

  private setupChannelHandlers(channel: Channel): void {
    // Message events
    channel.on('new_message', (message: Message) => {
      this.callbacks.onMessage?.(message);
    });

    channel.on('message_updated', (message: Message) => {
      this.callbacks.onMessageUpdated?.(message);
    });

    channel.on('message_deleted', ({ message_id }: { message_id: string }) => {
      this.callbacks.onMessageDeleted?.(message_id);
    });

    // Typing events
    channel.on('typing_start', (data: { user: User }) => {
      this.callbacks.onTypingStart?.(data.user);
    });

    channel.on('typing_stop', (data: { user: User }) => {
      this.callbacks.onTypingStop?.(data.user);
    });

    // Presence events
    channel.on('presence_state', (presences: PresenceState) => {
      this.callbacks.onPresenceState?.(presences);
    });

    channel.on('presence_diff', (diff: any) => {
      this.callbacks.onPresenceDiff?.(diff);
    });

    // User events
    channel.on('user_joined', (data: { user: User }) => {
      this.callbacks.onUserJoined?.(data.user);
    });

    channel.on('user_left', (data: { user_id: string }) => {
      this.callbacks.onUserLeft?.(data.user_id);
    });

    // Reaction events
    channel.on('reaction_added', (data: any) => {
      this.callbacks.onReactionAdded?.(data);
    });

    channel.on('reaction_removed', (data: any) => {
      this.callbacks.onReactionRemoved?.(data);
    });
  }

  sendMessage(channelId: string, content: string, tempId?: string): void {
    this.pushToChannel(channelId, 'send_message', {
      content,
      temp_id: tempId,
    });
  }

  editMessage(channelId: string, messageId: string, content: string): void {
    this.pushToChannel(channelId, 'edit_message', {
      message_id: messageId,
      content,
    });
  }

  deleteMessage(channelId: string, messageId: string): void {
    this.pushToChannel(channelId, 'delete_message', {
      message_id: messageId,
    });
  }

  startTyping(channelId: string): void {
    this.pushToChannel(channelId, 'typing_start', {});
  }

  stopTyping(channelId: string): void {
    this.pushToChannel(channelId, 'typing_stop', {});
  }

  addReaction(channelId: string, messageId: string, emoji: string): void {
    this.pushToChannel(channelId, 'add_reaction', {
      message_id: messageId,
      emoji,
    });
  }

  removeReaction(channelId: string, reactionId: string): void {
    this.pushToChannel(channelId, 'remove_reaction', {
      reaction_id: reactionId,
    });
  }

  markAsRead(channelId: string, messageId: string): void {
    this.pushToChannel(channelId, 'mark_read', {
      message_id: messageId,
    });
  }

  loadOlderMessages(channelId: string, beforeId: string): void {
    this.pushToChannel(channelId, 'load_older_messages', {
      before_id: beforeId,
    });
  }

  private pushToChannel(channelId: string, event: string, payload: any): void {
    const channel = this.channels.get(channelId);
    
    if (channel && this.isConnected) {
      channel.push(event, payload);
    } else {
      // Queue message for when connection is restored
      this.pendingMessages.push({ channelId, event, payload });
    }
  }

  private flushPendingMessages(): void {
    const messages = [...this.pendingMessages];
    this.pendingMessages = [];

    messages.forEach(({ channelId, event, payload }) => {
      this.pushToChannel(channelId, event, payload);
    });
  }

  setCallbacks(callbacks: SocketEventCallbacks): void {
    this.callbacks = { ...this.callbacks, ...callbacks };
  }

  isSocketConnected(): boolean {
    return this.isConnected;
  }

  getConnectedChannels(): string[] {
    return Array.from(this.channels.keys());
  }
}

export default new SocketService();