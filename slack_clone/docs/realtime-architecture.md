# Slack Clone Real-time Architecture

## Overview

This document outlines the comprehensive real-time communication system implemented using Phoenix PubSub, LiveView, and WebSocket channels for the Slack Clone application.

## Architecture Components

### 1. Phoenix PubSub System (`SlackClone.PubSub`)

**Topic Organization:**
- `workspace:{workspace_id}` - Workspace-wide events
- `channel:{channel_id}` - Channel-specific events  
- `user:{user_id}` - User-specific events
- `typing:{channel_id}` - Typing indicators for channels
- `presence:{workspace_id}` - Presence updates for workspaces
- `thread:{message_id}` - Message thread discussions

**Key Functions:**
- Centralized message broadcasting
- Topic management with consistent naming
- Event-specific broadcast methods
- Bulk subscription/unsubscription helpers

### 2. LiveView Components

#### WorkspaceLive
- Main application shell
- Handles workspace-level events
- Manages channel navigation
- Tracks user presence in workspace
- Coordinates with PresenceLive for online users

#### ChannelLive  
- Individual channel view
- Real-time message updates
- Typing indicator coordination
- Message input with auto-resize
- Integration with ThreadLive for discussions

#### MessageLive
- Individual message component
- Real-time reactions and updates
- Edit/delete functionality
- Thread opening capabilities
- Read receipt tracking

#### PresenceLive
- Online user list with status
- Efficient presence diff handling
- Activity indicators
- User status filtering and search

#### ThreadLive
- Message thread discussions
- Real-time reply updates
- Thread-specific presence
- Nested conversation management

### 3. WebSocket Channels

#### WorkspaceChannel
- Workspace membership management
- Channel creation/joining/leaving
- User status updates
- Presence state synchronization
- Cross-channel notifications

#### ChannelChannel
- Real-time messaging
- Typing indicator broadcasts
- Reaction management
- Read receipt tracking
- Thread reply coordination
- Message history loading

#### UserSocket
- Authentication and authorization
- User session management
- Channel routing
- Connection state handling

### 4. GenServer Coordination

#### Realtime.Hooks System
- `on_message_created/1` - Broadcast new messages
- `on_message_updated/1` - Broadcast message updates
- `on_channel_created/1` - Broadcast new channels
- `on_user_joined_channel/3` - Broadcast user joins
- `sync_presence_state/2` - Synchronize presence
- `handle_typing_event/3` - Coordinate typing indicators
- `handle_batch_events/1` - Process multiple events
- `handle_genserver_error/3` - Error coordination

### 5. Frontend Integration

#### JavaScript Hooks
- AutoResize - Textarea auto-expansion
- ScrollToBottom - Message container scrolling
- TypingIndicator - Client-side typing coordination
- PresenceIndicator - User status display
- MessageActions - Hover action menus
- FileUpload - Drag & drop file handling
- NotificationHandler - Browser notifications
- ConnectionStatus - Connection state display

#### User Socket Client
- WebSocket connection management
- Channel subscription handling
- Message sending/receiving
- Error handling and reconnection
- Event coordination with LiveView

## Real-time Features

### 1. Messaging
- ✅ Real-time message delivery
- ✅ Message editing and deletion
- ✅ Thread discussions
- ✅ File attachments
- ✅ Message formatting (mentions, links)

### 2. Presence & Status
- ✅ Online/offline user tracking
- ✅ User status indicators (online, away, busy)
- ✅ Activity-based presence updates
- ✅ Efficient presence diffs
- ✅ Cross-workspace presence sync

### 3. Typing Indicators
- ✅ Real-time typing broadcasts
- ✅ Automatic timeout handling
- ✅ Multiple user typing display
- ✅ Channel-specific indicators

### 4. Reactions & Interactions
- ✅ Real-time reaction updates
- ✅ Reaction count aggregation
- ✅ User-specific reaction tracking
- ✅ Emoji picker integration

### 5. Read Receipts
- ✅ Message read tracking
- ✅ Read status broadcasts
- ✅ User-specific read receipts
- ✅ Unread count management

## Topic Flow Diagram

```
GenServer Events → Hooks → PubSub Topics → LiveView Components
                                       ↓
                                 WebSocket Channels → Frontend
```

### Event Flow Examples

1. **New Message:**
   ```
   GenServer.create_message → Hooks.on_message_created → 
   PubSub.broadcast_new_message → ChannelLive.handle_info → 
   Real-time UI update
   ```

2. **User Typing:**
   ```
   Frontend typing → WebSocket → ChannelChannel.typing_start →
   PubSub.broadcast_typing_start → ChannelLive.handle_info →
   Typing indicator display
   ```

3. **Presence Update:**
   ```
   GenServer presence change → Hooks.sync_presence_state →
   PubSub.broadcast_presence_diff → WorkspaceLive.handle_info →
   PresenceLive update
   ```

## Performance Optimizations

### 1. Efficient Updates
- Presence diffs instead of full state
- Targeted topic subscriptions
- Batch event processing
- Connection pooling

### 2. Frontend Optimizations
- Message virtualization for large lists
- Debounced typing indicators
- Lazy loading of message history
- Efficient DOM updates with LiveView

### 3. Error Handling
- Automatic reconnection with backoff
- Graceful degradation on failures
- Error notification system
- Circuit breaker patterns

## Security Considerations

### 1. Authentication
- Token-based WebSocket authentication
- Session-based LiveView authentication
- User authorization per channel/workspace

### 2. Authorization
- Channel membership verification
- Message editing permissions
- File upload restrictions
- Rate limiting on actions

### 3. Data Validation
- Input sanitization
- Message content filtering
- File type restrictions
- Payload size limits

## Monitoring & Debugging

### 1. Logging
- Structured logging with metadata
- Connection state tracking
- Performance metrics
- Error tracking

### 2. Development Tools
- LiveView debug mode
- WebSocket connection inspector
- PubSub topic monitoring
- Presence state inspection

## Integration Points

### 1. Database Layer
- Message persistence hooks
- User state synchronization
- Channel membership updates
- Read receipt storage

### 2. External Services
- File upload coordination
- Push notification triggers
- Email notification hooks
- Analytics event tracking

## Deployment Considerations

### 1. Clustering
- PubSub cluster distribution
- Presence cluster synchronization
- Load balancer WebSocket support
- Session sticky routing

### 2. Scaling
- Horizontal LiveView scaling
- WebSocket connection distribution
- Redis PubSub clustering
- Database connection pooling

## Testing Strategy

### 1. Unit Tests
- PubSub broadcast verification
- Hook function testing
- LiveView component testing
- Channel message flow testing

### 2. Integration Tests
- End-to-end message flow
- Presence synchronization
- Multi-user scenario testing
- Connection failure recovery

This architecture provides a solid foundation for real-time collaboration features while maintaining clean separation of concerns and efficient coordination between GenServer business logic and real-time UI updates.