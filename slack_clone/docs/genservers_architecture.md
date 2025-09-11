# Slack Clone GenServers Architecture

## Overview
This implementation provides a comprehensive set of GenServers for managing real-time communication, file processing, and user coordination in a Slack clone application. The architecture follows Elixir/Phoenix best practices with proper supervision trees and fault tolerance.

## GenServer Components

### 1. MessageBufferServer
**Purpose**: Batch message persistence for optimal database performance
**Location**: `lib/slack_clone/services/message_buffer_server.ex`

**Key Features**:
- Batches messages every 5 seconds OR when 10 messages accumulate
- Handles database failures with retry logic
- Provides statistics tracking
- Graceful shutdown with message preservation

**API**:
```elixir
MessageBufferServer.buffer_message(channel_id, user_id, content, metadata)
MessageBufferServer.flush_messages()
MessageBufferServer.get_stats()
```

### 2. PresenceTracker
**Purpose**: Track user online/offline/away status with LiveView integration
**Location**: `lib/slack_clone/services/presence_tracker.ex`

**Key Features**:
- Manages online/away/offline state transitions
- Supports multiple socket connections per user
- Automatic timeouts and cleanup
- Broadcasts presence changes via PubSub
- Workspace-level presence filtering

**API**:
```elixir
PresenceTracker.user_online(user_id, socket_id, metadata)
PresenceTracker.user_away(user_id)
PresenceTracker.user_offline(user_id, socket_id)
PresenceTracker.get_presence(user_id)
PresenceTracker.get_workspace_presence(workspace_id)
```

### 3. WorkspaceServer
**Purpose**: Manage workspace state and member connections
**Location**: `lib/slack_clone/services/workspace_server.ex`

**Key Features**:
- Dynamically created per workspace
- Tracks active members and their connections
- Member timeout handling
- Workspace-level broadcasting
- Integration with workspace data

**API**:
```elixir
WorkspaceServer.join_workspace(workspace_id, user_id, socket_id, metadata)
WorkspaceServer.leave_workspace(workspace_id, user_id, socket_id)
WorkspaceServer.get_workspace_state(workspace_id)
WorkspaceServer.broadcast_to_workspace(workspace_id, event, payload)
```

### 4. ChannelServer
**Purpose**: Handle channel state and message broadcasting
**Location**: `lib/slack_clone/services/channel_server.ex`

**Key Features**:
- Dynamically created per channel
- Real-time message broadcasting
- Typing indicators with timeout
- Message history caching
- User connection management per channel

**API**:
```elixir
ChannelServer.join_channel(channel_id, user_id, socket_id)
ChannelServer.send_message(channel_id, user_id, content, metadata)
ChannelServer.update_typing(channel_id, user_id, is_typing)
ChannelServer.get_recent_messages(channel_id, limit)
```

### 5. NotificationServer
**Purpose**: Queue and dispatch notifications efficiently
**Location**: `lib/slack_clone/services/notification_server.ex`

**Key Features**:
- Batched notification processing
- Priority-based queuing (high priority first)
- Multiple notification types (push, email, in-app, webhook)
- Retry logic with exponential backoff
- Failed notification tracking

**API**:
```elixir
NotificationServer.queue_notification(type, recipient_id, payload, options)
NotificationServer.queue_notifications(notifications_list)
NotificationServer.process_queue()
NotificationServer.retry_failed_notifications()
```

### 6. UploadProcessor
**Purpose**: Background file processing with virus scanning
**Location**: `lib/slack_clone/services/upload_processor.ex`

**Key Features**:
- Concurrent job processing (max 5 simultaneous)
- Virus scanning simulation
- Image/video thumbnail generation
- Priority-based job queuing
- Comprehensive error handling and retries

**API**:
```elixir
UploadProcessor.process_file(upload_id, file_path, options)
UploadProcessor.get_processing_status(upload_id)
UploadProcessor.cancel_job(job_id)
UploadProcessor.get_stats()
```

## Supervision Tree Architecture

### Main Application
```
SlackClone.Supervisor (one_for_one)
├── SlackCloneWeb.Telemetry
├── SlackClone.Repo
├── Phoenix.PubSub
├── Finch
├── Oban
├── Redix
├── Cachex
├── SlackCloneWeb.Presence
├── SlackClone.Services.Supervisor    ← Our services
├── SlackClone.Services.Coordinator   ← Service coordination
└── SlackCloneWeb.Endpoint
```

### Services Supervisor
```
SlackClone.Services.Supervisor (one_for_one)
├── Registry (SlackClone.WorkspaceRegistry)
├── Registry (SlackClone.ChannelRegistry)
├── MessageBufferServer
├── PresenceTracker
├── NotificationServer
├── UploadProcessor
├── DynamicSupervisor (WorkspaceSupervisor)
└── DynamicSupervisor (ChannelSupervisor)
```

### Dynamic Supervisors
- **WorkspaceSupervisor**: Manages WorkspaceServer instances (one per workspace)
- **ChannelSupervisor**: Manages ChannelServer instances (one per channel)

## Coordination and Hooks

### Services Coordinator
**Location**: `lib/slack_clone/services/coordinator.ex`

**Responsibilities**:
- Ensure servers are started when needed
- Coordinate cross-service communication
- Execute claude-flow hooks for external coordination
- Monitor service health
- Handle graceful shutdowns

**Hook Integration**:
The coordinator executes claude-flow hooks at key points:
- `workspace_server_started`: When a workspace server starts
- `channel_server_started`: When a channel server starts
- `workspace_shutdown`: When shutting down workspace and channels

### Inter-Service Communication
Services communicate via Phoenix.PubSub topics:
- `presence:updates`: Presence state changes
- `workspace:{id}:*`: Workspace-specific events
- `channel:{id}:*`: Channel-specific events
- `message_buffer:stats`: Message buffer statistics
- `upload_processor:jobs`: Upload processing events

## Restart Strategies

### Service-Level Strategy
- **MessageBufferServer**: `:permanent` - Critical for message persistence
- **PresenceTracker**: `:permanent` - Essential for user state
- **NotificationServer**: `:permanent` - Important for user notifications
- **UploadProcessor**: `:permanent` - Handles file processing jobs

### Dynamic Server Strategy
- **WorkspaceServer**: `:transient` - Restart only on abnormal termination
- **ChannelServer**: `:transient` - Restart only on abnormal termination

## Testing Coverage

Each GenServer includes comprehensive tests covering:
- Normal operation scenarios
- Error conditions and recovery
- Concurrent access patterns
- Timeout and cleanup behavior
- Integration with PubSub
- Supervision tree behavior

**Test Files**:
- `test/slack_clone/services/message_buffer_server_test.exs`
- `test/slack_clone/services/presence_tracker_test.exs`
- `test/slack_clone/services/notification_server_test.exs`
- `test/slack_clone/services/upload_processor_test.exs`
- `test/slack_clone/services/supervisor_test.exs`

## Configuration

### Environment Variables
```elixir
config :slack_clone, SlackClone.Services,
  message_batch_size: 10,
  message_batch_timeout: 5_000,
  presence_timeout: 30_000,
  upload_max_concurrent: 5,
  notification_batch_size: 50
```

### Runtime Configuration
All GenServers support configuration via application environment or start_link options.

## Monitoring and Observability

### Statistics Available
Each GenServer provides comprehensive statistics:
- Message buffer: batches processed, errors, throughput
- Presence tracker: online users, connections, cleanup stats
- Notification server: queue size, success/failure rates
- Upload processor: active jobs, completion rates, virus detection
- Workspace/Channel servers: member counts, activity metrics

### Health Checks
The Services.Supervisor provides a `health_check/0` function that returns:
- Service status (running/stopped)
- Dynamic server counts
- Timestamp and uptime information

## Performance Characteristics

### Batching Benefits
- **MessageBufferServer**: Reduces database load by batching writes
- **NotificationServer**: Improves notification throughput
- **UploadProcessor**: Optimizes file processing pipeline

### Concurrency
- Multiple workspace servers can run simultaneously
- Channel servers operate independently
- Upload processing supports configurable concurrency limits
- All services designed for high concurrent access

### Memory Management
- Recent message caching in ChannelServer (configurable limit)
- Automatic cleanup of stale presence data
- Failed notification cleanup
- Upload job cleanup after processing

## Usage Examples

### Starting a Workspace
```elixir
# Ensure workspace server is running
{:ok, pid} = SlackClone.Services.Coordinator.ensure_workspace_server("workspace_123")

# User joins workspace
WorkspaceServer.join_workspace("workspace_123", "user_456", "socket_789")
```

### Sending a Message
```elixir
# Send message through channel server
ChannelServer.send_message("channel_123", "user_456", "Hello everyone!")

# Message gets buffered for efficient database writes
# and broadcast to all channel members in real-time
```

### File Upload Processing
```elixir
# Queue file for processing
UploadProcessor.process_file("upload_123", "/path/to/file.jpg", 
  priority: :high, generate_thumbnails: true)

# Check processing status
{:processing, :scanning} = UploadProcessor.get_processing_status("upload_123")
```

This architecture provides a robust, scalable foundation for a Slack-like real-time communication platform with proper fault tolerance, monitoring, and coordination capabilities.