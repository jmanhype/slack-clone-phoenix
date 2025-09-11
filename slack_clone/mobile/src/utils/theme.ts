import { DefaultTheme, DarkTheme } from '@react-navigation/native';

export const lightTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    primary: '#007AFF',
    background: '#FFFFFF',
    card: '#F2F2F2',
    text: '#000000',
    border: '#C7C7CC',
    notification: '#FF3B30',
    surface: '#FFFFFF',
    accent: '#5AC8FA',
    placeholder: '#8E8E93',
    disabled: '#C7C7CC',
    success: '#34C759',
    warning: '#FF9500',
    error: '#FF3B30',
    info: '#007AFF',
  },
};

export const darkTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    primary: '#0A84FF',
    background: '#1C1C1E',
    card: '#2C2C2E',
    text: '#FFFFFF',
    border: '#38383A',
    notification: '#FF453A',
    surface: '#2C2C2E',
    accent: '#64D2FF',
    placeholder: '#8E8E93',
    disabled: '#48484A',
    success: '#30D158',
    warning: '#FF9F0A',
    error: '#FF453A',
    info: '#0A84FF',
  },
};

export const getThemeColors = (isDark: boolean) => {
  return isDark ? darkTheme.colors : lightTheme.colors;
};