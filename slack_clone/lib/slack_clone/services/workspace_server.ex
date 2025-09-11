defmodule SlackClone.Services.WorkspaceServer do
  @moduledoc """
  GenServer for managing workspace state and member connections.
  Handles workspace-level operations and member coordination.
  """

  use GenServer
  require Logger

  alias SlackClone.Workspaces
  alias SlackClone.Workspaces.Workspace
  alias SlackClone.Accounts.User
  alias Phoenix.PubSub

  @member_timeout 300_000  # 5 minutes
  @stats_interval 60_000   # 1 minute

  defstruct [
    :workspace_id,
    :workspace_data,
    :members,
    :member_timers,
    :channels,
    :stats
  ]

  ## Client API

  def start_link(workspace_id, opts \\ []) do
    GenServer.start_link(__MODULE__, workspace_id, 
      name: via_tuple(workspace_id))
  end

  @doc """
  Add a member connection to workspace
  """
  def join_workspace(workspace_id, user_id, socket_id \\ nil, metadata \\ %{}) do
    GenServer.cast(via_tuple(workspace_id), 
      {:join_workspace, user_id, socket_id, metadata})
  end

  @doc """
  Remove a member connection from workspace
  """
  def leave_workspace(workspace_id, user_id, socket_id \\ nil) do
    GenServer.cast(via_tuple(workspace_id), 
      {:leave_workspace, user_id, socket_id})
  end

  @doc """
  Get workspace state
  """
  def get_workspace_state(workspace_id) do
    GenServer.call(via_tuple(workspace_id), :get_workspace_state)
  end

  @doc """
  Get active members in workspace
  """
  def get_active_members(workspace_id) do
    GenServer.call(via_tuple(workspace_id), :get_active_members)
  end

  @doc """
  Update workspace data
  """
  def update_workspace(workspace_id, updates) do
    GenServer.cast(via_tuple(workspace_id), {:update_workspace, updates})
  end

  @doc """
  Broadcast message to all workspace members
  """
  def broadcast_to_workspace(workspace_id, event, payload) do
    GenServer.cast(via_tuple(workspace_id), 
      {:broadcast_to_workspace, event, payload})
  end

  @doc """
  Get workspace statistics
  """
  def get_stats(workspace_id) do
    GenServer.call(via_tuple(workspace_id), :get_stats)
  end

  ## GenServer Callbacks

  @impl true
  def init(workspace_id) do
    Logger.info("Starting WorkspaceServer for workspace #{workspace_id}")
    
    # Load workspace data
    case Workspaces.get_workspace(workspace_id) do
      nil ->
        Logger.error("Workspace #{workspace_id} not found")
        {:stop, :workspace_not_found}
        
      workspace ->
        # Schedule periodic stats updates
        :timer.send_interval(@stats_interval, :update_stats)
        
        # Subscribe to workspace events
        PubSub.subscribe(SlackClone.PubSub, "workspace:#{workspace_id}")
        
        state = %__MODULE__{
          workspace_id: workspace_id,
          workspace_data: workspace,
          members: %{},
          member_timers: %{},
          channels: load_workspace_channels(workspace_id),
          stats: %{
            active_members: 0,
            total_connections: 0,
            messages_today: 0,
            last_activity: DateTime.utc_now(),
            uptime: DateTime.utc_now()
          }
        }
        
        {:ok, state}
    end
  end

  @impl true
  def handle_cast({:join_workspace, user_id, socket_id, metadata}, state) do
    Logger.debug("User #{user_id} joining workspace #{state.workspace_id}")
    
    # Check if user is actually a member of this workspace
    case is_workspace_member?(state.workspace_id, user_id) do
      false ->
        Logger.warn("User #{user_id} attempted to join workspace #{state.workspace_id} but is not a member")
        {:noreply, state}
        
      true ->
        current_time = DateTime.utc_now()
        
        # Cancel existing timeout for this user
        new_timers = cancel_member_timer(state.member_timers, user_id)
        
        # Update or create member record
        member = %{
          user_id: user_id,
          joined_at: current_time,
          last_activity: current_time,
          sockets: add_socket(get_member_sockets(state.members, user_id), socket_id),
          metadata: metadata
        }
        
        new_members = Map.put(state.members, user_id, member)
        
        # Set member timeout
        timeout_timer = Process.send_after(self(), 
          {:member_timeout, user_id}, @member_timeout)
        new_timers = Map.put(new_timers, user_id, timeout_timer)
        
        # Broadcast member joined
        broadcast_member_change(state.workspace_id, user_id, :joined, metadata)
        
        # Update stats
        new_stats = update_member_stats(state.stats, new_members)
        
        {:noreply, %{state | 
          members: new_members, 
          member_timers: new_timers,
          stats: new_stats
        }}
    end
  end

  def handle_cast({:leave_workspace, user_id, socket_id}, state) do
    case Map.get(state.members, user_id) do
      nil ->
        {:noreply, state}
        
      member ->
        # Remove socket if specified
        new_sockets = remove_socket(member.sockets, socket_id)
        
        if length(new_sockets) == 0 do
          Logger.debug("User #{user_id} leaving workspace #{state.workspace_id}")
          
          # Remove member entirely
          new_members = Map.delete(state.members, user_id)
          new_timers = cancel_member_timer(state.member_timers, user_id)
          
          broadcast_member_change(state.workspace_id, user_id, :left, member.metadata)
          
          new_stats = update_member_stats(state.stats, new_members)
          
          {:noreply, %{state | 
            members: new_members, 
            member_timers: new_timers,
            stats: new_stats
          }}
        else
          # Keep member but update sockets
          updated_member = %{member | 
            sockets: new_sockets, 
            last_activity: DateTime.utc_now()
          }
          new_members = Map.put(state.members, user_id, updated_member)
          
          {:noreply, %{state | members: new_members}}
        end
    end
  end

  def handle_cast({:update_workspace, updates}, state) do
    case Workspaces.update_workspace(state.workspace_data, updates) do
      {:ok, updated_workspace} ->
        Logger.info("Workspace #{state.workspace_id} updated")
        
        # Broadcast workspace update
        PubSub.broadcast(SlackClone.PubSub, 
          "workspace:#{state.workspace_id}:updates",
          {:workspace_updated, updated_workspace}
        )
        
        {:noreply, %{state | workspace_data: updated_workspace}}
        
      {:error, changeset} ->
        Logger.error("Failed to update workspace #{state.workspace_id}: #{inspect(changeset)}")
        {:noreply, state}
    end
  end

  def handle_cast({:broadcast_to_workspace, event, payload}, state) do
    Logger.debug("Broadcasting #{event} to workspace #{state.workspace_id}")
    
    PubSub.broadcast(SlackClone.PubSub,
      "workspace:#{state.workspace_id}:events",
      {event, payload}
    )
    
    # Update activity stats
    new_stats = %{state.stats | last_activity: DateTime.utc_now()}
    
    {:noreply, %{state | stats: new_stats}}
  end

  @impl true
  def handle_call(:get_workspace_state, _from, state) do
    workspace_state = %{
      workspace: state.workspace_data,
      active_members: state.members,
      channels: state.channels,
      stats: state.stats
    }
    
    {:reply, workspace_state, state}
  end

  def handle_call(:get_active_members, _from, state) do
    active_members = 
      state.members
      |> Enum.map(fn {user_id, member} ->
        %{
          user_id: user_id,
          joined_at: member.joined_at,
          last_activity: member.last_activity,
          connection_count: length(member.sockets),
          metadata: member.metadata
        }
      end)
    
    {:reply, active_members, state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info({:member_timeout, user_id}, state) do
    case Map.get(state.members, user_id) do
      nil ->
        {:noreply, state}
        
      member ->
        Logger.debug("Member #{user_id} timed out in workspace #{state.workspace_id}")
        
        new_members = Map.delete(state.members, user_id)
        new_timers = Map.delete(state.member_timers, user_id)
        
        broadcast_member_change(state.workspace_id, user_id, :timeout, member.metadata)
        
        new_stats = update_member_stats(state.stats, new_members)
        
        {:noreply, %{state | 
          members: new_members, 
          member_timers: new_timers,
          stats: new_stats
        }}
    end
  end

  def handle_info(:update_stats, state) do
    # Update various statistics
    new_stats = %{
      state.stats |
      messages_today: get_workspace_message_count(state.workspace_id),
      last_activity: get_last_workspace_activity(state.workspace_id)
    }
    
    # Broadcast stats update
    PubSub.broadcast(SlackClone.PubSub,
      "workspace:#{state.workspace_id}:stats",
      {:stats_update, new_stats}
    )
    
    {:noreply, %{state | stats: new_stats}}
  end

  # Handle workspace events from PubSub
  def handle_info({:workspace_updated, workspace}, state) do
    {:noreply, %{state | workspace_data: workspace}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("WorkspaceServer for workspace #{state.workspace_id} terminating: #{inspect(reason)}")
    
    # Clean up member timers
    state.member_timers
    |> Enum.each(fn {_user_id, timer_ref} ->
      Process.cancel_timer(timer_ref)
    end)
    
    :ok
  end

  ## Private Functions

  defp via_tuple(workspace_id) do
    {:via, Registry, {SlackClone.WorkspaceRegistry, workspace_id}}
  end

  defp load_workspace_channels(workspace_id) do
    # Load channels for this workspace
    case Workspaces.list_workspace_channels(workspace_id) do
      channels when is_list(channels) ->
        Enum.map(channels, fn channel ->
          %{
            id: channel.id,
            name: channel.name,
            type: channel.type,
            member_count: channel.member_count || 0
          }
        end)
      _ -> []
    end
  end

  defp is_workspace_member?(workspace_id, user_id) do
    Workspaces.is_member?(workspace_id, user_id)
  end

  defp get_member_sockets(members, user_id) do
    case Map.get(members, user_id) do
      nil -> []
      member -> member.sockets
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

  defp cancel_member_timer(timers, user_id) do
    case Map.pop(timers, user_id) do
      {nil, timers} -> timers
      {timer_ref, timers} ->
        Process.cancel_timer(timer_ref)
        timers
    end
  end

  defp broadcast_member_change(workspace_id, user_id, action, metadata) do
    PubSub.broadcast(SlackClone.PubSub,
      "workspace:#{workspace_id}:members",
      {:member_change, user_id, action, metadata}
    )
  end

  defp update_member_stats(stats, members) do
    active_count = map_size(members)
    
    total_connections = 
      members
      |> Enum.reduce(0, fn {_user_id, member}, acc ->
        acc + length(member.sockets)
      end)
    
    %{
      stats |
      active_members: active_count,
      total_connections: total_connections
    }
  end

  defp get_workspace_message_count(workspace_id) do
    # This would query the database for today's message count
    # For now, return a placeholder
    0
  end

  defp get_last_workspace_activity(workspace_id) do
    # This would query for the most recent activity
    # For now, return current time
    DateTime.utc_now()
  end
end