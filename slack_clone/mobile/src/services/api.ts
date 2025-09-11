import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  User,
  Workspace,
  Channel,
  Message,
  ApiResponse,
  LoginRequest,
  RegisterRequest,
  SendMessageRequest,
} from '@types/index';

const API_BASE_URL = __DEV__ ? 'http://localhost:4000/api' : 'https://your-production-url.com/api';

class ApiService {
  private baseURL: string;
  private token: string | null = null;

  constructor() {
    this.baseURL = API_BASE_URL;
    this.initializeToken();
  }

  private async initializeToken() {
    try {
      this.token = await AsyncStorage.getItem('@auth_token');
    } catch (error) {
      console.error('Failed to load token:', error);
    }
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<ApiResponse<T>> {
    const url = `${this.baseURL}${endpoint}`;
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    if (this.token) {
      headers.Authorization = `Bearer ${this.token}`;
    }

    try {
      const response = await fetch(url, {
        ...options,
        headers,
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || `HTTP ${response.status}`);
      }

      return data;
    } catch (error) {
      console.error(`API request failed: ${endpoint}`, error);
      throw error;
    }
  }

  // Auth methods
  async login(credentials: LoginRequest): Promise<ApiResponse<{ user: User; token: string }>> {
    const response = await this.request<{ user: User; token: string }>('/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    });

    if (response.success && response.data.token) {
      this.token = response.data.token;
      await AsyncStorage.setItem('@auth_token', response.data.token);
    }

    return response;
  }

  async register(userData: RegisterRequest): Promise<ApiResponse<{ user: User; token: string }>> {
    const response = await this.request<{ user: User; token: string }>('/auth/register', {
      method: 'POST',
      body: JSON.stringify(userData),
    });

    if (response.success && response.data.token) {
      this.token = response.data.token;
      await AsyncStorage.setItem('@auth_token', response.data.token);
    }

    return response;
  }

  async logout(): Promise<void> {
    try {
      await this.request('/auth/logout', { method: 'POST' });
    } catch (error) {
      console.error('Logout request failed:', error);
    } finally {
      this.token = null;
      await AsyncStorage.removeItem('@auth_token');
    }
  }

  async refreshToken(): Promise<ApiResponse<{ token: string }>> {
    const response = await this.request<{ token: string }>('/auth/refresh', {
      method: 'POST',
    });

    if (response.success) {
      this.token = response.data.token;
      await AsyncStorage.setItem('@auth_token', response.data.token);
    }

    return response;
  }

  // User methods
  async getCurrentUser(): Promise<ApiResponse<User>> {
    return this.request<User>('/users/me');
  }

  async updateProfile(userData: Partial<User>): Promise<ApiResponse<User>> {
    return this.request<User>('/users/me', {
      method: 'PUT',
      body: JSON.stringify(userData),
    });
  }

  // Workspace methods
  async getWorkspaces(): Promise<ApiResponse<Workspace[]>> {
    return this.request<Workspace[]>('/workspaces');
  }

  async getWorkspace(workspaceId: string): Promise<ApiResponse<Workspace>> {
    return this.request<Workspace>(`/workspaces/${workspaceId}`);
  }

  async createWorkspace(workspaceData: Partial<Workspace>): Promise<ApiResponse<Workspace>> {
    return this.request<Workspace>('/workspaces', {
      method: 'POST',
      body: JSON.stringify(workspaceData),
    });
  }

  // Channel methods
  async getChannels(workspaceId: string): Promise<ApiResponse<Channel[]>> {
    return this.request<Channel[]>(`/workspaces/${workspaceId}/channels`);
  }

  async getChannel(channelId: string): Promise<ApiResponse<Channel>> {
    return this.request<Channel>(`/channels/${channelId}`);
  }

  async createChannel(
    workspaceId: string,
    channelData: Partial<Channel>
  ): Promise<ApiResponse<Channel>> {
    return this.request<Channel>(`/workspaces/${workspaceId}/channels`, {
      method: 'POST',
      body: JSON.stringify(channelData),
    });
  }

  async joinChannel(channelId: string): Promise<ApiResponse<void>> {
    return this.request<void>(`/channels/${channelId}/join`, {
      method: 'POST',
    });
  }

  async leaveChannel(channelId: string): Promise<ApiResponse<void>> {
    return this.request<void>(`/channels/${channelId}/leave`, {
      method: 'DELETE',
    });
  }

  // Message methods
  async getMessages(
    channelId: string,
    limit = 50,
    beforeId?: string
  ): Promise<ApiResponse<Message[]>> {
    const params = new URLSearchParams({
      limit: limit.toString(),
      ...(beforeId && { before_id: beforeId }),
    });

    return this.request<Message[]>(`/channels/${channelId}/messages?${params}`);
  }

  async sendMessage(messageData: SendMessageRequest): Promise<ApiResponse<Message>> {
    return this.request<Message>('/messages', {
      method: 'POST',
      body: JSON.stringify(messageData),
    });
  }

  async editMessage(messageId: string, content: string): Promise<ApiResponse<Message>> {
    return this.request<Message>(`/messages/${messageId}`, {
      method: 'PUT',
      body: JSON.stringify({ content }),
    });
  }

  async deleteMessage(messageId: string): Promise<ApiResponse<void>> {
    return this.request<void>(`/messages/${messageId}`, {
      method: 'DELETE',
    });
  }

  async addReaction(messageId: string, emoji: string): Promise<ApiResponse<void>> {
    return this.request<void>(`/messages/${messageId}/reactions`, {
      method: 'POST',
      body: JSON.stringify({ emoji }),
    });
  }

  async removeReaction(messageId: string, emoji: string): Promise<ApiResponse<void>> {
    return this.request<void>(`/messages/${messageId}/reactions/${emoji}`, {
      method: 'DELETE',
    });
  }

  // File upload methods
  async uploadFile(uri: string, fileName: string, type: string): Promise<ApiResponse<string>> {
    const formData = new FormData();
    formData.append('file', {
      uri,
      name: fileName,
      type,
    } as any);

    const response = await fetch(`${this.baseURL}/files/upload`, {
      method: 'POST',
      headers: {
        'Content-Type': 'multipart/form-data',
        ...(this.token && { Authorization: `Bearer ${this.token}` }),
      },
      body: formData,
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || `Upload failed: ${response.status}`);
    }

    return data;
  }

  // Search methods
  async searchMessages(
    workspaceId: string,
    query: string,
    channelId?: string
  ): Promise<ApiResponse<Message[]>> {
    const params = new URLSearchParams({
      q: query,
      ...(channelId && { channel_id: channelId }),
    });

    return this.request<Message[]>(`/workspaces/${workspaceId}/search/messages?${params}`);
  }

  async searchChannels(workspaceId: string, query: string): Promise<ApiResponse<Channel[]>> {
    const params = new URLSearchParams({ q: query });
    return this.request<Channel[]>(`/workspaces/${workspaceId}/search/channels?${params}`);
  }

  // Notification methods
  async updatePushToken(token: string): Promise<ApiResponse<void>> {
    return this.request<void>('/users/push-token', {
      method: 'PUT',
      body: JSON.stringify({ push_token: token }),
    });
  }

  async getNotificationSettings(): Promise<ApiResponse<any>> {
    return this.request<any>('/users/notification-settings');
  }

  async updateNotificationSettings(settings: any): Promise<ApiResponse<any>> {
    return this.request<any>('/users/notification-settings', {
      method: 'PUT',
      body: JSON.stringify(settings),
    });
  }

  // Utility methods
  setToken(token: string | null) {
    this.token = token;
  }

  getToken(): string | null {
    return this.token;
  }
}

export default new ApiService();