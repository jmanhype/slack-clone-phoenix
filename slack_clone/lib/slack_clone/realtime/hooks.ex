defmodule SlackClone.Realtime.Hooks do
  @moduledoc """
  Coordination hooks for integrating Phoenix PubSub/LiveView with GenServer implementations.
  Provides a bridge between real-time UI updates and backend business logic.
  """
  
  alias SlackClone.PubSubHelper, as: PubSub
  # alias SlackCloneWeb.Presence

  @doc """
  Hook called when a message is created through the GenServer.
  Broadcasts the message to real-time subscribers.
  """
  def on_message_created(message) do
    # Broadcast to channel subscribers
    PubSub.broadcast_new_message(message.channel_id, message)
    
    # Update any relevant presence information
    update_channel_activity(message.channel_id)
    
    # Trigger any additional side effects
    handle_message_mentions(message)
    handle_message_attachments(message)
    
    :ok
  end

  @doc """
  Hook called when a message is updated through the GenServer.
  """
  def on_message_updated(message) do
    PubSub.broadcast_message_updated(message.channel_id, message)
    :ok
  end

  @doc """
  Hook called when a message is deleted through the GenServer.
  """
  def on_message_deleted(channel_id, message_id) do
    PubSub.broadcast_message_deleted(channel_id, message_id)
    :ok
  end

  @doc """
  Hook called when a channel is created through the GenServer.
  """
  def on_channel_created(channel) do
    PubSub.broadcast_channel_created(channel.workspace_id, channel)
    :ok
  end

  @doc """
  Hook called when a channel is updated through the GenServer.
  """
  def on_channel_updated(channel) do
    PubSub.broadcast_channel_updated(channel.workspace_id, channel)
    :ok
  end

  @doc """
  Hook called when a channel is deleted through the GenServer.
  """
  def on_channel_deleted(workspace_id, channel_id) do
    PubSub.broadcast_channel_deleted(workspace_id, channel_id)
    :ok
  end

  @doc """
  Hook called when a user joins a channel through the GenServer.
  """
  def on_user_joined_channel(channel_id, workspace_id, user) do
    PubSub.broadcast_user_joined_channel(channel_id, workspace_id, user)
    :ok
  end

  @doc """
  Hook called when a user leaves a channel through the GenServer.
  """
  def on_user_left_channel(channel_id, workspace_id, user_id) do
    PubSub.broadcast_user_left_channel(channel_id, workspace_id, user_id)
    :ok
  end

  @doc """
  Hook called when a reaction is added through the GenServer.
  """
  def on_reaction_added(channel_id, message_id, reaction) do
    PubSub.broadcast_reaction_added(channel_id, message_id, reaction)
    :ok
  end

  @doc """
  Hook called when a reaction is removed through the GenServer.
  """
  def on_reaction_removed(channel_id, message_id, reaction) do
    PubSub.broadcast_reaction_removed(channel_id, message_id, reaction)
    :ok
  end

  @doc """
  Hook called when a thread reply is created through the GenServer.
  """
  def on_thread_reply_created(parent_message_id, reply) do
    PubSub.broadcast_thread_reply(parent_message_id, reply)
    :ok
  end

  @doc """
  Hook called when a user's status changes through the GenServer.
  """
  def on_user_status_changed(workspace_id, user_id, status) do
    PubSub.broadcast_user_status_change(workspace_id, user_id, status)
    :ok
  end

  @doc """
  Hook called when a file is uploaded through the GenServer.
  """
  def on_file_uploaded(channel_id, file) do
    PubSub.broadcast_file_uploaded(channel_id, file)
    :ok
  end

  @doc """
  Hook called when a workspace is updated through the GenServer.
  """
  def on_workspace_updated(workspace) do
    PubSub.broadcast_workspace_updated(workspace.id, workspace)
    :ok
  end

  @doc """
  Coordination hook for presence updates from GenServer state.
  Synchronizes GenServer presence state with Phoenix Presence.
  """
  def sync_presence_state(workspace_id, user_presences) do
    # Convert GenServer presence format to Phoenix Presence format
    presence_diffs = build_presence_diffs(user_presences)
    
    # Broadcast presence updates
    PubSub.broadcast_presence_diff(workspace_id, presence_diffs)
    
    :ok
  end

  @doc """
  Coordination hook for typing indicators from GenServer.
  """
  def handle_typing_event(channel_id, user, action) when action in [:start, :stop] do
    case action do
      :start -> PubSub.broadcast_typing_start(channel_id, user)
      :stop -> PubSub.broadcast_typing_stop(channel_id, user)
    end
    
    :ok
  end

  @doc """
  Hook for coordinating read receipts from GenServer.
  """
  def handle_message_read(channel_id, message_id, user_id) do
    PubSub.broadcast_message_read(channel_id, message_id, user_id)
    :ok
  end

  @doc """
  Batch hook for handling multiple events from GenServer operations.
  Useful for complex operations that affect multiple entities.
  """
  def handle_batch_events(events) when is_list(events) do
    Enum.each(events, fn
      {:message_created, message} -> on_message_created(message)
      {:message_updated, message} -> on_message_updated(message)
      {:message_deleted, channel_id, message_id} -> on_message_deleted(channel_id, message_id)
      {:channel_created, channel} -> on_channel_created(channel)
      {:channel_updated, channel} -> on_channel_updated(channel)
      {:user_joined_channel, channel_id, workspace_id, user} -> 
        on_user_joined_channel(channel_id, workspace_id, user)
      {:user_left_channel, channel_id, workspace_id, user_id} -> 
        on_user_left_channel(channel_id, workspace_id, user_id)
      {:reaction_added, channel_id, message_id, reaction} -> 
        on_reaction_added(channel_id, message_id, reaction)
      {:file_uploaded, channel_id, file} -> on_file_uploaded(channel_id, file)
      _ -> :skip
    end)
    
    :ok
  end

  @doc """
  Error handling hook for GenServer failures.
  Notifies UI of errors and provides fallback behavior.
  """
  def handle_genserver_error(operation, error, context) do
    # Log the error
    require Logger
    Logger.error("GenServer operation failed", 
      operation: operation, 
      error: error, 
      context: context
    )

    # Broadcast error to relevant subscribers
    case context do
      %{channel_id: channel_id} ->
        PubSub.broadcast(PubSub.channel_topic(channel_id), :operation_error, %{
          operation: operation,
          error: format_error(error)
        })
      
      %{workspace_id: workspace_id} ->
        PubSub.broadcast(PubSub.workspace_topic(workspace_id), :operation_error, %{
          operation: operation,
          error: format_error(error)
        })
      
      _ -> :ok
    end

    :ok
  end

  @doc """
  Health check hook to monitor GenServer state and broadcast status.
  """
  def broadcast_health_status(service, status, metadata \\ %{}) do
    health_data = %{
      service: service,
      status: status,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }

    # Broadcast to system monitoring topic
    PubSub.broadcast("system:health", :health_update, health_data)
    
    :ok
  end

  # Private helper functions
  
  defp update_channel_activity(channel_id) do
    # Update last activity timestamp for the channel
    # This could trigger UI updates for "recently active" indicators
    activity_data = %{
      channel_id: channel_id,
      last_activity: DateTime.utc_now()
    }
    
    PubSub.broadcast(PubSub.channel_topic(channel_id), :activity_update, activity_data)
  end

  defp handle_message_mentions(message) do
    # Extract mentions and send notifications
    mentions = extract_mentions(message.content)
    
    Enum.each(mentions, fn mentioned_user_id ->
      PubSub.broadcast(PubSub.user_topic(mentioned_user_id), :mention_notification, %{
        message: message,
        mentioned_by: message.user_id
      })
    end)
  end

  defp handle_message_attachments(message) do
    # Handle any file attachments in the message
    if message.attachments && length(message.attachments) > 0 do
      Enum.each(message.attachments, fn attachment ->
        on_file_uploaded(message.channel_id, attachment)
      end)
    end
  end

  defp build_presence_diffs(user_presences) do
    # Convert GenServer presence format to Phoenix Presence diff format
    joins = 
      user_presences
      |> Enum.filter(&(&1.status == "online"))
      |> Enum.map(&format_presence_entry/1)
      |> Enum.into(%{})

    leaves = 
      user_presences
      |> Enum.filter(&(&1.status in ["offline", "away"]))
      |> Enum.map(&format_presence_entry/1)
      |> Enum.into(%{})

    %{joins: joins, leaves: leaves}
  end

  defp format_presence_entry(user_presence) do
    key = "user:#{user_presence.user_id}"
    meta = %{
      user_id: user_presence.user_id,
      name: user_presence.name,
      status: user_presence.status,
      last_seen_at: user_presence.last_seen_at
    }
    
    {key, %{metas: [meta]}}
  end

  defp extract_mentions(content) do
    # Extract @username mentions from message content
    Regex.scan(~r/@(\w+)/, content)
    |> Enum.map(fn [_, username] -> username end)
    |> resolve_usernames_to_ids()
  end

  defp resolve_usernames_to_ids(usernames) do
    # Mock implementation - replace with actual user lookup
    usernames
  end

  defp format_error(error) do
    case error do
      {:error, changeset} when is_map(changeset) ->
        # Format Ecto changeset errors
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end)
      
      {:error, reason} when is_atom(reason) ->
        %{reason: reason}
      
      {:error, reason} when is_binary(reason) ->
        %{message: reason}
      
      error ->
        %{error: inspect(error)}
    end
  end
end