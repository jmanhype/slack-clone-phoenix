import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-community/netinfo';
import BackgroundJob from 'react-native-background-job';
import { store } from '../store';
import { syncOfflineMessages, syncOfflineReactions, syncOfflineEdits } from '../store/slices/syncSlice';
import { updateConnectionStatus } from '../store/slices/appSlice';
import { socketService } from './socket';
import { notificationService } from './notifications';

export interface SyncQueueItem {
  id: string;
  type: 'message' | 'reaction' | 'edit' | 'delete' | 'typing' | 'presence';
  channelId: string;
  workspaceId: string;
  payload: any;
  timestamp: number;
  retryCount: number;
  maxRetries: number;
  priority: 'low' | 'medium' | 'high';
}

export interface BackgroundSyncConfig {
  enabled: boolean;
  syncInterval: number; // minutes
  maxRetries: number;
  retryDelay: number; // milliseconds
  batchSize: number;
  lowPowerMode: boolean;
  wifiOnly: boolean;
}

class BackgroundSyncService {
  private isInitialized = false;
  private syncInterval: NodeJS.Timeout | null = null;
  private syncQueue: SyncQueueItem[] = [];
  private isSyncing = false;
  private networkListener: (() => void) | null = null;
  private backgroundJobStarted = false;

  private readonly SYNC_QUEUE_KEY = 'sync_queue';
  private readonly SYNC_CONFIG_KEY = 'sync_config';
  private readonly LAST_SYNC_KEY = 'last_sync_timestamp';

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    try {
      // Load persisted sync queue
      await this.loadSyncQueue();

      // Set up network listener
      this.setupNetworkListener();

      // Start background job
      await this.startBackgroundJob();

      // Schedule regular sync
      await this.scheduleSync();

      this.isInitialized = true;
      console.log('Background sync service initialized');
    } catch (error) {
      console.error('Failed to initialize background sync:', error);
      throw error;
    }
  }

  private async loadSyncQueue(): Promise<void> {
    try {
      const queueData = await AsyncStorage.getItem(this.SYNC_QUEUE_KEY);
      if (queueData) {
        this.syncQueue = JSON.parse(queueData);
        console.log(`Loaded ${this.syncQueue.length} items from sync queue`);
      }
    } catch (error) {
      console.error('Failed to load sync queue:', error);
      this.syncQueue = [];
    }
  }

  private async persistSyncQueue(): Promise<void> {
    try {
      await AsyncStorage.setItem(this.SYNC_QUEUE_KEY, JSON.stringify(this.syncQueue));
    } catch (error) {
      console.error('Failed to persist sync queue:', error);
    }
  }

  private setupNetworkListener(): void {
    this.networkListener = NetInfo.addEventListener(state => {
      const isConnected = state.isConnected && state.isInternetReachable;
      
      // Update Redux store
      store.dispatch(updateConnectionStatus({
        isConnected,
        connectionType: state.type,
        isInternetReachable: state.isInternetReachable || false,
      }));

      // If we're back online, sync immediately
      if (isConnected && this.syncQueue.length > 0) {
        console.log('Network restored, starting sync...');
        this.syncNow();
      }
    });
  }

  private async startBackgroundJob(): Promise<void> {
    if (this.backgroundJobStarted) return;

    try {
      BackgroundJob.on('background', () => {
        console.log('App entered background, starting background sync job');
        this.performBackgroundSync();
      });

      BackgroundJob.on('foreground', () => {
        console.log('App entered foreground, syncing immediately');
        this.syncNow();
      });

      this.backgroundJobStarted = true;
    } catch (error) {
      console.error('Failed to start background job:', error);
    }
  }

  private async scheduleSync(): Promise<void> {
    const config = await this.getSyncConfig();
    
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
    }

    this.syncInterval = setInterval(() => {
      if (!this.isSyncing && this.syncQueue.length > 0) {
        this.syncNow();
      }
    }, config.syncInterval * 60 * 1000);
  }

  private async performBackgroundSync(): Promise<void> {
    try {
      // Check if background sync is allowed
      const config = await this.getSyncConfig();
      if (!config.enabled) return;

      // Check network conditions
      const netInfo = await NetInfo.fetch();
      if (!netInfo.isConnected || !netInfo.isInternetReachable) return;

      if (config.wifiOnly && netInfo.type !== 'wifi') {
        console.log('Background sync: WiFi-only mode, skipping');
        return;
      }

      // Perform sync with limited processing
      await this.syncWithBatching(Math.min(config.batchSize, 10));
    } catch (error) {
      console.error('Background sync failed:', error);
    }
  }

  // Public methods

  async addToSyncQueue(item: Omit<SyncQueueItem, 'id' | 'timestamp' | 'retryCount'>): Promise<void> {
    const syncItem: SyncQueueItem = {
      ...item,
      id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: Date.now(),
      retryCount: 0,
    };

    // Add to queue with priority ordering
    this.insertByPriority(syncItem);
    
    // Persist queue
    await this.persistSyncQueue();

    // If we're online, try to sync immediately
    const netInfo = await NetInfo.fetch();
    if (netInfo.isConnected && netInfo.isInternetReachable && !this.isSyncing) {
      this.syncNow();
    }

    console.log(`Added item to sync queue: ${syncItem.type}`, syncItem);
  }

  private insertByPriority(item: SyncQueueItem): void {
    const priorityOrder = { high: 3, medium: 2, low: 1 };
    const itemPriority = priorityOrder[item.priority];

    let insertIndex = this.syncQueue.length;
    for (let i = 0; i < this.syncQueue.length; i++) {
      const queuePriority = priorityOrder[this.syncQueue[i].priority];
      if (itemPriority > queuePriority) {
        insertIndex = i;
        break;
      }
    }

    this.syncQueue.splice(insertIndex, 0, item);
  }

  async syncNow(): Promise<void> {
    if (this.isSyncing || this.syncQueue.length === 0) return;

    this.isSyncing = true;
    console.log(`Starting sync of ${this.syncQueue.length} items...`);

    try {
      const config = await this.getSyncConfig();
      await this.syncWithBatching(config.batchSize);
    } catch (error) {
      console.error('Sync failed:', error);
    } finally {
      this.isSyncing = false;
    }
  }

  private async syncWithBatching(batchSize: number): Promise<void> {
    const config = await this.getSyncConfig();
    const batch = this.syncQueue.slice(0, batchSize);
    
    if (batch.length === 0) return;

    console.log(`Syncing batch of ${batch.length} items`);

    const results = await Promise.allSettled(
      batch.map(item => this.processSyncItem(item))
    );

    // Process results and handle retries
    const toRemove: string[] = [];
    const toRetry: SyncQueueItem[] = [];

    results.forEach((result, index) => {
      const item = batch[index];
      
      if (result.status === 'fulfilled') {
        toRemove.push(item.id);
        console.log(`Synced successfully: ${item.type} ${item.id}`);
      } else {
        console.error(`Sync failed for ${item.type} ${item.id}:`, result.reason);
        
        if (item.retryCount < config.maxRetries) {
          toRetry.push({
            ...item,
            retryCount: item.retryCount + 1,
          });
        } else {
          console.warn(`Max retries exceeded for ${item.type} ${item.id}, removing from queue`);
          toRemove.push(item.id);
        }
      }
    });

    // Remove completed and failed items
    this.syncQueue = this.syncQueue.filter(item => !toRemove.includes(item.id));

    // Add retry items back to queue
    toRetry.forEach(item => {
      setTimeout(() => {
        this.insertByPriority(item);
      }, config.retryDelay * item.retryCount);
    });

    // Update last sync timestamp
    await AsyncStorage.setItem(this.LAST_SYNC_KEY, Date.now().toString());

    // Persist updated queue
    await this.persistSyncQueue();

    // Continue with next batch if there are more items
    if (this.syncQueue.length > 0 && !config.lowPowerMode) {
      setTimeout(() => this.syncWithBatching(batchSize), 1000);
    }
  }

  private async processSyncItem(item: SyncQueueItem): Promise<void> {
    switch (item.type) {
      case 'message':
        await this.syncMessage(item);
        break;
      case 'reaction':
        await this.syncReaction(item);
        break;
      case 'edit':
        await this.syncEdit(item);
        break;
      case 'delete':
        await this.syncDelete(item);
        break;
      case 'typing':
        await this.syncTyping(item);
        break;
      case 'presence':
        await this.syncPresence(item);
        break;
      default:
        throw new Error(`Unknown sync item type: ${item.type}`);
    }
  }

  private async syncMessage(item: SyncQueueItem): Promise<void> {
    try {
      // Send message through socket service
      await socketService.sendMessage(item.channelId, item.payload);
      
      // Update Redux store
      store.dispatch(syncOfflineMessages([item.id]));
    } catch (error) {
      console.error('Failed to sync message:', error);
      throw error;
    }
  }

  private async syncReaction(item: SyncQueueItem): Promise<void> {
    try {
      await socketService.addReaction(item.channelId, item.payload.messageId, item.payload.emoji);
      store.dispatch(syncOfflineReactions([item.id]));
    } catch (error) {
      console.error('Failed to sync reaction:', error);
      throw error;
    }
  }

  private async syncEdit(item: SyncQueueItem): Promise<void> {
    try {
      await socketService.editMessage(item.channelId, item.payload.messageId, item.payload.content);
      store.dispatch(syncOfflineEdits([item.id]));
    } catch (error) {
      console.error('Failed to sync edit:', error);
      throw error;
    }
  }

  private async syncDelete(item: SyncQueueItem): Promise<void> {
    try {
      await socketService.deleteMessage(item.channelId, item.payload.messageId);
    } catch (error) {
      console.error('Failed to sync delete:', error);
      throw error;
    }
  }

  private async syncTyping(item: SyncQueueItem): Promise<void> {
    try {
      await socketService.sendTyping(item.channelId, item.payload.isTyping);
    } catch (error) {
      console.error('Failed to sync typing:', error);
      throw error;
    }
  }

  private async syncPresence(item: SyncQueueItem): Promise<void> {
    try {
      await socketService.updatePresence(item.payload.status);
    } catch (error) {
      console.error('Failed to sync presence:', error);
      throw error;
    }
  }

  async getSyncConfig(): Promise<BackgroundSyncConfig> {
    try {
      const configData = await AsyncStorage.getItem(this.SYNC_CONFIG_KEY);
      if (configData) {
        return JSON.parse(configData);
      }
    } catch (error) {
      console.error('Failed to get sync config:', error);
    }

    // Default config
    return {
      enabled: true,
      syncInterval: 5, // 5 minutes
      maxRetries: 3,
      retryDelay: 2000, // 2 seconds
      batchSize: 20,
      lowPowerMode: false,
      wifiOnly: false,
    };
  }

  async updateSyncConfig(config: Partial<BackgroundSyncConfig>): Promise<void> {
    try {
      const currentConfig = await this.getSyncConfig();
      const newConfig = { ...currentConfig, ...config };
      
      await AsyncStorage.setItem(this.SYNC_CONFIG_KEY, JSON.stringify(newConfig));
      
      // Reschedule sync with new interval
      if (config.syncInterval !== undefined) {
        await this.scheduleSync();
      }

      console.log('Sync config updated:', newConfig);
    } catch (error) {
      console.error('Failed to update sync config:', error);
      throw error;
    }
  }

  async getLastSyncTime(): Promise<number | null> {
    try {
      const timestamp = await AsyncStorage.getItem(this.LAST_SYNC_KEY);
      return timestamp ? parseInt(timestamp, 10) : null;
    } catch (error) {
      console.error('Failed to get last sync time:', error);
      return null;
    }
  }

  async getSyncQueueStatus(): Promise<{
    totalItems: number;
    pendingItems: number;
    failedItems: number;
    lastSyncTime: number | null;
    isOnline: boolean;
  }> {
    const netInfo = await NetInfo.fetch();
    const lastSyncTime = await this.getLastSyncTime();

    return {
      totalItems: this.syncQueue.length,
      pendingItems: this.syncQueue.filter(item => item.retryCount === 0).length,
      failedItems: this.syncQueue.filter(item => item.retryCount > 0).length,
      lastSyncTime,
      isOnline: netInfo.isConnected && netInfo.isInternetReachable || false,
    };
  }

  async clearSyncQueue(): Promise<void> {
    this.syncQueue = [];
    await this.persistSyncQueue();
    console.log('Sync queue cleared');
  }

  async pauseSync(): Promise<void> {
    const config = await this.getSyncConfig();
    await this.updateSyncConfig({ ...config, enabled: false });
    
    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }

    console.log('Background sync paused');
  }

  async resumeSync(): Promise<void> {
    const config = await this.getSyncConfig();
    await this.updateSyncConfig({ ...config, enabled: true });
    
    await this.scheduleSync();
    
    // Sync immediately if we have items
    if (this.syncQueue.length > 0) {
      this.syncNow();
    }

    console.log('Background sync resumed');
  }

  destroy(): void {
    if (this.networkListener) {
      this.networkListener();
      this.networkListener = null;
    }

    if (this.syncInterval) {
      clearInterval(this.syncInterval);
      this.syncInterval = null;
    }

    BackgroundJob.off('background');
    BackgroundJob.off('foreground');

    this.isInitialized = false;
    console.log('Background sync service destroyed');
  }
}

export const backgroundSyncService = new BackgroundSyncService();
export default backgroundSyncService;