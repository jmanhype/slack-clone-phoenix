defmodule SlackClone.Services.ChannelServer do
  @moduledoc """
  GenServer for handling channel state and message broadcasting.
  Manages real-time message delivery and channel-specific operations.
  """

  use GenServer
  require Logger

  alias SlackClone.Messages
  alias SlackClone.Channels
  alias SlackClone.Services.MessageBufferServer
  alias Phoenix.PubSub

  @message_history_limit 100
  @typing_timeout 3_000
  @member_activity_timeout 300_000  # 5 minutes

  defstruct [
    :channel_id,
    :channel_data,
    :connected_users,
    :typing_users,
    :typing_timers,
    :recent_messages,
    :stats
  ]

  ## Client API

  def start_link(channel_id, opts \\ []) do
    GenServer.start_link(__MODULE__, channel_id, 
      name: via_tuple(channel_id))
  end

  @doc """
  Join a channel
  """
  def join_channel(channel_id, user_id, socket_id \\ nil) do
    GenServer.cast(via_tuple(channel_id), {:join_channel, user_id, socket_id})
  end

  @doc """
  Leave a channel
  """
  def leave_channel(channel_id, user_id, socket_id \\ nil) do
    GenServer.cast(via_tuple(channel_id), {:leave_channel, user_id, socket_id})
  end

  @doc """
  Send a message to the channel
  """
  def send_message(channel_id, user_id, content, metadata \\ %{}) do
    GenServer.cast(via_tuple(channel_id), 
      {:send_message, user_id, content, metadata})
  end

  @doc """
  Update typing status
  """
  def update_typing(channel_id, user_id, is_typing) do
    GenServer.cast(via_tuple(channel_id), 
      {:update_typing, user_id, is_typing})
  end

  @doc """
  Get channel state
  """
  def get_channel_state(channel_id) do
    GenServer.call(via_tuple(channel_id), :get_channel_state)
  end

  @doc """
  Get recent messages
  """
  def get_recent_messages(channel_id, limit \\ @message_history_limit) do
    GenServer.call(via_tuple(channel_id), {:get_recent_messages, limit})
  end

  @doc """
  Get connected users
  """
  def get_connected_users(channel_id) do
    GenServer.call(via_tuple(channel_id), :get_connected_users)
  end

  @doc """
  Get channel statistics
  """
  def get_stats(channel_id) do
    GenServer.call(via_tuple(channel_id), :get_stats)
  end

  ## GenServer Callbacks

  @impl true
  def init(channel_id) do
    Logger.info("Starting ChannelServer for channel #{channel_id}")
    
    # Load channel data
    case Channels.get_channel(channel_id) do
      nil ->
        Logger.error("Channel #{channel_id} not found")
        {:stop, :channel_not_found}
        
      channel ->
        # Subscribe to channel events
        PubSub.subscribe(SlackClone.PubSub, "channel:#{channel_id}")
        PubSub.subscribe(SlackClone.PubSub, "channel:#{channel_id}:messages")
        
        # Load recent messages
        recent_messages = Messages.get_recent_messages(channel_id, @message_history_limit)
        
        state = %__MODULE__{
          channel_id: channel_id,
          channel_data: channel,
          connected_users: %{},
          typing_users: MapSet.new(),
          typing_timers: %{},
          recent_messages: recent_messages,
          stats: %{
            connected_users: 0,
            messages_sent: 0,
            typing_users: 0,
            last_message: get_last_message_time(recent_messages),
            uptime: DateTime.utc_now()
          }
        }
        
        {:ok, state}
    end
  end

  @impl true
  def handle_cast({:join_channel, user_id, socket_id}, state) do
    Logger.debug("User #{user_id} joining channel #{state.channel_id}")
    
    # Check if user can access this channel
    case can_access_channel?(state.channel_id, user_id) do
      false ->
        Logger.warn("User #{user_id} denied access to channel #{state.channel_id}")
        {:noreply, state}
        
      true ->
        current_time = DateTime.utc_now()
        
        # Update or create user connection
        user_connection = %{
          user_id: user_id,
          joined_at: current_time,
          last_activity: current_time,
          sockets: add_socket(get_user_sockets(state.connected_users, user_id), socket_id)
        }
        
        new_connected_users = Map.put(state.connected_users, user_id, user_connection)
        
        # Broadcast user joined
        broadcast_user_change(state.channel_id, user_id, :joined)
        
        # Send recent messages to the user
        send_recent_messages_to_user(user_id, socket_id, state.recent_messages)
        
        # Update stats
        new_stats = update_user_stats(state.stats, new_connected_users)
        
        {:noreply, %{state | 
          connected_users: new_connected_users,
          stats: new_stats
        }}
    end
  end

  def handle_cast({:leave_channel, user_id, socket_id}, state) do
    case Map.get(state.connected_users, user_id) do
      nil ->
        {:noreply, state}
        
      user_connection ->
        # Remove socket if specified
        new_sockets = remove_socket(user_connection.sockets, socket_id)
        
        if length(new_sockets) == 0 do
          Logger.debug("User #{user_id} leaving channel #{state.channel_id}")
          
          # Remove user entirely
          new_connected_users = Map.delete(state.connected_users, user_id)
          
          # Remove from typing users
          new_typing_users = MapSet.delete(state.typing_users, user_id)
          new_typing_timers = cancel_typing_timer(state.typing_timers, user_id)
          
          broadcast_user_change(state.channel_id, user_id, :left)
          
          if MapSet.member?(state.typing_users, user_id) do
            broadcast_typing_change(state.channel_id, new_typing_users)
          end
          
          new_stats = update_user_stats(state.stats, new_connected_users)
          |> update_typing_stats(new_typing_users)
          
          {:noreply, %{state | 
            connected_users: new_connected_users,
            typing_users: new_typing_users,
            typing_timers: new_typing_timers,
            stats: new_stats
          }}
        else
          # Keep user but update sockets
          updated_connection = %{user_connection | 
            sockets: new_sockets, 
            last_activity: DateTime.utc_now()
          }
          new_connected_users = Map.put(state.connected_users, user_id, updated_connection)
          
          {:noreply, %{state | connected_users: new_connected_users}}
        end
    end
  end

  def handle_cast({:send_message, user_id, content, metadata}, state) do
    Logger.debug("User #{user_id} sending message to channel #{state.channel_id}")
    
    # Check if user is connected to channel
    case Map.get(state.connected_users, user_id) do
      nil ->
        Logger.warn("User #{user_id} tried to send message but not connected to channel #{state.channel_id}")
        {:noreply, state}
        
      _user_connection ->
        # Create message data
        message_id = generate_message_id()
        current_time = DateTime.utc_now()
        
        message = %{
          id: message_id,
          channel_id: state.channel_id,
          user_id: user_id,
          content: content,
          metadata: metadata,
          inserted_at: current_time,
          updated_at: current_time
        }
        
        # Buffer message for persistence
        MessageBufferServer.buffer_message(
          state.channel_id, 
          user_id, 
          content, 
          metadata
        )
        
        # Add to recent messages (in memory)
        new_recent_messages = add_recent_message(state.recent_messages, message)
        
        # Broadcast message to all connected users
        broadcast_message(state.channel_id, message)
        
        # Remove user from typing if they were typing
        new_typing_users = MapSet.delete(state.typing_users, user_id)
        new_typing_timers = cancel_typing_timer(state.typing_timers, user_id)
        
        if MapSet.member?(state.typing_users, user_id) do
          broadcast_typing_change(state.channel_id, new_typing_users)
        end
        
        # Update user activity
        updated_connection = state.connected_users
        |> get_in([user_id])
        |> Map.put(:last_activity, current_time)
        
        new_connected_users = Map.put(state.connected_users, user_id, updated_connection)
        
        # Update stats
        new_stats = %{
          state.stats |
          messages_sent: state.stats.messages_sent + 1,
          last_message: current_time
        }
        |> update_typing_stats(new_typing_users)
        
        {:noreply, %{state |
          connected_users: new_connected_users,
          typing_users: new_typing_users,
          typing_timers: new_typing_timers,
          recent_messages: new_recent_messages,
          stats: new_stats
        }}
    end
  end

  def handle_cast({:update_typing, user_id, is_typing}, state) do
    # Check if user is connected
    case Map.get(state.connected_users, user_id) do
      nil ->
        {:noreply, state}
        
      _user_connection ->
        current_typing = MapSet.member?(state.typing_users, user_id)
        
        cond do
          is_typing and not current_typing ->
            # User started typing
            new_typing_users = MapSet.put(state.typing_users, user_id)
            
            # Set typing timeout
            typing_timer = Process.send_after(self(), 
              {:typing_timeout, user_id}, @typing_timeout)
            new_typing_timers = Map.put(state.typing_timers, user_id, typing_timer)
            
            broadcast_typing_change(state.channel_id, new_typing_users)
            
            new_stats = update_typing_stats(state.stats, new_typing_users)
            
            {:noreply, %{state |
              typing_users: new_typing_users,
              typing_timers: new_typing_timers,
              stats: new_stats
            }}
            
          not is_typing and current_typing ->
            # User stopped typing
            new_typing_users = MapSet.delete(state.typing_users, user_id)
            new_typing_timers = cancel_typing_timer(state.typing_timers, user_id)
            
            broadcast_typing_change(state.channel_id, new_typing_users)
            
            new_stats = update_typing_stats(state.stats, new_typing_users)
            
            {:noreply, %{state |
              typing_users: new_typing_users,
              typing_timers: new_typing_timers,
              stats: new_stats
            }}
            
          true ->
            # No change needed
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_call(:get_channel_state, _from, state) do
    channel_state = %{
      channel: state.channel_data,
      connected_users: state.connected_users,
      typing_users: MapSet.to_list(state.typing_users),
      stats: state.stats
    }
    
    {:reply, channel_state, state}
  end

  def handle_call({:get_recent_messages, limit}, _from, state) do
    messages = Enum.take(state.recent_messages, limit)
    {:reply, messages, state}
  end

  def handle_call(:get_connected_users, _from, state) do
    users = 
      state.connected_users
      |> Enum.map(fn {user_id, connection} ->
        %{
          user_id: user_id,
          joined_at: connection.joined_at,
          last_activity: connection.last_activity,
          socket_count: length(connection.sockets)
        }
      end)
    
    {:reply, users, state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info({:typing_timeout, user_id}, state) do
    if MapSet.member?(state.typing_users, user_id) do
      Logger.debug("Typing timeout for user #{user_id} in channel #{state.channel_id}")
      
      new_typing_users = MapSet.delete(state.typing_users, user_id)
      new_typing_timers = Map.delete(state.typing_timers, user_id)
      
      broadcast_typing_change(state.channel_id, new_typing_users)
      
      new_stats = update_typing_stats(state.stats, new_typing_users)
      
      {:noreply, %{state |
        typing_users: new_typing_users,
        typing_timers: new_typing_timers,
        stats: new_stats
      }}
    else
      {:noreply, state}
    end
  end

  # Handle external message events
  def handle_info({:message_persisted, message}, state) do
    # Update recent messages with persisted message data
    new_recent_messages = update_recent_message(state.recent_messages, message)
    {:noreply, %{state | recent_messages: new_recent_messages}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("ChannelServer for channel #{state.channel_id} terminating: #{inspect(reason)}")
    
    # Clean up typing timers
    state.typing_timers
    |> Enum.each(fn {_user_id, timer_ref} ->
      Process.cancel_timer(timer_ref)
    end)
    
    :ok
  end

  ## Private Functions

  defp via_tuple(channel_id) do
    {:via, Registry, {SlackClone.ChannelRegistry, channel_id}}
  end

  defp can_access_channel?(channel_id, user_id) do
    # Check if user has access to this channel
    Channels.can_access?(channel_id, user_id)
  end

  defp get_user_sockets(connected_users, user_id) do
    case Map.get(connected_users, user_id) do
      nil -> []
      connection -> connection.sockets
    end
  end

  defp add_socket(sockets, nil), do: sockets
  defp add_socket(sockets, socket_id) do
    if socket_id in sockets, do: sockets, else: [socket_id | sockets]
  end

  defp remove_socket(sockets, nil), do: sockets
  defp remove_socket(sockets, socket_id) do
    List.delete(sockets, socket_id)
  end

  defp cancel_typing_timer(timers, user_id) do
    case Map.pop(timers, user_id) do
      {nil, timers} -> timers
      {timer_ref, timers} ->
        Process.cancel_timer(timer_ref)
        timers
    end
  end

  defp broadcast_user_change(channel_id, user_id, action) do
    PubSub.broadcast(SlackClone.PubSub,
      "channel:#{channel_id}:users",
      {:user_change, user_id, action}
    )
  end

  defp broadcast_message(channel_id, message) do
    PubSub.broadcast(SlackClone.PubSub,
      "channel:#{channel_id}:messages",
      {:new_message, message}
    )
  end

  defp broadcast_typing_change(channel_id, typing_users) do
    PubSub.broadcast(SlackClone.PubSub,
      "channel:#{channel_id}:typing",
      {:typing_change, MapSet.to_list(typing_users)}
    )
  end

  defp send_recent_messages_to_user(_user_id, nil, _messages), do: :ok
  defp send_recent_messages_to_user(user_id, socket_id, messages) do
    # This would send messages directly to the user's socket
    # Implementation depends on your WebSocket/LiveView setup
    Logger.debug("Sending #{length(messages)} recent messages to user #{user_id}")
    :ok
  end

  defp generate_message_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp add_recent_message(messages, new_message) do
    [new_message | messages]
    |> Enum.take(@message_history_limit)
  end

  defp update_recent_message(messages, updated_message) do
    Enum.map(messages, fn msg ->
      if msg.id == updated_message.id do
        updated_message
      else
        msg
      end
    end)
  end

  defp get_last_message_time([]), do: nil
  defp get_last_message_time([message | _]), do: message.inserted_at

  defp update_user_stats(stats, connected_users) do
    %{stats | connected_users: map_size(connected_users)}
  end

  defp update_typing_stats(stats, typing_users) do
    %{stats | typing_users: MapSet.size(typing_users)}
  end
end