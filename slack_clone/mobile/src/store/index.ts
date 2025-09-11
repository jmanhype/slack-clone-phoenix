import { configureStore, combineReducers } from '@reduxjs/toolkit';
import {
  persistStore,
  persistReducer,
  FLUSH,
  REHYDRATE,
  PAUSE,
  PERSIST,
  PURGE,
  REGISTER,
} from 'redux-persist';
import AsyncStorage from '@react-native-async-storage/async-storage';
import EncryptedStorage from 'react-native-encrypted-storage';

import authSlice from './slices/authSlice';
import chatSlice from './slices/chatSlice';
import settingsSlice from './slices/settingsSlice';
import offlineSlice from './slices/offlineSlice';

// Create separate persist configs for different security needs
const securePersistConfig = {
  key: 'auth',
  storage: EncryptedStorage,
  whitelist: ['token', 'user', 'biometricEnabled'],
};

const standardPersistConfig = {
  key: 'app',
  storage: AsyncStorage,
  whitelist: ['settings'],
};

const chatPersistConfig = {
  key: 'chat',
  storage: AsyncStorage,
  whitelist: ['workspaces', 'channels'],
  blacklist: ['messages', 'typingUsers', 'onlineUsers', 'isConnected'],
};

const offlinePersistConfig = {
  key: 'offline',
  storage: AsyncStorage,
  whitelist: ['messages', 'syncQueue'],
};

// Create persisted reducers
const persistedAuthReducer = persistReducer(securePersistConfig, authSlice);
const persistedChatReducer = persistReducer(chatPersistConfig, chatSlice);
const persistedOfflineReducer = persistReducer(offlinePersistConfig, offlineSlice);

const rootReducer = combineReducers({
  auth: persistedAuthReducer,
  chat: persistedChatReducer,
  settings: persistReducer(standardPersistConfig, settingsSlice),
  offline: persistedOfflineReducer,
});

export const store = configureStore({
  reducer: rootReducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: [FLUSH, REHYDRATE, PAUSE, PERSIST, PURGE, REGISTER],
      },
    }),
  devTools: __DEV__,
});

export const persistor = persistStore(store);

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;