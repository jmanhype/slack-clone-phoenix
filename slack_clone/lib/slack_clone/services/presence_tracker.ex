defmodule SlackClone.Services.PresenceTracker do
  @moduledoc """
  GenServer for tracking user presence states (online/offline/away).
  Integrates with Phoenix LiveView for real-time updates.
  """

  use GenServer
  require Logger

  alias Phoenix.PubSub
  alias SlackClone.Accounts.User

  @presence_timeout 30_000  # 30 seconds
  @away_timeout 300_000     # 5 minutes
  @cleanup_interval 60_000  # 1 minute

  defstruct [:presences, :timers, :stats]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Mark user as online
  """
  def user_online(user_id, socket_id \\ nil, metadata \\ %{}) do
    GenServer.cast(__MODULE__, {:user_online, user_id, socket_id, metadata})
  end

  @doc """
  Mark user as away
  """
  def user_away(user_id) do
    GenServer.cast(__MODULE__, {:user_away, user_id})
  end

  @doc """
  Mark user as offline
  """
  def user_offline(user_id, socket_id \\ nil) do
    GenServer.cast(__MODULE__, {:user_offline, user_id, socket_id})
  end

  @doc """
  Get user's current presence status
  """
  def get_presence(user_id) do
    GenServer.call(__MODULE__, {:get_presence, user_id})
  end

  @doc """
  Get all users' presence in a workspace
  """
  def get_workspace_presence(workspace_id) do
    GenServer.call(__MODULE__, {:get_workspace_presence, workspace_id})
  end

  @doc """
  Get presence statistics
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting PresenceTracker")
    
    # Schedule periodic cleanup
    :timer.send_interval(@cleanup_interval, :cleanup_stale_presences)
    
    state = %__MODULE__{
      presences: %{},
      timers: %{},
      stats: %{
        online_users: 0,
        away_users: 0,
        total_connections: 0,
        last_cleanup: DateTime.utc_now()
      }
    }
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:user_online, user_id, socket_id, metadata}, state) do
    Logger.debug("User #{user_id} coming online (socket: #{socket_id})")
    
    current_time = DateTime.utc_now()
    
    # Cancel existing timers for this user
    new_timers = cancel_user_timers(state.timers, user_id)
    
    # Update or create presence record
    presence = %{
      user_id: user_id,
      status: :online,
      last_seen: current_time,
      sockets: add_socket(get_user_sockets(state.presences, user_id), socket_id),
      metadata: metadata
    }
    
    new_presences = Map.put(state.presences, user_id, presence)
    
    # Set away timer
    away_timer = Process.send_after(self(), {:set_user_away, user_id}, @away_timeout)
    new_timers = Map.put(new_timers, {user_id, :away}, away_timer)
    
    # Broadcast presence change
    broadcast_presence_change(user_id, :online, metadata)
    
    new_stats = update_stats(state.stats, new_presences)
    
    {:noreply, %{state | presences: new_presences, timers: new_timers, stats: new_stats}}
  end

  def handle_cast({:user_away, user_id}, state) do
    case Map.get(state.presences, user_id) do
      nil ->
        {:noreply, state}
        
      presence ->
        Logger.debug("User #{user_id} marked as away")
        
        updated_presence = %{presence | status: :away, last_seen: DateTime.utc_now()}
        new_presences = Map.put(state.presences, user_id, updated_presence)
        
        # Cancel away timer, keep offline timer
        new_timers = cancel_user_timer(state.timers, user_id, :away)
        
        # Set offline timer
        offline_timer = Process.send_after(self(), {:set_user_offline, user_id}, @presence_timeout)
        new_timers = Map.put(new_timers, {user_id, :offline}, offline_timer)
        
        broadcast_presence_change(user_id, :away, presence.metadata)
        
        new_stats = update_stats(state.stats, new_presences)
        
        {:noreply, %{state | presences: new_presences, timers: new_timers, stats: new_stats}}
    end
  end

  def handle_cast({:user_offline, user_id, socket_id}, state) do
    case Map.get(state.presences, user_id) do
      nil ->
        {:noreply, state}
        
      presence ->
        # Remove socket if specified
        new_sockets = remove_socket(presence.sockets, socket_id)
        
        if length(new_sockets) == 0 do
          Logger.debug("User #{user_id} going offline")
          
          # Remove presence entirely
          new_presences = Map.delete(state.presences, user_id)
          new_timers = cancel_user_timers(state.timers, user_id)
          
          broadcast_presence_change(user_id, :offline, presence.metadata)
          
          new_stats = update_stats(state.stats, new_presences)
          
          {:noreply, %{state | presences: new_presences, timers: new_timers, stats: new_stats}}
        else
          # Keep presence but update sockets
          updated_presence = %{presence | sockets: new_sockets, last_seen: DateTime.utc_now()}
          new_presences = Map.put(state.presences, user_id, updated_presence)
          
          {:noreply, %{state | presences: new_presences}}
        end
    end
  end

  @impl true
  def handle_call({:get_presence, user_id}, _from, state) do
    presence = Map.get(state.presences, user_id, %{status: :offline})
    {:reply, presence, state}
  end

  def handle_call({:get_workspace_presence, workspace_id}, _from, state) do
    # Filter presences by workspace membership
    workspace_presences = 
      state.presences
      |> Enum.filter(fn {user_id, _presence} ->
        # This would need to check workspace membership
        # For now, return all presences
        true
      end)
      |> Enum.into(%{})
    
    {:reply, workspace_presences, state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info({:set_user_away, user_id}, state) do
    # Remove the timer reference
    new_timers = cancel_user_timer(state.timers, user_id, :away)
    
    case Map.get(state.presences, user_id) do
      %{status: :online} = presence ->
        updated_presence = %{presence | status: :away, last_seen: DateTime.utc_now()}
        new_presences = Map.put(state.presences, user_id, updated_presence)
        
        # Set offline timer
        offline_timer = Process.send_after(self(), {:set_user_offline, user_id}, @presence_timeout)
        new_timers = Map.put(new_timers, {user_id, :offline}, offline_timer)
        
        broadcast_presence_change(user_id, :away, presence.metadata)
        
        new_stats = update_stats(state.stats, new_presences)
        
        {:noreply, %{state | presences: new_presences, timers: new_timers, stats: new_stats}}
        
      _ ->
        {:noreply, %{state | timers: new_timers}}
    end
  end

  def handle_info({:set_user_offline, user_id}, state) do
    new_timers = cancel_user_timer(state.timers, user_id, :offline)
    
    case Map.get(state.presences, user_id) do
      nil ->
        {:noreply, %{state | timers: new_timers}}
        
      presence ->
        Logger.debug("User #{user_id} timed out, setting offline")
        
        new_presences = Map.delete(state.presences, user_id)
        all_new_timers = cancel_user_timers(new_timers, user_id)
        
        broadcast_presence_change(user_id, :offline, presence.metadata)
        
        new_stats = update_stats(state.stats, new_presences)
        
        {:noreply, %{state | presences: new_presences, timers: all_new_timers, stats: new_stats}}
    end
  end

  def handle_info(:cleanup_stale_presences, state) do
    Logger.debug("Running presence cleanup")
    
    cutoff_time = DateTime.add(DateTime.utc_now(), -@presence_timeout, :millisecond)
    
    {stale_users, fresh_presences} = 
      state.presences
      |> Enum.split_with(fn {_user_id, presence} ->
        DateTime.compare(presence.last_seen, cutoff_time) == :lt
      end)
    
    if length(stale_users) > 0 do
      Logger.info("Cleaning up #{length(stale_users)} stale presences")
      
      # Remove stale presences and their timers
      new_presences = Enum.into(fresh_presences, %{})
      new_timers = 
        stale_users
        |> Enum.reduce(state.timers, fn {user_id, presence}, acc ->
          broadcast_presence_change(user_id, :offline, presence.metadata)
          cancel_user_timers(acc, user_id)
        end)
      
      new_stats = %{
        state.stats |
        last_cleanup: DateTime.utc_now()
      }
      |> update_stats(new_presences)
      
      {:noreply, %{state | presences: new_presences, timers: new_timers, stats: new_stats}}
    else
      new_stats = %{state.stats | last_cleanup: DateTime.utc_now()}
      {:noreply, %{state | stats: new_stats}}
    end
  end

  ## Private Functions

  defp get_user_sockets(presences, user_id) do
    case Map.get(presences, user_id) do
      nil -> []
      presence -> presence.sockets
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

  defp cancel_user_timers(timers, user_id) do
    [:away, :offline]
    |> Enum.reduce(timers, fn timer_type, acc ->
      cancel_user_timer(acc, user_id, timer_type)
    end)
  end

  defp cancel_user_timer(timers, user_id, timer_type) do
    case Map.pop(timers, {user_id, timer_type}) do
      {nil, timers} -> timers
      {timer_ref, timers} ->
        Process.cancel_timer(timer_ref)
        timers
    end
  end

  defp broadcast_presence_change(user_id, status, metadata) do
    PubSub.broadcast(
      SlackClone.PubSub,
      "presence:updates",
      {:presence_diff, %{user_id => %{status: status, metadata: metadata}}}
    )
    
    PubSub.broadcast(
      SlackClone.PubSub,
      "presence:user:#{user_id}",
      {:presence_change, status, metadata}
    )
  end

  defp update_stats(stats, presences) do
    online_count = 
      presences
      |> Enum.count(fn {_user_id, presence} -> presence.status == :online end)
    
    away_count = 
      presences
      |> Enum.count(fn {_user_id, presence} -> presence.status == :away end)
    
    total_connections = 
      presences
      |> Enum.reduce(0, fn {_user_id, presence}, acc -> 
        acc + length(presence.sockets)
      end)
    
    %{
      stats |
      online_users: online_count,
      away_users: away_count,
      total_connections: total_connections
    }
  end
end