defmodule SlackClone.Services.Coordinator do
  @moduledoc """
  Coordination module for managing service interactions and startup/shutdown.
  Handles hooks and cross-service communication.
  """

  use GenServer
  require Logger

  alias SlackClone.Services.Supervisor, as: ServicesSupervisor
  alias Phoenix.PubSub

  @service_startup_timeout 10_000

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Ensure workspace server is running for a workspace
  """
  def ensure_workspace_server(workspace_id) do
    GenServer.call(__MODULE__, {:ensure_workspace_server, workspace_id})
  end

  @doc """
  Ensure channel server is running for a channel
  """
  def ensure_channel_server(channel_id) do
    GenServer.call(__MODULE__, {:ensure_channel_server, channel_id})
  end

  @doc """
  Gracefully shutdown a workspace and its channels
  """
  def shutdown_workspace(workspace_id) do
    GenServer.cast(__MODULE__, {:shutdown_workspace, workspace_id})
  end

  @doc """
  Get system coordination status
  """
  def get_coordination_status do
    GenServer.call(__MODULE__, :get_coordination_status)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting SlackClone.Services.Coordinator")
    
    # Subscribe to service events
    PubSub.subscribe(SlackClone.PubSub, "services:coordination")
    
    # Initialize coordination hooks
    :ok = initialize_hooks()
    
    state = %{
      workspace_servers: %{},
      channel_servers: %{},
      startup_time: DateTime.utc_now(),
      coordination_events: []
    }
    
    {:ok, state}
  end

  @impl true
  def handle_call({:ensure_workspace_server, workspace_id}, _from, state) do
    case Map.get(state.workspace_servers, workspace_id) do
      nil ->
        case ServicesSupervisor.start_workspace_server(workspace_id) do
          {:ok, pid} ->
            Logger.info("Coordinator ensured WorkspaceServer for #{workspace_id}")
            
            new_state = put_in(state.workspace_servers[workspace_id], %{
              pid: pid,
              started_at: DateTime.utc_now(),
              status: :running
            })
            
            # Execute post-startup hooks
            execute_hook(:workspace_server_started, %{workspace_id: workspace_id, pid: pid})
            
            {:reply, {:ok, pid}, new_state}
            
          error ->
            Logger.error("Coordinator failed to start WorkspaceServer for #{workspace_id}: #{inspect(error)}")
            {:reply, error, state}
        end
        
      %{pid: pid, status: :running} ->
        # Already running
        {:reply, {:ok, pid}, state}
        
      %{status: :starting} ->
        # Currently starting, wait a bit
        {:reply, {:error, :starting}, state}
    end
  end

  def handle_call({:ensure_channel_server, channel_id}, _from, state) do
    case Map.get(state.channel_servers, channel_id) do
      nil ->
        case ServicesSupervisor.start_channel_server(channel_id) do
          {:ok, pid} ->
            Logger.info("Coordinator ensured ChannelServer for #{channel_id}")
            
            new_state = put_in(state.channel_servers[channel_id], %{
              pid: pid,
              started_at: DateTime.utc_now(),
              status: :running
            })
            
            # Execute post-startup hooks
            execute_hook(:channel_server_started, %{channel_id: channel_id, pid: pid})
            
            {:reply, {:ok, pid}, new_state}
            
          error ->
            Logger.error("Coordinator failed to start ChannelServer for #{channel_id}: #{inspect(error)}")
            {:reply, error, state}
        end
        
      %{pid: pid, status: :running} ->
        # Already running
        {:reply, {:ok, pid}, state}
        
      %{status: :starting} ->
        # Currently starting
        {:reply, {:error, :starting}, state}
    end
  end

  def handle_call(:get_coordination_status, _from, state) do
    status = %{
      startup_time: state.startup_time,
      uptime: DateTime.diff(DateTime.utc_now(), state.startup_time, :second),
      workspace_servers: map_size(state.workspace_servers),
      channel_servers: map_size(state.channel_servers),
      recent_events: Enum.take(state.coordination_events, 10),
      service_health: ServicesSupervisor.health_check()
    }
    
    {:reply, status, state}
  end

  @impl true
  def handle_cast({:shutdown_workspace, workspace_id}, state) do
    Logger.info("Coordinator shutting down workspace #{workspace_id}")
    
    # Find and shutdown all channels for this workspace
    workspace_channels = get_workspace_channels(workspace_id)
    
    Enum.each(workspace_channels, fn channel_id ->
      ServicesSupervisor.stop_channel_server(channel_id)
    end)
    
    # Shutdown workspace server
    ServicesSupervisor.stop_workspace_server(workspace_id)
    
    # Update state
    new_state = %{
      state |
      workspace_servers: Map.delete(state.workspace_servers, workspace_id),
      channel_servers: 
        workspace_channels
        |> Enum.reduce(state.channel_servers, fn channel_id, acc ->
          Map.delete(acc, channel_id)
        end)
    }
    
    # Execute shutdown hooks
    execute_hook(:workspace_shutdown, %{workspace_id: workspace_id, channels: workspace_channels})
    
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:service_event, event, data}, state) do
    Logger.debug("Coordinator received service event: #{event}")
    
    # Add to event history
    event_record = %{
      event: event,
      data: data,
      timestamp: DateTime.utc_now()
    }
    
    new_events = [event_record | state.coordination_events]
    |> Enum.take(100)  # Keep last 100 events
    
    new_state = %{state | coordination_events: new_events}
    
    # Handle specific coordination events
    case event do
      :workspace_member_joined ->
        handle_workspace_member_joined(data, new_state)
        
      :channel_message_sent ->
        handle_channel_message_sent(data, new_state)
        
      _ ->
        {:noreply, new_state}
    end
  end

  # Handle process down messages for tracked servers
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    Logger.warn("Tracked process #{inspect(pid)} went down: #{inspect(reason)}")
    
    # Remove from tracking
    new_workspace_servers = 
      state.workspace_servers
      |> Enum.reject(fn {_id, info} -> info.pid == pid end)
      |> Enum.into(%{})
    
    new_channel_servers = 
      state.channel_servers
      |> Enum.reject(fn {_id, info} -> info.pid == pid end)
      |> Enum.into(%{})
    
    new_state = %{
      state |
      workspace_servers: new_workspace_servers,
      channel_servers: new_channel_servers
    }
    
    {:noreply, new_state}
  end

  ## Private Functions

  defp initialize_hooks do
    Logger.info("Initializing coordination hooks")
    
    # Set up hooks for cross-service coordination
    :ok = setup_message_buffer_hooks()
    :ok = setup_presence_hooks()
    :ok = setup_notification_hooks()
    :ok = setup_upload_hooks()
    
    :ok
  end

  defp setup_message_buffer_hooks do
    # Hook into message buffer flushes to trigger notifications
    PubSub.subscribe(SlackClone.PubSub, "message_buffer:stats")
    :ok
  end

  defp setup_presence_hooks do
    # Hook into presence changes to update workspace member lists
    PubSub.subscribe(SlackClone.PubSub, "presence:updates")
    :ok
  end

  defp setup_notification_hooks do
    # Hook into notification events for coordination
    PubSub.subscribe(SlackClone.PubSub, "notifications:coordination")
    :ok
  end

  defp setup_upload_hooks do
    # Hook into upload processing for file sharing coordination
    PubSub.subscribe(SlackClone.PubSub, "upload_processor:jobs")
    :ok
  end

  defp execute_hook(hook_name, data) do
    Logger.debug("Executing coordination hook: #{hook_name}")
    
    # Execute hook via claude-flow if available
    case System.cmd("npx", [
      "claude-flow@alpha", "hooks", "post-edit",
      "--file", to_string(hook_name),
      "--memory-key", "swarm/coordinator/#{hook_name}"
    ], stderr_to_stdout: true) do
      {_, 0} ->
        Logger.debug("Hook #{hook_name} executed successfully")
        
      {output, _} ->
        Logger.debug("Hook execution output: #{output}")
    end
    
    # Also broadcast the hook execution
    PubSub.broadcast(
      SlackClone.PubSub,
      "coordination:hooks",
      {:hook_executed, hook_name, data}
    )
    
    :ok
  end

  defp handle_workspace_member_joined(data, state) do
    # Ensure workspace server is running when member joins
    case Map.get(data, :workspace_id) do
      nil -> {:noreply, state}
      workspace_id ->
        ensure_workspace_server(workspace_id)
        {:noreply, state}
    end
  end

  defp handle_channel_message_sent(data, state) do
    # Coordinate message-related services
    case Map.get(data, :channel_id) do
      nil -> {:noreply, state}
      channel_id ->
        # Ensure channel server is running
        ensure_channel_server(channel_id)
        
        # Trigger notification processing if needed
        if Map.get(data, :mentions, []) != [] do
          PubSub.broadcast(
            SlackClone.PubSub,
            "notifications:trigger",
            {:mention_notifications, data}
          )
        end
        
        {:noreply, state}
    end
  end

  defp get_workspace_channels(workspace_id) do
    # This would query the database for channels in a workspace
    # For now, return channels from our tracked servers
    state = :sys.get_state(__MODULE__)
    
    state.channel_servers
    |> Enum.filter(fn {channel_id, _info} ->
      # This would check if channel belongs to workspace
      # For now, assume all channels could belong to any workspace
      true
    end)
    |> Enum.map(fn {channel_id, _info} -> channel_id end)
  end
end