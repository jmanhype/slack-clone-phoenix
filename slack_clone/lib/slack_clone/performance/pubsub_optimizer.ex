defmodule SlackClone.Performance.PubSubOptimizer do
  @moduledoc """
  Optimized PubSub patterns with message batching, presence debouncing,
  and intelligent subscription management for real-time performance.
  """
  
  use GenServer
  
  alias Phoenix.PubSub
  alias SlackClone.Performance.CacheManager
  
  # Batching configuration
  @batch_interval 100        # milliseconds
  @max_batch_size 50
  @typing_debounce 2000     # milliseconds
  @presence_debounce 5000   # milliseconds
  
  # Topic patterns
  @channel_topic "channel:"
  @workspace_topic "workspace:"
  @user_topic "user:"
  @typing_topic "typing:"
  @presence_topic "presence:"
  
  defmodule BatchState do
    defstruct messages: [], typing_events: [], presence_events: [], timer: nil
  end
  
  @doc """
  Start the PubSub optimizer GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Optimized channel message broadcasting with batching.
  """
  def broadcast_messages(channel_id, messages) when is_list(messages) do
    GenServer.cast(__MODULE__, {:batch_messages, channel_id, messages})
  end
  
  def broadcast_message(channel_id, message) do
    broadcast_messages(channel_id, [message])
  end
  
  @doc """
  Debounced typing indicator broadcasting.
  """
  def broadcast_typing_start(channel_id, user) do
    key = "#{channel_id}:#{user.id}"
    GenServer.cast(__MODULE__, {:typing_start, key, channel_id, user})
  end
  
  def broadcast_typing_stop(channel_id, user) do
    key = "#{channel_id}:#{user.id}"
    GenServer.cast(__MODULE__, {:typing_stop, key, channel_id, user})
  end
  
  @doc """
  Debounced presence broadcasting.
  """
  def broadcast_presence_update(workspace_id, user_id, presence_data) do
    GenServer.cast(__MODULE__, {:presence_update, workspace_id, user_id, presence_data})
  end
  
  @doc """
  Optimized subscription management.
  """
  def subscribe_to_channel(channel_id, opts \\ []) do
    topics = [
      "#{@channel_topic}#{channel_id}",
      "#{@typing_topic}#{channel_id}"
    ]
    
    if Keyword.get(opts, :include_presence, true) do
      topics = ["#{@presence_topic}#{channel_id}" | topics]
    end
    
    Enum.each(topics, &PubSub.subscribe(SlackClone.PubSub, &1))
  end
  
  def subscribe_to_workspace(workspace_id) do
    topics = [
      "#{@workspace_topic}#{workspace_id}",
      "#{@presence_topic}workspace:#{workspace_id}"
    ]
    
    Enum.each(topics, &PubSub.subscribe(SlackClone.PubSub, &1))
  end
  
  def subscribe_to_user(user_id) do
    PubSub.subscribe(SlackClone.PubSub, "#{@user_topic}#{user_id}")
  end
  
  @doc """
  Unsubscribe from multiple topics efficiently.
  """
  def unsubscribe_from_channel(channel_id) do
    topics = [
      "#{@channel_topic}#{channel_id}",
      "#{@typing_topic}#{channel_id}",
      "#{@presence_topic}#{channel_id}"
    ]
    
    Enum.each(topics, &PubSub.unsubscribe(SlackClone.PubSub, &1))
  end
  
  # GenServer callbacks
  
  def init(_opts) do
    state = %BatchState{
      messages: %{},
      typing_events: %{},
      presence_events: %{},
      timer: nil
    }
    
    {:ok, state}
  end
  
  def handle_cast({:batch_messages, channel_id, new_messages}, state) do
    current_messages = Map.get(state.messages, channel_id, [])
    updated_messages = current_messages ++ new_messages
    
    # Limit batch size to prevent memory issues
    limited_messages = Enum.take(updated_messages, @max_batch_size)
    
    new_state = %{state | messages: Map.put(state.messages, channel_id, limited_messages)}
    
    # Start timer if not already running
    new_state = maybe_start_batch_timer(new_state)
    
    {:noreply, new_state}
  end
  
  def handle_cast({:typing_start, key, channel_id, user}, state) do
    current_time = System.system_time(:millisecond)
    
    typing_event = %{
      channel_id: channel_id,
      user: user,
      action: :start,
      timestamp: current_time
    }
    
    # Check debouncing
    case Map.get(state.typing_events, key) do
      %{timestamp: last_time} when current_time - last_time < @typing_debounce ->
        # Too frequent, ignore
        {:noreply, state}
      
      _ ->
        # Update typing events and broadcast
        new_typing_events = Map.put(state.typing_events, key, typing_event)
        new_state = %{state | typing_events: new_typing_events}
        
        # Broadcast immediately for typing indicators
        PubSub.broadcast!(
          SlackClone.PubSub,
          "#{@typing_topic}#{channel_id}",
          {:typing_start, %{user_id: user.id, user_name: user.name}}
        )
        
        {:noreply, new_state}
    end
  end
  
  def handle_cast({:typing_stop, key, channel_id, user}, state) do
    # Remove from typing events and broadcast stop
    new_typing_events = Map.delete(state.typing_events, key)
    new_state = %{state | typing_events: new_typing_events}
    
    PubSub.broadcast!(
      SlackClone.PubSub,
      "#{@typing_topic}#{channel_id}",
      {:typing_stop, %{user_id: user.id}}
    )
    
    {:noreply, new_state}
  end
  
  def handle_cast({:presence_update, workspace_id, user_id, presence_data}, state) do
    current_time = System.system_time(:millisecond)
    key = "#{workspace_id}:#{user_id}"
    
    presence_event = %{
      workspace_id: workspace_id,
      user_id: user_id,
      data: presence_data,
      timestamp: current_time
    }
    
    # Check debouncing
    case Map.get(state.presence_events, key) do
      %{timestamp: last_time} when current_time - last_time < @presence_debounce ->
        # Update data but don't broadcast yet
        updated_event = %{presence_event | timestamp: last_time}
        new_presence_events = Map.put(state.presence_events, key, updated_event)
        {:noreply, %{state | presence_events: new_presence_events}}
      
      _ ->
        # Update and prepare for batched broadcast
        new_presence_events = Map.put(state.presence_events, key, presence_event)
        new_state = %{state | presence_events: new_presence_events}
        new_state = maybe_start_batch_timer(new_state)
        {:noreply, new_state}
    end
  end
  
  def handle_info(:flush_batches, state) do
    # Broadcast all batched messages
    Enum.each(state.messages, fn {channel_id, messages} ->
      if length(messages) > 0 do
        # Sort messages by timestamp
        sorted_messages = Enum.sort_by(messages, & &1.inserted_at)
        
        PubSub.broadcast!(
          SlackClone.PubSub,
          "#{@channel_topic}#{channel_id}",
          {:batched_messages, sorted_messages}
        )
      end
    end)
    
    # Broadcast presence updates
    Enum.each(state.presence_events, fn {key, event} ->
      PubSub.broadcast!(
        SlackClone.PubSub,
        "#{@presence_topic}workspace:#{event.workspace_id}",
        {:presence_update, %{user_id: event.user_id, data: event.data}}
      )
    end)
    
    # Reset state
    new_state = %BatchState{
      messages: %{},
      typing_events: state.typing_events,  # Keep typing events
      presence_events: %{},
      timer: nil
    }
    
    {:noreply, new_state}
  end
  
  def handle_info(_message, state) do
    {:noreply, state}
  end
  
  # Private helper functions
  
  defp maybe_start_batch_timer(state) do
    if is_nil(state.timer) do
      timer = Process.send_after(self(), :flush_batches, @batch_interval)
      %{state | timer: timer}
    else
      state
    end
  end
  
  @doc """
  Get channel subscription statistics for monitoring.
  """
  def get_subscription_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
  
  def handle_call(:get_stats, _from, state) do
    stats = %{
      batched_channels: map_size(state.messages),
      total_batched_messages: 
        state.messages
        |> Map.values()
        |> Enum.map(&length/1)
        |> Enum.sum(),
      active_typing_indicators: map_size(state.typing_events),
      pending_presence_updates: map_size(state.presence_events),
      timer_active: not is_nil(state.timer)
    }
    
    {:reply, stats, state}
  end
end