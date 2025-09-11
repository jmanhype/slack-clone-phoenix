import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import apiService from '@services/api';
import socketService from '@services/socket';
import { ChatState, Workspace, Channel, Message, User, PresenceState } from '@types/index';

// Async thunks
export const fetchWorkspaces = createAsyncThunk(
  'chat/fetchWorkspaces',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.getWorkspaces();
      if (response.success) {
        return response.data;
      } else {
        return rejectWithValue(response.message || 'Failed to fetch workspaces');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch workspaces');
    }
  }
);

export const fetchChannels = createAsyncThunk(
  'chat/fetchChannels',
  async (workspaceId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getChannels(workspaceId);
      if (response.success) {
        return { workspaceId, channels: response.data };
      } else {
        return rejectWithValue(response.message || 'Failed to fetch channels');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch channels');
    }
  }
);

export const fetchMessages = createAsyncThunk(
  'chat/fetchMessages',
  async ({ channelId, limit, beforeId }: { channelId: string; limit?: number; beforeId?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getMessages(channelId, limit, beforeId);
      if (response.success) {
        return { channelId, messages: response.data, isLoadingMore: !!beforeId };
      } else {
        return rejectWithValue(response.message || 'Failed to fetch messages');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch messages');
    }
  }
);

export const sendMessage = createAsyncThunk(
  'chat/sendMessage',
  async ({ channelId, content, tempId }: { channelId: string; content: string; tempId?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.sendMessage({ channel_id: channelId, content, temp_id: tempId });
      if (response.success) {
        return { channelId, message: response.data, tempId };
      } else {
        return rejectWithValue(response.message || 'Failed to send message');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to send message');
    }
  }
);

export const editMessage = createAsyncThunk(
  'chat/editMessage',
  async ({ messageId, content }: { messageId: string; content: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.editMessage(messageId, content);
      if (response.success) {
        return response.data;
      } else {
        return rejectWithValue(response.message || 'Failed to edit message');
      }
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to edit message');
    }
  }
);

export const deleteMessage = createAsyncThunk(
  'chat/deleteMessage',
  async (messageId: string, { rejectWithValue }) => {
    try {
      await apiService.deleteMessage(messageId);
      return messageId;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to delete message');
    }
  }
);

export const joinChannel = createAsyncThunk(
  'chat/joinChannel',
  async (channelId: string, { rejectWithValue }) => {
    try {
      await apiService.joinChannel(channelId);
      const channel = await socketService.joinChannel(channelId);
      return { channelId, success: !!channel };
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to join channel');
    }
  }
);

export const leaveChannel = createAsyncThunk(
  'chat/leaveChannel',
  async (channelId: string, { rejectWithValue }) => {
    try {
      await apiService.leaveChannel(channelId);
      socketService.leaveChannel(channelId);
      return channelId;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to leave channel');
    }
  }
);

// Initial state
const initialState: ChatState = {
  workspaces: [],
  channels: [],
  messages: {},
  currentWorkspace: null,
  currentChannel: null,
  typingUsers: {},
  onlineUsers: [],
  isConnected: false,
  isLoading: false,
};

// Helper functions
const findChannelById = (channels: Channel[], channelId: string): Channel | undefined => {
  return channels.find(channel => channel.id === channelId);
};

const updateChannelMessages = (
  messages: { [channelId: string]: Message[] },
  channelId: string,
  newMessages: Message[],
  isLoadingMore = false
): { [channelId: string]: Message[] } => {
  const existingMessages = messages[channelId] || [];
  
  if (isLoadingMore) {
    // Prepend older messages
    return {
      ...messages,
      [channelId]: [...newMessages, ...existingMessages],
    };
  } else {
    // Replace with new messages (initial load)
    return {
      ...messages,
      [channelId]: newMessages,
    };
  }
};

// Slice
const chatSlice = createSlice({
  name: 'chat',
  initialState,
  reducers: {
    setCurrentWorkspace: (state, action: PayloadAction<Workspace | null>) => {
      state.currentWorkspace = action.payload;
    },
    setCurrentChannel: (state, action: PayloadAction<Channel | null>) => {
      state.currentChannel = action.payload;
    },
    setConnectionStatus: (state, action: PayloadAction<boolean>) => {
      state.isConnected = action.payload;
    },
    addMessage: (state, action: PayloadAction<{ channelId: string; message: Message }>) => {
      const { channelId, message } = action.payload;
      if (!state.messages[channelId]) {
        state.messages[channelId] = [];
      }
      
      // Check if message already exists (avoid duplicates)
      const existingIndex = state.messages[channelId].findIndex(m => m.id === message.id);
      if (existingIndex === -1) {
        state.messages[channelId].push(message);
      }
    },
    updateMessage: (state, action: PayloadAction<Message>) => {
      const message = action.payload;
      const channelMessages = state.messages[message.channel_id];
      if (channelMessages) {
        const index = channelMessages.findIndex(m => m.id === message.id);
        if (index !== -1) {
          channelMessages[index] = message;
        }
      }
    },
    removeMessage: (state, action: PayloadAction<{ channelId: string; messageId: string }>) => {
      const { channelId, messageId } = action.payload;
      const channelMessages = state.messages[channelId];
      if (channelMessages) {
        state.messages[channelId] = channelMessages.filter(m => m.id !== messageId);
      }
    },
    addTempMessage: (state, action: PayloadAction<{ channelId: string; message: Message }>) => {
      const { channelId, message } = action.payload;
      if (!state.messages[channelId]) {
        state.messages[channelId] = [];
      }
      state.messages[channelId].push(message);
    },
    removeTempMessage: (state, action: PayloadAction<{ channelId: string; tempId: string }>) => {
      const { channelId, tempId } = action.payload;
      const channelMessages = state.messages[channelId];
      if (channelMessages) {
        state.messages[channelId] = channelMessages.filter(m => m.temp_id !== tempId);
      }
    },
    updateTempMessage: (state, action: PayloadAction<{ channelId: string; tempId: string; message: Message }>) => {
      const { channelId, tempId, message } = action.payload;
      const channelMessages = state.messages[channelId];
      if (channelMessages) {
        const index = channelMessages.findIndex(m => m.temp_id === tempId);
        if (index !== -1) {
          channelMessages[index] = message;
        }
      }
    },
    setTypingUsers: (state, action: PayloadAction<{ channelId: string; users: User[] }>) => {
      const { channelId, users } = action.payload;
      state.typingUsers[channelId] = users;
    },
    addTypingUser: (state, action: PayloadAction<{ channelId: string; user: User }>) => {
      const { channelId, user } = action.payload;
      if (!state.typingUsers[channelId]) {
        state.typingUsers[channelId] = [];
      }
      const existingIndex = state.typingUsers[channelId].findIndex(u => u.id === user.id);
      if (existingIndex === -1) {
        state.typingUsers[channelId].push(user);
      }
    },
    removeTypingUser: (state, action: PayloadAction<{ channelId: string; userId: string }>) => {
      const { channelId, userId } = action.payload;
      if (state.typingUsers[channelId]) {
        state.typingUsers[channelId] = state.typingUsers[channelId].filter(u => u.id !== userId);
      }
    },
    setOnlineUsers: (state, action: PayloadAction<User[]>) => {
      state.onlineUsers = action.payload;
    },
    updatePresence: (state, action: PayloadAction<PresenceState>) => {
      // Convert presence state to online users
      const onlineUsers = Object.entries(action.payload).map(([userId, presence]) => ({
        id: userId,
        name: presence.name,
        avatar_url: presence.avatar_url,
        status: 'online' as const,
        email: '',
        timezone: '',
        created_at: '',
        updated_at: '',
      }));
      state.onlineUsers = onlineUsers;
    },
    updateChannelUnreadCount: (state, action: PayloadAction<{ channelId: string; count: number }>) => {
      const { channelId, count } = action.payload;
      const channel = state.channels.find(c => c.id === channelId);
      if (channel) {
        channel.unread_count = count;
      }
    },
    markChannelAsRead: (state, action: PayloadAction<string>) => {
      const channelId = action.payload;
      const channel = state.channels.find(c => c.id === channelId);
      if (channel) {
        channel.unread_count = 0;
      }
    },
    clearMessages: (state, action: PayloadAction<string>) => {
      const channelId = action.payload;
      delete state.messages[channelId];
    },
    clearAllData: (state) => {
      state.workspaces = [];
      state.channels = [];
      state.messages = {};
      state.currentWorkspace = null;
      state.currentChannel = null;
      state.typingUsers = {};
      state.onlineUsers = [];
    },
  },
  extraReducers: (builder) => {
    // Fetch workspaces
    builder.addCase(fetchWorkspaces.pending, (state) => {
      state.isLoading = true;
    });
    builder.addCase(fetchWorkspaces.fulfilled, (state, action) => {
      state.isLoading = false;
      state.workspaces = action.payload;
    });
    builder.addCase(fetchWorkspaces.rejected, (state) => {
      state.isLoading = false;
    });

    // Fetch channels
    builder.addCase(fetchChannels.fulfilled, (state, action) => {
      const { workspaceId, channels } = action.payload;
      // Replace channels for this workspace
      state.channels = [
        ...state.channels.filter(c => c.workspace_id !== workspaceId),
        ...channels,
      ];
    });

    // Fetch messages
    builder.addCase(fetchMessages.fulfilled, (state, action) => {
      const { channelId, messages, isLoadingMore } = action.payload;
      state.messages = updateChannelMessages(state.messages, channelId, messages, isLoadingMore);
    });

    // Send message
    builder.addCase(sendMessage.fulfilled, (state, action) => {
      const { channelId, message, tempId } = action.payload;
      
      // Remove temp message if it exists
      if (tempId && state.messages[channelId]) {
        state.messages[channelId] = state.messages[channelId].filter(m => m.temp_id !== tempId);
      }
      
      // Add the actual message
      if (!state.messages[channelId]) {
        state.messages[channelId] = [];
      }
      state.messages[channelId].push(message);
    });

    // Edit message
    builder.addCase(editMessage.fulfilled, (state, action) => {
      const message = action.payload;
      const channelMessages = state.messages[message.channel_id];
      if (channelMessages) {
        const index = channelMessages.findIndex(m => m.id === message.id);
        if (index !== -1) {
          channelMessages[index] = message;
        }
      }
    });

    // Delete message
    builder.addCase(deleteMessage.fulfilled, (state, action) => {
      const messageId = action.payload;
      // Find and remove message from all channels
      Object.keys(state.messages).forEach(channelId => {
        state.messages[channelId] = state.messages[channelId].filter(m => m.id !== messageId);
      });
    });

    // Join channel
    builder.addCase(joinChannel.fulfilled, (state, action) => {
      const { channelId } = action.payload;
      const channel = state.channels.find(c => c.id === channelId);
      if (channel) {
        // Mark channel as joined or update status
        // This could include adding user to channel members, etc.
      }
    });

    // Leave channel
    builder.addCase(leaveChannel.fulfilled, (state, action) => {
      const channelId = action.payload;
      // Remove channel from list or update status
      state.channels = state.channels.filter(c => c.id !== channelId);
      delete state.messages[channelId];
      delete state.typingUsers[channelId];
      
      if (state.currentChannel?.id === channelId) {
        state.currentChannel = null;
      }
    });
  },
});

export const {
  setCurrentWorkspace,
  setCurrentChannel,
  setConnectionStatus,
  addMessage,
  updateMessage,
  removeMessage,
  addTempMessage,
  removeTempMessage,
  updateTempMessage,
  setTypingUsers,
  addTypingUser,
  removeTypingUser,
  setOnlineUsers,
  updatePresence,
  updateChannelUnreadCount,
  markChannelAsRead,
  clearMessages,
  clearAllData,
} = chatSlice.actions;

export default chatSlice.reducer;