import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { Appearance } from 'react-native';
import { SettingsState } from '@types/index';

const initialState: SettingsState = {
  theme: 'system',
  notifications: {
    push: true,
    sound: true,
    vibration: true,
    channels: true,
    directMessages: true,
    mentions: true,
  },
  language: 'en',
  fontSize: 'medium',
};

const settingsSlice = createSlice({
  name: 'settings',
  initialState,
  reducers: {
    setTheme: (state, action: PayloadAction<'light' | 'dark' | 'system'>) => {
      state.theme = action.payload;
    },
    updateNotificationSettings: (state, action: PayloadAction<Partial<typeof initialState.notifications>>) => {
      state.notifications = { ...state.notifications, ...action.payload };
    },
    setLanguage: (state, action: PayloadAction<string>) => {
      state.language = action.payload;
    },
    setFontSize: (state, action: PayloadAction<'small' | 'medium' | 'large'>) => {
      state.fontSize = action.payload;
    },
    resetSettings: () => initialState,
  },
});

export const {
  setTheme,
  updateNotificationSettings,
  setLanguage,
  setFontSize,
  resetSettings,
} = settingsSlice.actions;

export default settingsSlice.reducer;