/**
 * Slack Clone TypeScript SDK
 * 
 * A comprehensive TypeScript SDK for interacting with the Slack Clone API
 * Includes REST API client and WebSocket support with full type safety.
 * 
 * @version 1.0.0
 * @author Slack Clone API Team
 */

// Types and Interfaces
export interface User {
  id: string;
  email: string;
}

export interface UserProfile extends User {
  name?: string;
  avatar_url?: string;
  inserted_at: string;
  updated_at: string;
}

export interface Workspace {
  id: string;
  name: string;
  description?: string;
  is_public: boolean;
  owner_id: string;
  member_count: number;
  inserted_at: string;
  updated_at: string;
}

export interface WorkspaceDetails extends Workspace {
  channels: Channel[];
  members: WorkspaceMember[];
}

export interface WorkspaceMember {
  id: string;
  user: UserProfile;
  role: 'owner' | 'admin' | 'member';
  joined_at: string;
}

export interface Channel {
  id: string;
  name: string;
  type: 'public' | 'private' | 'direct';
  description?: string;
  topic?: string;
  workspace_id: string;
  created_by: string;
  member_count: number;
  unread_count: number;
  last_message_at?: string;
  inserted_at: string;
  updated_at: string;
}

export interface ChannelDetails extends Channel {
  members: ChannelMember[];
  pinned_messages: Message[];
}

export interface ChannelMember {
  id: string;
  user: UserProfile;
  role: 'admin' | 'member';
  joined_at: string;
}

export interface Message {
  id: string;
  content: string;
  channel_id: string;
  user_id: string;
  user: UserProfile;
  thread_id?: string;
  parent_message_id?: string;
  reply_count: number;
  attachments: Attachment[];
  reactions: ReactionSummary[];
  mentions: string[];
  is_edited: boolean;
  edited_at?: string;
  inserted_at: string;
  updated_at: string;
}

export interface Attachment {
  id: string;
  filename: string;
  content_type: string;
  size: number;
  url: string;
  thumbnail_url?: string;
}

export interface Reaction {
  id: string;
  emoji: string;
  message_id: string;
  user_id: string;
  user: UserProfile;
  inserted_at: string;
}

export interface ReactionSummary {
  emoji: string;
  count: number;
  users: UserProfile[];
  user_reacted: boolean;
}

export interface Pagination {
  page: number;
  per_page: number;
  total_pages: number;
  total_count: number;
}

export interface ApiResponse<T> {
  data: T;
}

export interface PaginatedResponse<T> {
  data: T[];
  pagination: Pagination;
}

export interface ApiError {
  error: {
    message: string;
    code?: string;
    details?: Record<string, string[]>;
  };
}

export interface AuthTokens {
  access_token: string;
  refresh_token: string;
  user: User;
}

// Configuration interfaces
export interface SlackCloneConfig {
  baseURL?: string;
  timeout?: number;
  retryAttempts?: number;
  retryDelay?: number;
}

export interface WebSocketConfig {
  url?: string;
  reconnectAfterMs?: number[];
  timeout?: number;
  logger?: (kind: string, msg: string, data: any) => void;
}

// Event interfaces for WebSocket
export interface ChannelEvents {
  new_message: (message: Message) => void;
  message_updated: (message: Message) => void;
  message_deleted: (data: { message_id: string }) => void;
  typing_start: (data: { user_id: string; user_name: string; channel_id: string }) => void;
  typing_stop: (data: { user_id: string; channel_id: string }) => void;
  reaction_added: (data: { message_id: string; reaction: Reaction }) => void;
  reaction_removed: (data: { reaction: Reaction }) => void;
  presence_state: (presences: Record<string, any>) => void;
  presence_diff: (diff: { joins: Record<string, any>; leaves: Record<string, any> }) => void;
  user_joined: (data: { user: UserProfile }) => void;
  user_left: (data: { user_id: string }) => void;
  thread_started: (data: { message_id: string; thread: any }) => void;
  thread_reply: (data: { reply: Message }) => void;
}

// Custom errors
export class SlackCloneError extends Error {
  public readonly code?: string;
  public readonly status?: number;
  public readonly details?: Record<string, string[]>;

  constructor(message: string, code?: string, status?: number, details?: Record<string, string[]>) {
    super(message);
    this.name = 'SlackCloneError';
    this.code = code;
    this.status = status;
    this.details = details;
  }
}

export class AuthenticationError extends SlackCloneError {
  constructor(message: string = 'Authentication failed') {
    super(message, 'AUTHENTICATION_ERROR', 401);
    this.name = 'AuthenticationError';
  }
}

export class TokenExpiredError extends SlackCloneError {
  constructor(message: string = 'Token has expired') {
    super(message, 'TOKEN_EXPIRED', 401);
    this.name = 'TokenExpiredError';
  }
}

export class RateLimitError extends SlackCloneError {
  public readonly retryAfter: number;

  constructor(message: string = 'Rate limit exceeded', retryAfter: number = 60) {
    super(message, 'RATE_LIMIT_EXCEEDED', 429);
    this.name = 'RateLimitError';
    this.retryAfter = retryAfter;
  }
}

// HTTP Client implementation
export class HTTPClient {
  private baseURL: string;
  private timeout: number;
  private retryAttempts: number;
  private retryDelay: number;

  constructor(config: SlackCloneConfig = {}) {
    this.baseURL = config.baseURL || 'https://api.slackclone.com';
    this.timeout = config.timeout || 30000;
    this.retryAttempts = config.retryAttempts || 3;
    this.retryDelay = config.retryDelay || 1000;
  }

  async request<T>(
    method: string,
    endpoint: string,
    data?: any,
    headers: Record<string, string> = {}
  ): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;
    const config: RequestInit = {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
      signal: AbortSignal.timeout(this.timeout),
    };

    if (data && (method === 'POST' || method === 'PUT' || method === 'PATCH')) {
      config.body = JSON.stringify(data);
    }

    let lastError: Error;

    for (let attempt = 0; attempt <= this.retryAttempts; attempt++) {
      try {
        const response = await fetch(url, config);
        
        if (!response.ok) {
          await this.handleErrorResponse(response);
        }

        return await response.json();
      } catch (error) {
        lastError = error as Error;
        
        if (attempt < this.retryAttempts && this.shouldRetry(error as Error)) {
          await this.sleep(this.retryDelay * Math.pow(2, attempt));
          continue;
        }
        
        throw error;
      }
    }

    throw lastError!;
  }

  private async handleErrorResponse(response: Response): Promise<never> {
    let errorData: ApiError;
    
    try {
      errorData = await response.json();
    } catch {
      errorData = {
        error: {
          message: `HTTP ${response.status}: ${response.statusText}`,
          code: response.status.toString(),
        },
      };
    }

    const { message, code, details } = errorData.error;

    switch (response.status) {
      case 401:
        if (code === 'TOKEN_EXPIRED') {
          throw new TokenExpiredError(message);
        }
        throw new AuthenticationError(message);
      case 403:
        throw new SlackCloneError(message, code, response.status, details);
      case 429:
        const retryAfter = parseInt(response.headers.get('Retry-After') || '60');
        throw new RateLimitError(message, retryAfter);
      default:
        throw new SlackCloneError(message, code, response.status, details);
    }
  }

  private shouldRetry(error: Error): boolean {
    // Retry on network errors, timeouts, or 5xx server errors
    return (
      error.name === 'TypeError' || // Network error
      error.name === 'AbortError' || // Timeout
      (error instanceof SlackCloneError && error.status && error.status >= 500)
    );
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Authentication service
export class AuthService {
  private httpClient: HTTPClient;
  private accessToken: string | null = null;
  private refreshToken: string | null = null;

  constructor(httpClient: HTTPClient) {
    this.httpClient = httpClient;
  }

  async login(email: string, password: string): Promise<AuthTokens> {
    const response = await this.httpClient.request<ApiResponse<AuthTokens>>(
      'POST',
      '/api/auth/login',
      { email, password }
    );

    const tokens = response.data;
    this.accessToken = tokens.access_token;
    this.refreshToken = tokens.refresh_token;

    return tokens;
  }

  async refreshAccessToken(): Promise<string> {
    if (!this.refreshToken) {
      throw new AuthenticationError('No refresh token available');
    }

    const response = await this.httpClient.request<ApiResponse<{ access_token: string }>>(
      'POST',
      '/api/auth/refresh',
      { refresh_token: this.refreshToken }
    );

    this.accessToken = response.data.access_token;
    return this.accessToken;
  }

  async logout(): Promise<void> {
    if (this.accessToken) {
      try {
        await this.httpClient.request(
          'POST',
          '/api/auth/logout',
          {},
          { Authorization: `Bearer ${this.accessToken}` }
        );
      } catch (error) {
        // Ignore logout errors
        console.warn('Logout request failed:', error);
      }
    }

    this.accessToken = null;
    this.refreshToken = null;
  }

  getAccessToken(): string | null {
    return this.accessToken;
  }

  setTokens(accessToken: string, refreshToken: string): void {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  isAuthenticated(): boolean {
    return !!this.accessToken;
  }

  async makeAuthenticatedRequest<T>(
    method: string,
    endpoint: string,
    data?: any
  ): Promise<T> {
    const headers: Record<string, string> = {};

    if (this.accessToken) {
      headers.Authorization = `Bearer ${this.accessToken}`;
    }

    try {
      return await this.httpClient.request<T>(method, endpoint, data, headers);
    } catch (error) {
      if (error instanceof TokenExpiredError && this.refreshToken) {
        try {
          await this.refreshAccessToken();
          headers.Authorization = `Bearer ${this.accessToken}`;
          return await this.httpClient.request<T>(method, endpoint, data, headers);
        } catch (refreshError) {
          // Clear tokens on refresh failure
          this.accessToken = null;
          this.refreshToken = null;
          throw new AuthenticationError('Token refresh failed');
        }
      }
      throw error;
    }
  }
}

// WebSocket client
export class WebSocketClient {
  private socket: any; // Phoenix Socket type
  private config: WebSocketConfig;
  private channels = new Map<string, any>();

  constructor(config: WebSocketConfig = {}) {
    this.config = {
      url: config.url || 'ws://localhost:4000/socket/websocket',
      reconnectAfterMs: config.reconnectAfterMs || [1000, 5000, 10000],
      timeout: config.timeout || 30000,
      logger: config.logger,
    };
  }

  connect(token: string): Promise<void> {
    return new Promise((resolve, reject) => {
      // Note: This assumes Phoenix.Socket is available
      // In a real implementation, you'd import it from 'phoenix' package
      if (typeof (window as any).Phoenix === 'undefined') {
        reject(new Error('Phoenix.Socket is not available'));
        return;
      }

      const Socket = (window as any).Phoenix.Socket;

      this.socket = new Socket(this.config.url, {
        params: { token },
        reconnectAfterMs: () => this.config.reconnectAfterMs,
        timeout: this.config.timeout,
        logger: this.config.logger,
      });

      this.socket.onOpen(() => resolve());
      this.socket.onError((error: any) => reject(error));
      this.socket.onClose(() => console.log('WebSocket connection closed'));

      this.socket.connect();
    });
  }

  joinChannel(channelId: string, callbacks: Partial<ChannelEvents> = {}): Promise<any> {
    return new Promise((resolve, reject) => {
      const topic = `channel:${channelId}`;
      const channel = this.socket.channel(topic);

      // Set up event listeners
      Object.entries(callbacks).forEach(([event, callback]) => {
        if (callback) {
          channel.on(event, callback);
        }
      });

      // Join the channel
      channel.join()
        .receive('ok', (response: any) => {
          this.channels.set(channelId, channel);
          resolve(response);
        })
        .receive('error', (response: any) => {
          reject(new Error(`Failed to join channel: ${response.reason}`));
        });
    });
  }

  leaveChannel(channelId: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const channel = this.channels.get(channelId);
      if (!channel) {
        resolve();
        return;
      }

      channel.leave()
        .receive('ok', () => {
          this.channels.delete(channelId);
          resolve();
        })
        .receive('error', (response: any) => {
          reject(new Error(`Failed to leave channel: ${response.reason}`));
        });
    });
  }

  sendMessage(channelId: string, content: string, tempId?: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const channel = this.channels.get(channelId);
      if (!channel) {
        reject(new Error(`Not connected to channel: ${channelId}`));
        return;
      }

      channel.push('send_message', {
        content,
        temp_id: tempId || Date.now().toString(),
      })
        .receive('ok', () => resolve())
        .receive('error', (response: any) => {
          reject(new Error(`Failed to send message: ${JSON.stringify(response.errors)}`));
        });
    });
  }

  editMessage(channelId: string, messageId: string, content: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const channel = this.channels.get(channelId);
      if (!channel) {
        reject(new Error(`Not connected to channel: ${channelId}`));
        return;
      }

      channel.push('edit_message', {
        message_id: messageId,
        content,
      })
        .receive('ok', () => resolve())
        .receive('error', (response: any) => {
          reject(new Error(`Failed to edit message: ${response.reason}`));
        });
    });
  }

  deleteMessage(channelId: string, messageId: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const channel = this.channels.get(channelId);
      if (!channel) {
        reject(new Error(`Not connected to channel: ${channelId}`));
        return;
      }

      channel.push('delete_message', {
        message_id: messageId,
      })
        .receive('ok', () => resolve())
        .receive('error', (response: any) => {
          reject(new Error(`Failed to delete message: ${response.reason}`));
        });
    });
  }

  startTyping(channelId: string): void {
    const channel = this.channels.get(channelId);
    if (channel) {
      channel.push('typing_start');
    }
  }

  stopTyping(channelId: string): void {
    const channel = this.channels.get(channelId);
    if (channel) {
      channel.push('typing_stop');
    }
  }

  addReaction(channelId: string, messageId: string, emoji: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const channel = this.channels.get(channelId);
      if (!channel) {
        reject(new Error(`Not connected to channel: ${channelId}`));
        return;
      }

      channel.push('add_reaction', {
        message_id: messageId,
        emoji,
      })
        .receive('ok', () => resolve())
        .receive('error', (response: any) => {
          reject(new Error(`Failed to add reaction: ${response.reason}`));
        });
    });
  }

  removeReaction(channelId: string, reactionId: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const channel = this.channels.get(channelId);
      if (!channel) {
        reject(new Error(`Not connected to channel: ${channelId}`));
        return;
      }

      channel.push('remove_reaction', {
        reaction_id: reactionId,
      })
        .receive('ok', () => resolve())
        .receive('error', (response: any) => {
          reject(new Error(`Failed to remove reaction: ${response.reason}`));
        });
    });
  }

  markAsRead(channelId: string, messageId: string): void {
    const channel = this.channels.get(channelId);
    if (channel) {
      channel.push('mark_read', { message_id: messageId });
    }
  }

  loadOlderMessages(channelId: string, beforeId: string): Promise<Message[]> {
    return new Promise((resolve, reject) => {
      const channel = this.channels.get(channelId);
      if (!channel) {
        reject(new Error(`Not connected to channel: ${channelId}`));
        return;
      }

      channel.push('load_older_messages', {
        before_id: beforeId,
      })
        .receive('ok', (response: { messages: Message[] }) => {
          resolve(response.messages);
        })
        .receive('error', (response: any) => {
          reject(new Error(`Failed to load messages: ${response.reason}`));
        });
    });
  }

  disconnect(): void {
    if (this.socket) {
      this.socket.disconnect();
      this.channels.clear();
    }
  }
}

// Main SDK class
export class SlackCloneSDK {
  private httpClient: HTTPClient;
  private authService: AuthService;
  private wsClient: WebSocketClient;

  constructor(config: SlackCloneConfig = {}, wsConfig: WebSocketConfig = {}) {
    this.httpClient = new HTTPClient(config);
    this.authService = new AuthService(this.httpClient);
    this.wsClient = new WebSocketClient(wsConfig);
  }

  // Authentication methods
  get auth() {
    return {
      login: this.authService.login.bind(this.authService),
      logout: this.authService.logout.bind(this.authService),
      refreshToken: this.authService.refreshAccessToken.bind(this.authService),
      isAuthenticated: this.authService.isAuthenticated.bind(this.authService),
      setTokens: this.authService.setTokens.bind(this.authService),
      getAccessToken: this.authService.getAccessToken.bind(this.authService),
    };
  }

  // WebSocket methods
  get ws() {
    return {
      connect: (token: string) => this.wsClient.connect(token),
      disconnect: () => this.wsClient.disconnect(),
      joinChannel: this.wsClient.joinChannel.bind(this.wsClient),
      leaveChannel: this.wsClient.leaveChannel.bind(this.wsClient),
      sendMessage: this.wsClient.sendMessage.bind(this.wsClient),
      editMessage: this.wsClient.editMessage.bind(this.wsClient),
      deleteMessage: this.wsClient.deleteMessage.bind(this.wsClient),
      startTyping: this.wsClient.startTyping.bind(this.wsClient),
      stopTyping: this.wsClient.stopTyping.bind(this.wsClient),
      addReaction: this.wsClient.addReaction.bind(this.wsClient),
      removeReaction: this.wsClient.removeReaction.bind(this.wsClient),
      markAsRead: this.wsClient.markAsRead.bind(this.wsClient),
      loadOlderMessages: this.wsClient.loadOlderMessages.bind(this.wsClient),
    };
  }

  // User API methods
  async getCurrentUser(): Promise<UserProfile> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<UserProfile>>(
      'GET',
      '/api/me'
    );
    return response.data;
  }

  async updateCurrentUser(updates: Partial<Pick<UserProfile, 'email' | 'name' | 'avatar_url'>>): Promise<UserProfile> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<UserProfile>>(
      'PUT',
      '/api/me',
      { user: updates }
    );
    return response.data;
  }

  // Workspace API methods
  async getWorkspaces(page: number = 1, limit: number = 20): Promise<PaginatedResponse<Workspace>> {
    return await this.authService.makeAuthenticatedRequest<PaginatedResponse<Workspace>>(
      'GET',
      `/api/workspaces?page=${page}&limit=${limit}`
    );
  }

  async getWorkspace(workspaceId: string): Promise<WorkspaceDetails> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<WorkspaceDetails>>(
      'GET',
      `/api/workspaces/${workspaceId}`
    );
    return response.data;
  }

  async createWorkspace(data: {
    name: string;
    description?: string;
    is_public?: boolean;
  }): Promise<Workspace> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<Workspace>>(
      'POST',
      '/api/workspaces',
      data
    );
    return response.data;
  }

  async updateWorkspace(workspaceId: string, data: {
    name?: string;
    description?: string;
    is_public?: boolean;
  }): Promise<Workspace> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<Workspace>>(
      'PUT',
      `/api/workspaces/${workspaceId}`,
      data
    );
    return response.data;
  }

  async deleteWorkspace(workspaceId: string): Promise<void> {
    await this.authService.makeAuthenticatedRequest(
      'DELETE',
      `/api/workspaces/${workspaceId}`
    );
  }

  // Channel API methods
  async getChannels(workspaceId: string, filters: {
    type?: 'public' | 'private' | 'direct';
    member?: boolean;
  } = {}): Promise<Channel[]> {
    const params = new URLSearchParams();
    if (filters.type) params.append('type', filters.type);
    if (filters.member !== undefined) params.append('member', filters.member.toString());

    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<Channel[]>>(
      'GET',
      `/api/workspaces/${workspaceId}/channels?${params.toString()}`
    );
    return response.data;
  }

  async getChannel(workspaceId: string, channelId: string): Promise<ChannelDetails> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<ChannelDetails>>(
      'GET',
      `/api/workspaces/${workspaceId}/channels/${channelId}`
    );
    return response.data;
  }

  async createChannel(workspaceId: string, data: {
    name: string;
    type: 'public' | 'private';
    description?: string;
    topic?: string;
  }): Promise<Channel> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<Channel>>(
      'POST',
      `/api/workspaces/${workspaceId}/channels`,
      data
    );
    return response.data;
  }

  async updateChannel(workspaceId: string, channelId: string, data: {
    name?: string;
    description?: string;
    topic?: string;
  }): Promise<Channel> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<Channel>>(
      'PUT',
      `/api/workspaces/${workspaceId}/channels/${channelId}`,
      data
    );
    return response.data;
  }

  async deleteChannel(workspaceId: string, channelId: string): Promise<void> {
    await this.authService.makeAuthenticatedRequest(
      'DELETE',
      `/api/workspaces/${workspaceId}/channels/${channelId}`
    );
  }

  // Message API methods
  async getMessages(workspaceId: string, channelId: string, options: {
    before?: string;
    after?: string;
    limit?: number;
    include_threads?: boolean;
  } = {}): Promise<{ data: Message[]; has_more: boolean; cursor?: string }> {
    const params = new URLSearchParams();
    if (options.before) params.append('before', options.before);
    if (options.after) params.append('after', options.after);
    if (options.limit) params.append('limit', options.limit.toString());
    if (options.include_threads) params.append('include_threads', options.include_threads.toString());

    return await this.authService.makeAuthenticatedRequest(
      'GET',
      `/api/workspaces/${workspaceId}/channels/${channelId}/messages?${params.toString()}`
    );
  }

  async sendMessage(workspaceId: string, channelId: string, data: {
    content: string;
    thread_id?: string;
    attachments?: Attachment[];
  }): Promise<Message> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<Message>>(
      'POST',
      `/api/workspaces/${workspaceId}/channels/${channelId}/messages`,
      data
    );
    return response.data;
  }

  async editMessage(messageId: string, content: string): Promise<Message> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<Message>>(
      'PUT',
      `/api/messages/${messageId}`,
      { content }
    );
    return response.data;
  }

  async deleteMessage(messageId: string): Promise<void> {
    await this.authService.makeAuthenticatedRequest(
      'DELETE',
      `/api/messages/${messageId}`
    );
  }

  async addReaction(messageId: string, emoji: string): Promise<Reaction> {
    const response = await this.authService.makeAuthenticatedRequest<ApiResponse<Reaction>>(
      'POST',
      `/api/messages/${messageId}/reactions`,
      { emoji }
    );
    return response.data;
  }

  async removeReaction(messageId: string, reactionId: string): Promise<void> {
    await this.authService.makeAuthenticatedRequest(
      'DELETE',
      `/api/messages/${messageId}/reactions/${reactionId}`
    );
  }
}

// Export default instance
export default SlackCloneSDK;

// Usage examples (for documentation)
/*
// Basic usage
const sdk = new SlackCloneSDK({
  baseURL: 'https://api.slackclone.com',
  timeout: 30000,
});

// Authentication
try {
  const tokens = await sdk.auth.login('user@example.com', 'password');
  console.log('Logged in:', tokens);
} catch (error) {
  console.error('Login failed:', error);
}

// WebSocket connection
await sdk.ws.connect(sdk.auth.getAccessToken()!);

// Join a channel and set up event listeners
await sdk.ws.joinChannel('channel-id', {
  new_message: (message) => {
    console.log('New message:', message);
  },
  typing_start: (data) => {
    console.log('User started typing:', data.user_name);
  },
  presence_diff: (diff) => {
    console.log('Presence update:', diff);
  },
});

// Send a message
await sdk.ws.sendMessage('channel-id', 'Hello world!');

// Get workspaces
const workspaces = await sdk.getWorkspaces();
console.log('Workspaces:', workspaces);

// Create a channel
const channel = await sdk.createChannel('workspace-id', {
  name: 'general',
  type: 'public',
  description: 'General discussion',
});

// Get messages
const messages = await sdk.getMessages('workspace-id', 'channel-id', {
  limit: 50,
  include_threads: true,
});
*/