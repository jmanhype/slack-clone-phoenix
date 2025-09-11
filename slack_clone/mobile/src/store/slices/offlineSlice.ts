import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { OfflineMessage } from '@types/index';

interface OfflineState {
  isOnline: boolean;
  messages: OfflineMessage[];
  syncQueue: Array<{
    id: string;
    action: 'send_message' | 'edit_message' | 'delete_message' | 'join_channel' | 'leave_channel';
    data: any;
    timestamp: string;
    retryCount: number;
  }>;
  lastSyncAttempt: string | null;
}

const initialState: OfflineState = {
  isOnline: true,
  messages: [],
  syncQueue: [],
  lastSyncAttempt: null,
};

const offlineSlice = createSlice({
  name: 'offline',
  initialState,
  reducers: {
    setOnlineStatus: (state, action: PayloadAction<boolean>) => {
      state.isOnline = action.payload;
    },
    addOfflineMessage: (state, action: PayloadAction<OfflineMessage>) => {
      state.messages.push(action.payload);
    },
    removeOfflineMessage: (state, action: PayloadAction<string>) => {
      state.messages = state.messages.filter(msg => msg.id !== action.payload);
    },
    addToSyncQueue: (state, action: PayloadAction<{
      id: string;
      action: 'send_message' | 'edit_message' | 'delete_message' | 'join_channel' | 'leave_channel';
      data: any;
    }>) => {
      const queueItem = {
        ...action.payload,
        timestamp: new Date().toISOString(),
        retryCount: 0,
      };
      state.syncQueue.push(queueItem);
    },
    removeFromSyncQueue: (state, action: PayloadAction<string>) => {
      state.syncQueue = state.syncQueue.filter(item => item.id !== action.payload);
    },
    incrementRetryCount: (state, action: PayloadAction<string>) => {
      const item = state.syncQueue.find(item => item.id === action.payload);
      if (item) {
        item.retryCount++;
      }
    },
    updateLastSyncAttempt: (state) => {
      state.lastSyncAttempt = new Date().toISOString();
    },
    clearOfflineData: (state) => {
      state.messages = [];
      state.syncQueue = [];
      state.lastSyncAttempt = null;
    },
  },
});

export const {
  setOnlineStatus,
  addOfflineMessage,
  removeOfflineMessage,
  addToSyncQueue,
  removeFromSyncQueue,
  incrementRetryCount,
  updateLastSyncAttempt,
  clearOfflineData,
} = offlineSlice.actions;

export default offlineSlice.reducer;