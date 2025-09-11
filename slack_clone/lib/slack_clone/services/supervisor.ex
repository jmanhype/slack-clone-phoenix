defmodule SlackClone.Services.Supervisor do
  @moduledoc """
  Supervisor for all SlackClone service GenServers.
  Uses different restart strategies for different types of services.
  """

  use Supervisor
  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Starting SlackClone.Services.Supervisor")
    
    children = [
      # Core service registries - these must start first
      {Registry, keys: :unique, name: SlackClone.WorkspaceRegistry},
      {Registry, keys: :unique, name: SlackClone.ChannelRegistry},
      
      # Performance monitoring services - must start before other services
      {SlackClone.Performance.PubSubOptimizer, []},
      {SlackClone.Performance.Monitor, []},
      
      # Singleton services - restart individually
      {SlackClone.Services.MessageBufferServer, []},
      {SlackClone.Services.PresenceTracker, []},
      {SlackClone.Services.NotificationServer, []},
      {SlackClone.Services.UploadProcessor, []},
      
      # Dynamic supervisors for workspace and channel servers
      {DynamicSupervisor, name: SlackClone.WorkspaceSupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: SlackClone.ChannelSupervisor, strategy: :one_for_one}
    ]

    # Use one_for_one strategy so individual service failures don't affect others
    # except for registries which use rest_for_one so dependent services restart
    opts = [
      strategy: :one_for_one,
      name: SlackClone.Services.Supervisor,
      max_restarts: 5,
      max_seconds: 60
    ]

    Supervisor.init(children, opts)
  end

  ## Public API for managing dynamic servers

  @doc """
  Start a workspace server
  """
  def start_workspace_server(workspace_id) do
    child_spec = {SlackClone.Services.WorkspaceServer, workspace_id}
    
    case DynamicSupervisor.start_child(SlackClone.WorkspaceSupervisor, child_spec) do
      {:ok, pid} -> 
        Logger.info("Started WorkspaceServer for workspace #{workspace_id}")
        {:ok, pid}
      {:error, {:already_started, pid}} -> 
        {:ok, pid}
      error -> 
        Logger.error("Failed to start WorkspaceServer for workspace #{workspace_id}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Stop a workspace server
  """
  def stop_workspace_server(workspace_id) do
    case Registry.lookup(SlackClone.WorkspaceRegistry, workspace_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(SlackClone.WorkspaceSupervisor, pid)
      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Start a channel server
  """
  def start_channel_server(channel_id) do
    child_spec = {SlackClone.Services.ChannelServer, channel_id}
    
    case DynamicSupervisor.start_child(SlackClone.ChannelSupervisor, child_spec) do
      {:ok, pid} -> 
        Logger.info("Started ChannelServer for channel #{channel_id}")
        {:ok, pid}
      {:error, {:already_started, pid}} -> 
        {:ok, pid}
      error -> 
        Logger.error("Failed to start ChannelServer for channel #{channel_id}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Stop a channel server
  """
  def stop_channel_server(channel_id) do
    case Registry.lookup(SlackClone.ChannelRegistry, channel_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(SlackClone.ChannelSupervisor, pid)
      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  List all running workspace servers
  """
  def list_workspace_servers do
    SlackClone.WorkspaceSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.map(fn pid ->
      case Registry.keys(SlackClone.WorkspaceRegistry, pid) do
        [workspace_id] -> %{workspace_id: workspace_id, pid: pid}
        [] -> %{workspace_id: nil, pid: pid}
      end
    end)
  end

  @doc """
  List all running channel servers
  """
  def list_channel_servers do
    SlackClone.ChannelSupervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.map(fn pid ->
      case Registry.keys(SlackClone.ChannelRegistry, pid) do
        [channel_id] -> %{channel_id: channel_id, pid: pid}
        [] -> %{channel_id: nil, pid: pid}
      end
    end)
  end

  @doc """
  Get service health status
  """
  def health_check do
    services = [
      {:pubsub_optimizer, SlackClone.Performance.PubSubOptimizer},
      {:performance_monitor, SlackClone.Performance.Monitor},
      {:message_buffer, SlackClone.Services.MessageBufferServer},
      {:presence_tracker, SlackClone.Services.PresenceTracker},
      {:notification_server, SlackClone.Services.NotificationServer},
      {:upload_processor, SlackClone.Services.UploadProcessor}
    ]
    
    service_status = 
      services
      |> Enum.map(fn {name, module} ->
        status = case Process.whereis(module) do
          nil -> :stopped
          pid when is_pid(pid) -> :running
        end
        {name, status}
      end)
      |> Enum.into(%{})
    
    workspace_count = length(list_workspace_servers())
    channel_count = length(list_channel_servers())
    
    %{
      services: service_status,
      dynamic_servers: %{
        workspaces: workspace_count,
        channels: channel_count
      },
      timestamp: DateTime.utc_now()
    }
  end
end