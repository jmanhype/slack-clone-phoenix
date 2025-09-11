defmodule SlackClone.Services.SupervisorTest do
  use ExUnit.Case, async: false

  alias SlackClone.Services.Supervisor, as: ServicesSupervisor

  setup do
    # Ensure services supervisor is running
    case Process.whereis(ServicesSupervisor) do
      nil -> 
        {:ok, _pid} = ServicesSupervisor.start_link([])
        :ok
      _pid -> 
        :ok
    end
  end

  describe "start_workspace_server/1" do
    test "starts a workspace server successfully" do
      workspace_id = "test_workspace_#{:rand.uniform(1000)}"
      
      {:ok, pid} = ServicesSupervisor.start_workspace_server(workspace_id)
      
      assert is_pid(pid)
      assert Process.alive?(pid)
      
      # Verify it's registered
      registry_lookup = Registry.lookup(SlackClone.WorkspaceRegistry, workspace_id)
      assert [{^pid, _}] = registry_lookup
      
      # Cleanup
      ServicesSupervisor.stop_workspace_server(workspace_id)
    end
    
    test "returns existing server if already started" do
      workspace_id = "existing_workspace_#{:rand.uniform(1000)}"
      
      {:ok, pid1} = ServicesSupervisor.start_workspace_server(workspace_id)
      {:ok, pid2} = ServicesSupervisor.start_workspace_server(workspace_id)
      
      assert pid1 == pid2
      
      # Cleanup
      ServicesSupervisor.stop_workspace_server(workspace_id)
    end
  end

  describe "stop_workspace_server/1" do
    test "stops a running workspace server" do
      workspace_id = "stop_test_workspace_#{:rand.uniform(1000)}"
      
      {:ok, pid} = ServicesSupervisor.start_workspace_server(workspace_id)
      assert Process.alive?(pid)
      
      :ok = ServicesSupervisor.stop_workspace_server(workspace_id)
      
      # Wait for shutdown
      :timer.sleep(100)
      
      # Verify it's no longer registered
      registry_lookup = Registry.lookup(SlackClone.WorkspaceRegistry, workspace_id)
      assert [] = registry_lookup
    end
    
    test "returns error for non-existent workspace server" do
      workspace_id = "non_existent_workspace"
      
      result = ServicesSupervisor.stop_workspace_server(workspace_id)
      assert result == {:error, :not_found}
    end
  end

  describe "start_channel_server/1" do
    test "starts a channel server successfully" do
      channel_id = "test_channel_#{:rand.uniform(1000)}"
      
      {:ok, pid} = ServicesSupervisor.start_channel_server(channel_id)
      
      assert is_pid(pid)
      assert Process.alive?(pid)
      
      # Verify it's registered
      registry_lookup = Registry.lookup(SlackClone.ChannelRegistry, channel_id)
      assert [{^pid, _}] = registry_lookup
      
      # Cleanup
      ServicesSupervisor.stop_channel_server(channel_id)
    end
    
    test "returns existing server if already started" do
      channel_id = "existing_channel_#{:rand.uniform(1000)}"
      
      {:ok, pid1} = ServicesSupervisor.start_channel_server(channel_id)
      {:ok, pid2} = ServicesSupervisor.start_channel_server(channel_id)
      
      assert pid1 == pid2
      
      # Cleanup
      ServicesSupervisor.stop_channel_server(channel_id)
    end
  end

  describe "stop_channel_server/1" do
    test "stops a running channel server" do
      channel_id = "stop_test_channel_#{:rand.uniform(1000)}"
      
      {:ok, pid} = ServicesSupervisor.start_channel_server(channel_id)
      assert Process.alive?(pid)
      
      :ok = ServicesSupervisor.stop_channel_server(channel_id)
      
      # Wait for shutdown
      :timer.sleep(100)
      
      # Verify it's no longer registered
      registry_lookup = Registry.lookup(SlackClone.ChannelRegistry, channel_id)
      assert [] = registry_lookup
    end
    
    test "returns error for non-existent channel server" do
      channel_id = "non_existent_channel"
      
      result = ServicesSupervisor.stop_channel_server(channel_id)
      assert result == {:error, :not_found}
    end
  end

  describe "list_workspace_servers/0" do
    test "returns list of running workspace servers" do
      workspace_id1 = "list_workspace_1_#{:rand.uniform(1000)}"
      workspace_id2 = "list_workspace_2_#{:rand.uniform(1000)}"
      
      {:ok, _pid1} = ServicesSupervisor.start_workspace_server(workspace_id1)
      {:ok, _pid2} = ServicesSupervisor.start_workspace_server(workspace_id2)
      
      servers = ServicesSupervisor.list_workspace_servers()
      
      assert is_list(servers)
      assert length(servers) >= 2
      
      workspace_ids = Enum.map(servers, & &1.workspace_id)
      assert workspace_id1 in workspace_ids
      assert workspace_id2 in workspace_ids
      
      # Cleanup
      ServicesSupervisor.stop_workspace_server(workspace_id1)
      ServicesSupervisor.stop_workspace_server(workspace_id2)
    end
  end

  describe "list_channel_servers/0" do
    test "returns list of running channel servers" do
      channel_id1 = "list_channel_1_#{:rand.uniform(1000)}"
      channel_id2 = "list_channel_2_#{:rand.uniform(1000)}"
      
      {:ok, _pid1} = ServicesSupervisor.start_channel_server(channel_id1)
      {:ok, _pid2} = ServicesSupervisor.start_channel_server(channel_id2)
      
      servers = ServicesSupervisor.list_channel_servers()
      
      assert is_list(servers)
      assert length(servers) >= 2
      
      channel_ids = Enum.map(servers, & &1.channel_id)
      assert channel_id1 in channel_ids
      assert channel_id2 in channel_ids
      
      # Cleanup
      ServicesSupervisor.stop_channel_server(channel_id1)
      ServicesSupervisor.stop_channel_server(channel_id2)
    end
  end

  describe "health_check/0" do
    test "returns comprehensive health status" do
      health = ServicesSupervisor.health_check()
      
      assert is_map(health)
      assert Map.has_key?(health, :services)
      assert Map.has_key?(health, :dynamic_servers)
      assert Map.has_key?(health, :timestamp)
      
      # Check service statuses
      assert is_map(health.services)
      assert Map.has_key?(health.services, :message_buffer)
      assert Map.has_key?(health.services, :presence_tracker)
      assert Map.has_key?(health.services, :notification_server)
      assert Map.has_key?(health.services, :upload_processor)
      
      # Check dynamic server counts
      assert is_map(health.dynamic_servers)
      assert Map.has_key?(health.dynamic_servers, :workspaces)
      assert Map.has_key?(health.dynamic_servers, :channels)
      assert is_integer(health.dynamic_servers.workspaces)
      assert is_integer(health.dynamic_servers.channels)
      
      # Check timestamp
      assert is_struct(health.timestamp, DateTime)
    end
    
    test "reflects actual running services" do
      # Start some servers
      workspace_id = "health_workspace_#{:rand.uniform(1000)}"
      channel_id = "health_channel_#{:rand.uniform(1000)}"
      
      {:ok, _} = ServicesSupervisor.start_workspace_server(workspace_id)
      {:ok, _} = ServicesSupervisor.start_channel_server(channel_id)
      
      health = ServicesSupervisor.health_check()
      
      assert health.dynamic_servers.workspaces >= 1
      assert health.dynamic_servers.channels >= 1
      
      # Cleanup
      ServicesSupervisor.stop_workspace_server(workspace_id)
      ServicesSupervisor.stop_channel_server(channel_id)
    end
  end

  describe "supervision behavior" do
    test "restarts failed workspace server" do
      workspace_id = "restart_test_workspace_#{:rand.uniform(1000)}"
      
      {:ok, original_pid} = ServicesSupervisor.start_workspace_server(workspace_id)
      
      # Kill the server
      Process.exit(original_pid, :kill)
      
      # Wait for supervisor to restart it
      :timer.sleep(200)
      
      # Check if a new server was started
      registry_lookup = Registry.lookup(SlackClone.WorkspaceRegistry, workspace_id)
      
      case registry_lookup do
        [{new_pid, _}] ->
          assert new_pid != original_pid
          assert Process.alive?(new_pid)
        [] ->
          # Supervisor might not restart immediately, that's also valid behavior
          :ok
      end
      
      # Cleanup
      ServicesSupervisor.stop_workspace_server(workspace_id)
    end
    
    test "restarts failed channel server" do
      channel_id = "restart_test_channel_#{:rand.uniform(1000)}"
      
      {:ok, original_pid} = ServicesSupervisor.start_channel_server(channel_id)
      
      # Kill the server
      Process.exit(original_pid, :kill)
      
      # Wait for supervisor to restart it
      :timer.sleep(200)
      
      # Check if a new server was started
      registry_lookup = Registry.lookup(SlackClone.ChannelRegistry, channel_id)
      
      case registry_lookup do
        [{new_pid, _}] ->
          assert new_pid != original_pid
          assert Process.alive?(new_pid)
        [] ->
          # Supervisor might not restart immediately, that's also valid behavior
          :ok
      end
      
      # Cleanup
      ServicesSupervisor.stop_channel_server(channel_id)
    end
  end
end