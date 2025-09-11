import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import AsyncStorage from '@react-native-async-storage/async-storage';
import apiService from '@services/api';
import { AuthState, User, LoginRequest, RegisterRequest } from '@types/index';

// Async thunks
export const loginUser = createAsyncThunk(
  'auth/login',
  async (credentials: LoginRequest, { rejectWithValue }) => {
    try {
      const response = await apiService.login(credentials);
      if (response.success) {
        return response.data;
      } else {
        return rejectWithValue(response.message || 'Login failed');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Login failed');
    }
  }
);

export const registerUser = createAsyncThunk(
  'auth/register',
  async (userData: RegisterRequest, { rejectWithValue }) => {
    try {
      const response = await apiService.register(userData);
      if (response.success) {
        return response.data;
      } else {
        return rejectWithValue(response.message || 'Registration failed');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Registration failed');
    }
  }
);

export const getCurrentUser = createAsyncThunk(
  'auth/getCurrentUser',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.getCurrentUser();
      if (response.success) {
        return response.data;
      } else {
        return rejectWithValue(response.message || 'Failed to get user');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to get user');
    }
  }
);

export const updateProfile = createAsyncThunk(
  'auth/updateProfile',
  async (userData: Partial<User>, { rejectWithValue }) => {
    try {
      const response = await apiService.updateProfile(userData);
      if (response.success) {
        return response.data;
      } else {
        return rejectWithValue(response.message || 'Profile update failed');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Profile update failed');
    }
  }
);

export const refreshToken = createAsyncThunk(
  'auth/refreshToken',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.refreshToken();
      if (response.success) {
        return response.data.token;
      } else {
        return rejectWithValue(response.message || 'Token refresh failed');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Token refresh failed');
    }
  }
);

export const logoutUser = createAsyncThunk(
  'auth/logout',
  async (_, { dispatch }) => {
    try {
      await apiService.logout();
    } catch (error) {
      console.error('Logout error:', error);
    }
    
    // Clear all stored data
    await AsyncStorage.multiRemove(['@auth_token', '@user_data']);
    return null;
  }
);

// Initial state
const initialState: AuthState = {
  user: null,
  token: null,
  isAuthenticated: false,
  isLoading: false,
  error: null,
  biometricEnabled: false,
};

// Slice
const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null;
    },
    setBiometricEnabled: (state, action: PayloadAction<boolean>) => {
      state.biometricEnabled = action.payload;
    },
    setToken: (state, action: PayloadAction<string | null>) => {
      state.token = action.payload;
      state.isAuthenticated = !!action.payload;
      if (action.payload) {
        apiService.setToken(action.payload);
      }
    },
    updateUserStatus: (state, action: PayloadAction<'online' | 'offline' | 'away' | 'busy'>) => {
      if (state.user) {
        state.user.status = action.payload;
      }
    },
    resetAuth: (state) => {
      state.user = null;
      state.token = null;
      state.isAuthenticated = false;
      state.error = null;
      state.isLoading = false;
    },
  },
  extraReducers: (builder) => {
    // Login
    builder.addCase(loginUser.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(loginUser.fulfilled, (state, action) => {
      state.isLoading = false;
      state.user = action.payload.user;
      state.token = action.payload.token;
      state.isAuthenticated = true;
      state.error = null;
      apiService.setToken(action.payload.token);
    });
    builder.addCase(loginUser.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
      state.isAuthenticated = false;
    });

    // Register
    builder.addCase(registerUser.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(registerUser.fulfilled, (state, action) => {
      state.isLoading = false;
      state.user = action.payload.user;
      state.token = action.payload.token;
      state.isAuthenticated = true;
      state.error = null;
      apiService.setToken(action.payload.token);
    });
    builder.addCase(registerUser.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
      state.isAuthenticated = false;
    });

    // Get current user
    builder.addCase(getCurrentUser.pending, (state) => {
      state.isLoading = true;
    });
    builder.addCase(getCurrentUser.fulfilled, (state, action) => {
      state.isLoading = false;
      state.user = action.payload;
      state.isAuthenticated = true;
      state.error = null;
    });
    builder.addCase(getCurrentUser.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
      // Don't reset authentication on user fetch failure
    });

    // Update profile
    builder.addCase(updateProfile.pending, (state) => {
      state.isLoading = true;
      state.error = null;
    });
    builder.addCase(updateProfile.fulfilled, (state, action) => {
      state.isLoading = false;
      state.user = action.payload;
      state.error = null;
    });
    builder.addCase(updateProfile.rejected, (state, action) => {
      state.isLoading = false;
      state.error = action.payload as string;
    });

    // Refresh token
    builder.addCase(refreshToken.fulfilled, (state, action) => {
      state.token = action.payload;
      apiService.setToken(action.payload);
    });
    builder.addCase(refreshToken.rejected, (state) => {
      // Token refresh failed, user needs to log in again
      state.user = null;
      state.token = null;
      state.isAuthenticated = false;
    });

    // Logout
    builder.addCase(logoutUser.fulfilled, (state) => {
      state.user = null;
      state.token = null;
      state.isAuthenticated = false;
      state.error = null;
      state.isLoading = false;
      state.biometricEnabled = false;
      apiService.setToken(null);
    });
  },
});

export const {
  clearError,
  setBiometricEnabled,
  setToken,
  updateUserStatus,
  resetAuth,
} = authSlice.actions;

export default authSlice.reducer;