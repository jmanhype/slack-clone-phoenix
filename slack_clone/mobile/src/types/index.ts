// User types
export interface User {
  id: string;
  name: string;
  email: string;
  avatar_url?: string;
  status: 'online' | 'offline' | 'away' | 'busy';
  timezone?: string;
  created_at: string;
  updated_at: string;
}

// Workspace types
export interface Workspace {
  id: string;
  name: string;
  slug: string;
  description?: string;
  logo_url?: string;
  created_at: string;
  updated_at: string;
}

// Channel types
export interface Channel {
  id: string;
  name: string;
  description?: string;
  type: 'public' | 'private' | 'direct';
  workspace_id: string;
  created_by: string;
  topic?: string;
  created_at: string;
  updated_at: string;
  unread_count?: number;
  last_message?: Message;
}

// Message types
export interface Message {
  id: string;
  content: string;
  user_id: string;
  channel_id: string;
  thread_id?: string;
  type: 'text' | 'file' | 'image' | 'voice';
  attachments?: Attachment[];
  reactions?: Reaction[];
  mentions?: string[];
  edited_at?: string;
  created_at: string;
  updated_at: string;
  temp_id?: string;
  user?: User;
}

// Attachment types
export interface Attachment {
  id: string;
  filename: string;
  content_type: string;
  size: number;
  url: string;
  thumbnail_url?: string;
}

// Reaction types
export interface Reaction {
  id: string;
  emoji: string;
  count: number;
  users: string[];
  user_reacted: boolean;
}

// Thread types
export interface Thread {
  id: string;
  message_id: string;
  reply_count: number;
  participants: User[];
  last_reply_at: string;
  replies?: Message[];
}

// Navigation types
export type RootStackParamList = {
  Splash: undefined;
  Auth: undefined;
  Main: undefined;
};

export type AuthStackParamList = {
  Login: undefined;
  Register: undefined;
  ForgotPassword: undefined;
  BiometricSetup: undefined;
};

export type MainTabParamList = {
  Home: undefined;
  Channels: undefined;
  DirectMessages: undefined;
  Profile: undefined;
};

export type HomeStackParamList = {
  WorkspaceList: undefined;
  ChannelList: { workspaceId: string };
  Chat: { channelId: string; channelName: string };
  Thread: { threadId: string; messageId: string };
};

// Redux state types
export interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  biometricEnabled: boolean;
}

export interface ChatState {
  workspaces: Workspace[];
  channels: Channel[];
  messages: { [channelId: string]: Message[] };
  currentWorkspace: Workspace | null;
  currentChannel: Channel | null;
  typingUsers: { [channelId: string]: User[] };
  onlineUsers: User[];
  isConnected: boolean;
  isLoading: boolean;
}

export interface SettingsState {
  theme: 'light' | 'dark' | 'system';
  notifications: {
    push: boolean;
    sound: boolean;
    vibration: boolean;
    channels: boolean;
    directMessages: boolean;
    mentions: boolean;
  };
  language: string;
  fontSize: 'small' | 'medium' | 'large';
}

// Socket types
export interface SocketMessage {
  event: string;
  payload: any;
  ref?: string;
}

export interface PresenceState {
  [userId: string]: {
    name: string;
    avatar_url?: string;
    joined_at: number;
  };
}

// API types
export interface ApiResponse<T> {
  data: T;
  message?: string;
  success: boolean;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface RegisterRequest {
  name: string;
  email: string;
  password: string;
  password_confirmation: string;
}

export interface SendMessageRequest {
  content: string;
  channel_id: string;
  temp_id?: string;
  thread_id?: string;
  attachments?: Attachment[];
}

// Notification types
export interface PushNotification {
  title: string;
  body: string;
  data?: {
    channelId?: string;
    messageId?: string;
    threadId?: string;
  };
}

// Offline types
export interface OfflineMessage extends Omit<SendMessageRequest, 'temp_id'> {
  id: string;
  created_at: string;
  retry_count: number;
}

// Gesture types
export interface SwipeAction {
  id: string;
  title: string;
  color: string;
  icon: string;
  action: () => void;
}

// File types
export interface FileUploadResult {
  uri: string;
  type: string;
  fileName: string;
  fileSize: number;
}

// Voice recording types
export interface VoiceRecording {
  uri: string;
  duration: number;
  size: number;
}