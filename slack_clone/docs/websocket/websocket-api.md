# WebSocket API Documentation

## Overview

The Slack Clone WebSocket API provides real-time communication capabilities for messaging, presence tracking, typing indicators, and other live features. The API uses Phoenix Channels built on top of WebSocket connections.

## Base URLs

- **Production**: `wss://api.slackclone.com/socket/websocket`
- **Staging**: `wss://staging-api.slackclone.com/socket/websocket`
- **Development**: `ws://localhost:4000/socket/websocket`

## Authentication

WebSocket connections require authentication via JWT tokens passed in the connection parameters:

```javascript
// JavaScript example
const socket = new Phoenix.Socket("ws://localhost:4000/socket/websocket", {
  params: { token: "your-jwt-token" }
});
```

## Connection Lifecycle

### 1. Establish Socket Connection

```javascript
import { Socket } from "phoenix"

const socket = new Socket("ws://localhost:4000/socket/websocket", {
  params: { token: userToken },
  logger: (kind, msg, data) => { console.log(`${kind}: ${msg}`, data) }
});

socket.connect();

// Handle connection events
socket.onOpen(() => console.log("Connected to server"));
socket.onError((error) => console.log("Connection error:", error));
socket.onClose((event) => console.log("Connection closed:", event));
```

### 2. Join Channels

After establishing the socket connection, join specific channels:

```javascript
// Join a channel
const channel = socket.channel("channel:12345678-1234-5678-1234-123456789012");

channel.join()
  .receive("ok", (response) => {
    console.log("Joined channel successfully", response);
  })
  .receive("error", (response) => {
    console.log("Unable to join channel", response);
  });
```

### 3. Handle Channel Events

```javascript
// Listen for incoming messages
channel.on("new_message", (message) => {
  console.log("New message:", message);
});

// Handle connection status
channel.onError(() => console.log("Channel error"));
channel.onClose(() => console.log("Channel closed"));
```

## Channel Types

### Workspace Channels (`workspace:{workspace_id}`)

For workspace-level events like new channels, member updates, etc.

### Channel Channels (`channel:{channel_id}`)

For channel-specific messaging and real-time interactions.

---

## Channel Events

### Channel: `channel:{channel_id}`

#### Joining the Channel

**Event**: `phx_join`

**Payload**: 
```json
{
  "user_id": "12345678-1234-5678-1234-123456789012"
}
```

**Response on Success**:
```json
{
  "status": "ok",
  "response": {
    "channel": {
      "id": "12345678-1234-5678-1234-123456789012",
      "name": "general",
      "type": "public",
      "description": "General discussion"
    }
  }
}
```

**Response on Error**:
```json
{
  "status": "error",
  "response": {
    "reason": "Access denied"
  }
}
```

#### After Join Events

Once joined, you'll automatically receive:

1. **`messages_loaded`** - Recent messages
2. **`presence_state`** - Current online users

---

## Outgoing Events (Client → Server)

### Send Message

**Event**: `send_message`

**Payload**:
```json
{
  "content": "Hello everyone! 👋",
  "temp_id": "temp_123456789",
  "attachments": [
    {
      "id": "attachment_123",
      "filename": "image.jpg",
      "content_type": "image/jpeg",
      "url": "https://files.slackclone.com/attachments/image.jpg"
    }
  ]
}
```

**Success Response**: `message_sent`
```json
{
  "temp_id": "temp_123456789",
  "message": {
    "id": "12345678-1234-5678-1234-123456789012",
    "content": "Hello everyone! 👋",
    "user": {
      "id": "user_123",
      "name": "John Doe",
      "avatar_url": "https://example.com/avatar.jpg"
    },
    "inserted_at": "2023-09-16T16:45:00Z",
    "attachments": [...],
    "reactions": []
  }
}
```

**Error Response**: `message_error`
```json
{
  "temp_id": "temp_123456789",
  "errors": {
    "content": ["can't be blank"]
  }
}
```

### Send Thread Reply

**Event**: `send_message`

**Payload**:
```json
{
  "content": "Great point! I agree with this approach.",
  "thread_id": "parent_message_id",
  "temp_id": "temp_987654321"
}
```

### Edit Message

**Event**: `edit_message`

**Payload**:
```json
{
  "message_id": "12345678-1234-5678-1234-123456789012",
  "content": "Updated message content"
}
```

**Success Response**: `message_edited`
```json
{
  "message": {
    "id": "12345678-1234-5678-1234-123456789012",
    "content": "Updated message content",
    "is_edited": true,
    "edited_at": "2023-09-16T16:50:00Z"
  }
}
```

**Error Response**: `edit_error`
```json
{
  "message_id": "12345678-1234-5678-1234-123456789012",
  "reason": "Edit time limit exceeded"
}
```

### Delete Message

**Event**: `delete_message`

**Payload**:
```json
{
  "message_id": "12345678-1234-5678-1234-123456789012"
}
```

### Typing Indicators

**Start Typing Event**: `typing_start`
```json
{}
```

**Stop Typing Event**: `typing_stop`
```json
{}
```

### Reactions

**Add Reaction Event**: `add_reaction`
```json
{
  "message_id": "12345678-1234-5678-1234-123456789012",
  "emoji": ":thumbsup:"
}
```

**Remove Reaction Event**: `remove_reaction`
```json
{
  "reaction_id": "reaction_12345"
}
```

### Message Read Receipts

**Mark as Read Event**: `mark_read`
```json
{
  "message_id": "12345678-1234-5678-1234-123456789012"
}
```

### Load Older Messages

**Event**: `load_older_messages`

**Payload**:
```json
{
  "before_id": "12345678-1234-5678-1234-123456789012"
}
```

**Response**: `older_messages_loaded`
```json
{
  "messages": [
    {
      "id": "older_message_1",
      "content": "This is an older message",
      "inserted_at": "2023-09-16T15:30:00Z"
    }
  ]
}
```

### Thread Management

**Start Thread Event**: `start_thread`
```json
{
  "message_id": "12345678-1234-5678-1234-123456789012"
}
```

---

## Incoming Events (Server → Client)

### New Message

**Event**: `new_message`

**Payload**:
```json
{
  "message": {
    "id": "12345678-1234-5678-1234-123456789012",
    "content": "New message from another user",
    "user": {
      "id": "user_456",
      "name": "Jane Smith",
      "avatar_url": "https://example.com/jane.jpg"
    },
    "channel_id": "channel_123",
    "inserted_at": "2023-09-16T16:45:00Z",
    "attachments": [],
    "reactions": [],
    "mentions": ["user_123"],
    "thread_id": null
  }
}
```

### Message Updates

**Event**: `message_updated`
```json
{
  "message": {
    "id": "12345678-1234-5678-1234-123456789012",
    "content": "Edited message content",
    "is_edited": true,
    "edited_at": "2023-09-16T16:50:00Z"
  }
}
```

**Event**: `message_deleted`
```json
{
  "message_id": "12345678-1234-5678-1234-123456789012"
}
```

### Typing Indicators

**Event**: `typing_start`
```json
{
  "user_id": "user_456",
  "user_name": "Jane Smith",
  "channel_id": "channel_123"
}
```

**Event**: `typing_stop`
```json
{
  "user_id": "user_456",
  "channel_id": "channel_123"
}
```

### Reactions

**Event**: `reaction_added`
```json
{
  "message_id": "12345678-1234-5678-1234-123456789012",
  "reaction": {
    "id": "reaction_123",
    "emoji": ":thumbsup:",
    "user": {
      "id": "user_456",
      "name": "Jane Smith"
    },
    "inserted_at": "2023-09-16T16:45:00Z"
  }
}
```

**Event**: `reaction_removed`
```json
{
  "reaction": {
    "id": "reaction_123",
    "emoji": ":thumbsup:",
    "message_id": "12345678-1234-5678-1234-123456789012"
  }
}
```

### Presence Tracking

**Event**: `presence_state` (on join)
```json
{
  "user_123": {
    "metas": [{
      "name": "John Doe",
      "avatar_url": "https://example.com/john.jpg",
      "joined_at": 1694972400,
      "phx_ref": "channel_ref_1"
    }]
  },
  "user_456": {
    "metas": [{
      "name": "Jane Smith",
      "avatar_url": "https://example.com/jane.jpg", 
      "joined_at": 1694972500,
      "phx_ref": "channel_ref_2"
    }]
  }
}
```

**Event**: `presence_diff`
```json
{
  "joins": {
    "user_789": {
      "metas": [{
        "name": "Bob Wilson",
        "avatar_url": "https://example.com/bob.jpg",
        "joined_at": 1694972600,
        "phx_ref": "channel_ref_3"
      }]
    }
  },
  "leaves": {
    "user_456": {
      "metas": [{
        "name": "Jane Smith",
        "avatar_url": "https://example.com/jane.jpg",
        "joined_at": 1694972500,
        "phx_ref": "channel_ref_2"
      }]
    }
  }
}
```

### User Events

**Event**: `user_joined`
```json
{
  "user": {
    "id": "user_789",
    "name": "Bob Wilson",
    "avatar_url": "https://example.com/bob.jpg"
  }
}
```

**Event**: `user_left`
```json
{
  "user_id": "user_456"
}
```

### Thread Events

**Event**: `thread_started`
```json
{
  "message_id": "12345678-1234-5678-1234-123456789012",
  "thread": {
    "id": "thread_123",
    "message_count": 0,
    "participants": []
  }
}
```

**Event**: `thread_reply`
```json
{
  "thread_id": "thread_123",
  "reply": {
    "id": "reply_456",
    "content": "Thread reply content",
    "user": {
      "id": "user_123",
      "name": "John Doe"
    },
    "inserted_at": "2023-09-16T16:45:00Z"
  }
}
```

**Event**: `thread_reply_sent` (acknowledgment)
```json
{
  "reply": {
    "id": "reply_456",
    "content": "Thread reply content",
    "thread_id": "thread_123",
    "inserted_at": "2023-09-16T16:45:00Z"
  }
}
```

---

## Error Handling

### Connection Errors

```javascript
socket.onError((error) => {
  console.error("WebSocket error:", error);
  // Implement reconnection logic
  setTimeout(() => socket.connect(), 5000);
});
```

### Channel Errors

```javascript
channel.onError((error) => {
  console.error("Channel error:", error);
  // Attempt to rejoin the channel
  channel.join();
});
```

### Common Error Responses

```json
{
  "status": "error",
  "response": {
    "reason": "unauthorized",
    "message": "Invalid or expired token"
  }
}
```

```json
{
  "status": "error", 
  "response": {
    "reason": "forbidden",
    "message": "Insufficient permissions"
  }
}
```

---

## Rate Limiting

WebSocket connections are subject to the following limits:

- **Connection Limit**: 100 concurrent connections per user
- **Message Rate**: 60 messages per minute per channel
- **Join Rate**: 30 channel joins per minute per user
- **Typing Events**: 10 typing indicators per minute per channel

When rate limits are exceeded, you'll receive:

```json
{
  "status": "error",
  "response": {
    "reason": "rate_limit_exceeded",
    "retry_after": 30000,
    "message": "Too many requests. Retry after 30 seconds."
  }
}
```

---

## Best Practices

### Connection Management

1. **Implement reconnection logic** with exponential backoff
2. **Handle authentication token expiry** by refreshing tokens
3. **Monitor connection health** with heartbeat/ping mechanisms
4. **Gracefully handle disconnections** and queue messages for retry

### Message Handling

1. **Use temporary IDs** for optimistic UI updates
2. **Implement message deduplication** using message IDs
3. **Handle message ordering** using timestamps
4. **Cache messages locally** for offline support

### Performance Optimization

1. **Batch presence updates** to avoid UI thrashing
2. **Throttle typing indicators** to reduce server load
3. **Lazy load older messages** on demand
4. **Use efficient data structures** for message storage

### Error Recovery

1. **Implement circuit breakers** for failed operations
2. **Queue failed messages** for retry
3. **Show connection status** to users
4. **Provide offline indicators** when disconnected

---

## Examples

### Complete Connection Example

```javascript
import { Socket } from "phoenix";

class SlackCloneWebSocket {
  constructor(token) {
    this.socket = new Socket("ws://localhost:4000/socket/websocket", {
      params: { token },
      reconnectAfterMs: () => [1000, 5000, 10000]
    });
    
    this.channels = new Map();
    this.setupSocketListeners();
  }

  setupSocketListeners() {
    this.socket.onOpen(() => {
      console.log("Connected to Slack Clone");
    });

    this.socket.onError((error) => {
      console.error("WebSocket error:", error);
    });

    this.socket.onClose(() => {
      console.log("WebSocket connection closed");
    });
  }

  connect() {
    this.socket.connect();
  }

  joinChannel(channelId, callbacks = {}) {
    const channel = this.socket.channel(`channel:${channelId}`);
    
    channel.join()
      .receive("ok", (response) => {
        console.log(`Joined channel ${channelId}`, response);
        callbacks.onJoin?.(response);
      })
      .receive("error", (response) => {
        console.error(`Failed to join channel ${channelId}`, response);
        callbacks.onError?.(response);
      });

    // Set up message handlers
    channel.on("new_message", callbacks.onMessage || ((msg) => console.log("New message:", msg)));
    channel.on("message_updated", callbacks.onMessageUpdate || ((msg) => console.log("Message updated:", msg)));
    channel.on("message_deleted", callbacks.onMessageDelete || ((msg) => console.log("Message deleted:", msg)));
    channel.on("typing_start", callbacks.onTypingStart || ((data) => console.log("Typing start:", data)));
    channel.on("typing_stop", callbacks.onTypingStop || ((data) => console.log("Typing stop:", data)));
    channel.on("presence_diff", callbacks.onPresenceDiff || ((diff) => console.log("Presence diff:", diff)));

    this.channels.set(channelId, channel);
    return channel;
  }

  sendMessage(channelId, content, tempId = Date.now().toString()) {
    const channel = this.channels.get(channelId);
    if (!channel) {
      throw new Error(`Not connected to channel ${channelId}`);
    }

    channel.push("send_message", {
      content,
      temp_id: tempId
    })
    .receive("ok", (response) => {
      console.log("Message sent successfully:", response);
    })
    .receive("error", (response) => {
      console.error("Failed to send message:", response);
    });
  }

  startTyping(channelId) {
    const channel = this.channels.get(channelId);
    if (channel) {
      channel.push("typing_start");
    }
  }

  stopTyping(channelId) {
    const channel = this.channels.get(channelId);
    if (channel) {
      channel.push("typing_stop");
    }
  }

  addReaction(channelId, messageId, emoji) {
    const channel = this.channels.get(channelId);
    if (channel) {
      channel.push("add_reaction", {
        message_id: messageId,
        emoji
      });
    }
  }

  disconnect() {
    this.socket.disconnect();
  }
}

// Usage example
const client = new SlackCloneWebSocket("your-jwt-token");
client.connect();

client.joinChannel("12345678-1234-5678-1234-123456789012", {
  onJoin: (response) => {
    console.log("Successfully joined channel:", response.channel);
  },
  onMessage: (message) => {
    console.log("Received message:", message);
  },
  onPresenceDiff: (diff) => {
    console.log("Presence update:", diff);
  }
});

// Send a message
client.sendMessage("12345678-1234-5678-1234-123456789012", "Hello World!");
```

---

This documentation provides a comprehensive guide to implementing WebSocket functionality in your Slack Clone client applications. For additional examples and language-specific implementations, see the [Integration Guides](../guides/).