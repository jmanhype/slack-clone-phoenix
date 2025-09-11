defmodule SlackClone.PubSubHelper do
  @moduledoc """
  Central PubSub module for organizing topics and broadcasting messages
  across the SlackClone application.
  
  Topic Organization:
  - workspace:\#{workspace_id} - Workspace-wide events
  - channel:\#{channel_id} - Channel-specific events
  - user:\#{user_id} - User-specific events
  - typing:\#{channel_id} - Typing indicators for channels
  - presence:\#{workspace_id} - Presence updates for workspaces
  """

  alias Phoenix.PubSub

  @pubsub_name SlackClone.PubSub

  # Topic builders
  def workspace_topic(workspace_id), do: "workspace:#{workspace_id}"
  def channel_topic(channel_id), do: "channel:#{channel_id}"
  def user_topic(user_id), do: "user:#{user_id}"
  def typing_topic(channel_id), do: "typing:#{channel_id}"
  def presence_topic(workspace_id), do: "presence:#{workspace_id}"
  def message_thread_topic(message_id), do: "thread:#{message_id}"

  # Core broadcasting functions
  def broadcast(topic, event, payload) do
    PubSub.broadcast(@pubsub_name, topic, {event, payload})
  end

  def broadcast!(topic, event, payload) do
    PubSub.broadcast!(@pubsub_name, topic, {event, payload})
  end

  def subscribe(topic) do
    PubSub.subscribe(@pubsub_name, topic)
  end

  def unsubscribe(topic) do
    PubSub.unsubscribe(@pubsub_name, topic)
  end

  # Message-specific broadcasts
  def broadcast_new_message(channel_id, message) do
    broadcast(channel_topic(channel_id), :new_message, message)
    broadcast(workspace_topic(message.workspace_id), :new_message, message)
  end

  def broadcast_message_updated(channel_id, message) do
    broadcast(channel_topic(channel_id), :message_updated, message)
  end

  def broadcast_message_deleted(channel_id, message_id) do
    broadcast(channel_topic(channel_id), :message_deleted, %{id: message_id})
  end

  # Typing indicators
  def broadcast_typing_start(channel_id, user) do
    broadcast(typing_topic(channel_id), :typing_start, %{
      user_id: user.id,
      user_name: user.name,
      timestamp: System.system_time(:millisecond)
    })
  end

  def broadcast_typing_stop(channel_id, user) do
    broadcast(typing_topic(channel_id), :typing_stop, %{
      user_id: user.id,
      timestamp: System.system_time(:millisecond)
    })
  end

  # Channel events
  def broadcast_channel_created(workspace_id, channel) do
    broadcast(workspace_topic(workspace_id), :channel_created, channel)
  end

  def broadcast_channel_updated(workspace_id, channel) do
    broadcast(workspace_topic(workspace_id), :channel_updated, channel)
    broadcast(channel_topic(channel.id), :channel_updated, channel)
  end

  def broadcast_channel_deleted(workspace_id, channel_id) do
    broadcast(workspace_topic(workspace_id), :channel_deleted, %{id: channel_id})
  end

  # User events
  def broadcast_user_joined_channel(channel_id, workspace_id, user) do
    broadcast(channel_topic(channel_id), :user_joined, user)
    broadcast(workspace_topic(workspace_id), :user_joined_channel, %{
      channel_id: channel_id,
      user: user
    })
  end

  def broadcast_user_left_channel(channel_id, workspace_id, user_id) do
    broadcast(channel_topic(channel_id), :user_left, %{user_id: user_id})
    broadcast(workspace_topic(workspace_id), :user_left_channel, %{
      channel_id: channel_id,
      user_id: user_id
    })
  end

  # Presence events
  def broadcast_presence_diff(workspace_id, diff) do
    broadcast(presence_topic(workspace_id), :presence_diff, diff)
  end

  def broadcast_user_status_change(workspace_id, user_id, status) do
    broadcast(workspace_topic(workspace_id), :user_status_change, %{
      user_id: user_id,
      status: status
    })
  end

  # Read receipts
  def broadcast_message_read(channel_id, message_id, user_id) do
    broadcast(channel_topic(channel_id), :message_read, %{
      message_id: message_id,
      user_id: user_id,
      read_at: DateTime.utc_now()
    })
  end

  # Thread events
  def broadcast_thread_reply(message_id, reply) do
    broadcast(message_thread_topic(message_id), :thread_reply, reply)
    broadcast(channel_topic(reply.channel_id), :thread_reply, %{
      parent_message_id: message_id,
      reply: reply
    })
  end

  # Workspace events
  def broadcast_workspace_updated(workspace_id, workspace) do
    broadcast(workspace_topic(workspace_id), :workspace_updated, workspace)
  end

  # File upload events
  def broadcast_file_uploaded(channel_id, file) do
    broadcast(channel_topic(channel_id), :file_uploaded, file)
  end

  # Reaction events
  def broadcast_reaction_added(channel_id, message_id, reaction) do
    broadcast(channel_topic(channel_id), :reaction_added, %{
      message_id: message_id,
      reaction: reaction
    })
  end

  def broadcast_reaction_removed(channel_id, message_id, reaction) do
    broadcast(channel_topic(channel_id), :reaction_removed, %{
      message_id: message_id,
      reaction: reaction
    })
  end

  # Helper functions for bulk operations
  def subscribe_to_workspace(workspace_id) do
    subscribe(workspace_topic(workspace_id))
    subscribe(presence_topic(workspace_id))
  end

  def subscribe_to_channel(channel_id) do
    subscribe(channel_topic(channel_id))
    subscribe(typing_topic(channel_id))
  end

  def unsubscribe_from_workspace(workspace_id) do
    unsubscribe(workspace_topic(workspace_id))
    unsubscribe(presence_topic(workspace_id))
  end

  def unsubscribe_from_channel(channel_id) do
    unsubscribe(channel_topic(channel_id))
    unsubscribe(typing_topic(channel_id))
  end
end