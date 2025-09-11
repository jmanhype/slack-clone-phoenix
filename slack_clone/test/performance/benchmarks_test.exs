defmodule SlackClone.Performance.BenchmarksTest do
  @moduledoc """
  Performance benchmarks for the Slack Clone application.
  These tests measure performance characteristics and ensure scalability.
  """
  
  use SlackClone.DataCase
  use ExMachina
  
  import SlackClone.Factory
  
  alias SlackClone.Services.{ChannelServer, PresenceTracker}
  alias SlackClone.{Messages, Channels, Accounts}
  alias Phoenix.PubSub
  
  @moduletag :benchmark
  
  describe "message processing benchmarks" do
    setup do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      users = insert_list(10, :user)
      
      for user <- users do
        insert(:workspace_membership, workspace: workspace, user: user)
        insert(:channel_membership, channel: channel, user: user)
      end
      
      {:ok, _pid} = ChannelServer.start_link(channel.id)
      
      %{channel: channel, users: users}
    end
    
    @tag timeout: 30_000
    test "message creation performance", %{channel: channel, users: users} do
      user = hd(users)
      message_count = 1000
      
      # Benchmark message creation
      {time_microseconds, _results} = :timer.tc(fn ->
        for i <- 1..message_count do
          Messages.create_message(%{
            content: "Performance test message #{i}",
            channel_id: channel.id,
            user_id: user.id,
            type: "text",
            metadata: %{}
          })
        end
      end)
      
      time_milliseconds = time_microseconds / 1000
      messages_per_second = message_count / (time_microseconds / 1_000_000)
      
      IO.puts("\n📊 Message Creation Performance:")
      IO.puts("  Total time: #{:io_lib.format('~.2f', [time_milliseconds])} ms")
      IO.puts("  Messages created: #{message_count}")
      IO.puts("  Messages per second: #{:io_lib.format('~.2f', [messages_per_second])}")
      IO.puts("  Average per message: #{:io_lib.format('~.2f', [time_milliseconds / message_count])} ms")
      
      # Performance assertions
      assert messages_per_second >= 100, "Should create at least 100 messages per second"
      assert time_milliseconds / message_count <= 50, "Should create each message in under 50ms"
    end
    
    @tag timeout: 30_000
    test "real-time message broadcasting performance", %{channel: channel, users: users} do
      user = hd(users)
      message_count = 100
      
      # Subscribe to channel to measure broadcast time
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:messages")
      
      # Join user to channel for ChannelServer broadcasting
      ChannelServer.join_channel(channel.id, user.id, "test_socket")
      
      {time_microseconds, _results} = :timer.tc(fn ->
        for i <- 1..message_count do
          ChannelServer.send_message(channel.id, user.id, "Broadcast test #{i}", %{})
          
          # Receive broadcast to measure end-to-end time
          assert_receive {:new_message, _message}, 1000
        end
      end)
      
      time_milliseconds = time_microseconds / 1000
      broadcasts_per_second = message_count / (time_microseconds / 1_000_000)
      
      IO.puts("\n📊 Real-time Broadcasting Performance:")
      IO.puts("  Total time: #{:io_lib.format('~.2f', [time_milliseconds])} ms")
      IO.puts("  Messages broadcast: #{message_count}")
      IO.puts("  Broadcasts per second: #{:io_lib.format('~.2f', [broadcasts_per_second])}")
      IO.puts("  Average per broadcast: #{:io_lib.format('~.2f', [time_milliseconds / message_count])} ms")
      
      # Performance assertions
      assert broadcasts_per_second >= 50, "Should broadcast at least 50 messages per second"
      assert time_milliseconds / message_count <= 100, "Should broadcast each message in under 100ms"
    end
    
    @tag timeout: 30_000
    test "concurrent message processing", %{channel: channel, users: users} do
      message_count_per_user = 10
      total_messages = length(users) * message_count_per_user
      
      # Join all users to channel
      for user <- users do
        ChannelServer.join_channel(channel.id, user.id, "socket_#{user.id}")
      end
      
      # Process messages concurrently from all users
      {time_microseconds, _results} = :timer.tc(fn ->
        tasks = for user <- users do
          Task.async(fn ->
            for i <- 1..message_count_per_user do
              ChannelServer.send_message(channel.id, user.id, "Concurrent message #{i}", %{})
            end
          end)
        end
        
        Task.await_many(tasks, 30_000)
      end)
      
      time_milliseconds = time_microseconds / 1000
      messages_per_second = total_messages / (time_microseconds / 1_000_000)
      
      IO.puts("\n📊 Concurrent Message Processing:")
      IO.puts("  Concurrent users: #{length(users)}")
      IO.puts("  Messages per user: #{message_count_per_user}")
      IO.puts("  Total messages: #{total_messages}")
      IO.puts("  Total time: #{:io_lib.format('~.2f', [time_milliseconds])} ms")
      IO.puts("  Messages per second: #{:io_lib.format('~.2f', [messages_per_second])}")
      
      # Verify all messages were processed
      state = ChannelServer.get_channel_state(channel.id)
      assert state.stats.messages_sent == total_messages
      
      # Performance assertions
      assert messages_per_second >= 20, "Should handle at least 20 concurrent messages per second"
    end
  end
  
  describe "presence tracking benchmarks" do
    setup do
      {:ok, _pid} = PresenceTracker.start_link()
      users = insert_list(100, :user)
      
      %{users: users}
    end
    
    @tag timeout: 30_000
    test "user presence updates performance", %{users: users} do
      user_count = length(users)
      
      # Benchmark bringing users online
      {online_time, _} = :timer.tc(fn ->
        for user <- users do
          PresenceTracker.user_online(user.id, "socket_#{user.id}")
        end
      end)
      
      online_ms = online_time / 1000
      online_per_second = user_count / (online_time / 1_000_000)
      
      # Benchmark presence queries
      {query_time, _} = :timer.tc(fn ->
        for user <- users do
          PresenceTracker.get_presence(user.id)
        end
      end)
      
      query_ms = query_time / 1000
      queries_per_second = user_count / (query_time / 1_000_000)
      
      IO.puts("\n📊 Presence Tracking Performance:")
      IO.puts("  Users tracked: #{user_count}")
      IO.puts("  Online updates: #{:io_lib.format('~.2f', [online_ms])} ms")
      IO.puts("  Online per second: #{:io_lib.format('~.2f', [online_per_second])}")
      IO.puts("  Query time: #{:io_lib.format('~.2f', [query_ms])} ms")
      IO.puts("  Queries per second: #{:io_lib.format('~.2f', [queries_per_second])}")
      
      # Verify stats
      stats = PresenceTracker.get_stats()
      assert stats.online_users == user_count
      assert stats.total_connections == user_count
      
      # Performance assertions
      assert online_per_second >= 200, "Should handle at least 200 online updates per second"
      assert queries_per_second >= 500, "Should handle at least 500 presence queries per second"
    end
    
    @tag timeout: 30_000
    test "concurrent presence operations", %{users: users} do
      operations_per_user = 5
      total_operations = length(users) * operations_per_user
      
      {time_microseconds, _} = :timer.tc(fn ->
        tasks = for user <- users do
          Task.async(fn ->
            socket_id = "socket_#{user.id}"
            
            # Mix of presence operations
            PresenceTracker.user_online(user.id, socket_id)
            PresenceTracker.get_presence(user.id)
            PresenceTracker.user_away(user.id)
            PresenceTracker.get_presence(user.id)
            PresenceTracker.user_online(user.id, socket_id)
          end)
        end
        
        Task.await_many(tasks, 30_000)
      end)
      
      time_ms = time_microseconds / 1000
      operations_per_second = total_operations / (time_microseconds / 1_000_000)
      
      IO.puts("\n📊 Concurrent Presence Operations:")
      IO.puts("  Concurrent users: #{length(users)}")
      IO.puts("  Operations per user: #{operations_per_user}")
      IO.puts("  Total operations: #{total_operations}")
      IO.puts("  Total time: #{:io_lib.format('~.2f', [time_ms])} ms")
      IO.puts("  Operations per second: #{:io_lib.format('~.2f', [operations_per_second])}")
      
      # Performance assertions
      assert operations_per_second >= 100, "Should handle at least 100 concurrent presence operations per second"
    end
  end
  
  describe "database query benchmarks" do
    setup do
      workspace = insert(:workspace)
      channels = insert_list(10, :channel, workspace: workspace)
      users = insert_list(20, :user)
      
      # Create many messages across channels
      for channel <- channels do
        for user <- Enum.take(users, 5) do
          insert(:channel_membership, channel: channel, user: user)
          insert_list(50, :message, channel: channel, user: user)
        end
      end
      
      %{workspace: workspace, channels: channels, users: users}
    end
    
    @tag timeout: 30_000
    test "message query performance", %{channels: channels} do
      channel = hd(channels)
      query_count = 100
      
      # Benchmark recent message queries
      {time_microseconds, _} = :timer.tc(fn ->
        for _i <- 1..query_count do
          Messages.get_recent_messages(channel.id, 50)
        end
      end)
      
      time_ms = time_microseconds / 1000
      queries_per_second = query_count / (time_microseconds / 1_000_000)
      
      IO.puts("\n📊 Message Query Performance:")
      IO.puts("  Queries executed: #{query_count}")
      IO.puts("  Total time: #{:io_lib.format('~.2f', [time_ms])} ms")
      IO.puts("  Queries per second: #{:io_lib.format('~.2f', [queries_per_second])}")
      IO.puts("  Average per query: #{:io_lib.format('~.2f', [time_ms / query_count])} ms")
      
      # Performance assertions
      assert queries_per_second >= 50, "Should execute at least 50 message queries per second"
      assert time_ms / query_count <= 100, "Should execute each query in under 100ms"
    end
    
    @tag timeout: 30_000
    test "user authentication performance", %{users: users} do
      user = hd(users)
      auth_count = 100
      
      # Benchmark user authentication
      {time_microseconds, _} = :timer.tc(fn ->
        for _i <- 1..auth_count do
          Accounts.get_user_by_email_and_password(user.email, "password123")
        end
      end)
      
      time_ms = time_microseconds / 1000
      auth_per_second = auth_count / (time_microseconds / 1_000_000)
      
      IO.puts("\n📊 User Authentication Performance:")
      IO.puts("  Auth attempts: #{auth_count}")
      IO.puts("  Total time: #{:io_lib.format('~.2f', [time_ms])} ms")
      IO.puts("  Auth per second: #{:io_lib.format('~.2f', [auth_per_second])}")
      IO.puts("  Average per auth: #{:io_lib.format('~.2f', [time_ms / auth_count])} ms")
      
      # Performance assertions
      assert auth_per_second >= 10, "Should handle at least 10 authentications per second"
      assert time_ms / auth_count <= 500, "Should authenticate in under 500ms"
    end
  end
  
  describe "memory usage benchmarks" do
    @tag timeout: 60_000
    test "memory usage under load" do
      # Measure initial memory
      :erlang.garbage_collect()
      initial_memory = :erlang.memory(:total)
      
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      users = insert_list(50, :user)
      
      {:ok, _pid} = ChannelServer.start_link(channel.id)
      {:ok, _pid} = PresenceTracker.start_link()
      
      # Join users and send messages to create memory load
      for user <- users do
        insert(:channel_membership, channel: channel, user: user)
        ChannelServer.join_channel(channel.id, user.id, "socket_#{user.id}")
        PresenceTracker.user_online(user.id, "socket_#{user.id}")
        
        # Send some messages
        for i <- 1..10 do
          ChannelServer.send_message(channel.id, user.id, "Message #{i}", %{})
        end
      end
      
      # Force garbage collection and measure memory
      :erlang.garbage_collect()
      Process.sleep(100) # Allow cleanup
      peak_memory = :erlang.memory(:total)
      
      # Clean up and measure final memory
      for user <- users do
        ChannelServer.leave_channel(channel.id, user.id, "socket_#{user.id}")
        PresenceTracker.user_offline(user.id, "socket_#{user.id}")
      end
      
      :erlang.garbage_collect()
      Process.sleep(100)
      final_memory = :erlang.memory(:total)
      
      memory_growth = peak_memory - initial_memory
      memory_per_user = memory_growth / length(users)
      cleanup_efficiency = (peak_memory - final_memory) / memory_growth * 100
      
      IO.puts("\n📊 Memory Usage Analysis:")
      IO.puts("  Users simulated: #{length(users)}")
      IO.puts("  Initial memory: #{format_bytes(initial_memory)}")
      IO.puts("  Peak memory: #{format_bytes(peak_memory)}")
      IO.puts("  Final memory: #{format_bytes(final_memory)}")
      IO.puts("  Memory growth: #{format_bytes(memory_growth)}")
      IO.puts("  Memory per user: #{format_bytes(trunc(memory_per_user))}")
      IO.puts("  Cleanup efficiency: #{:io_lib.format('~.1f', [cleanup_efficiency])}%")
      
      # Memory assertions
      assert memory_per_user < 100_000, "Should use less than 100KB per user"
      assert cleanup_efficiency > 50, "Should clean up at least 50% of allocated memory"
    end
  end
  
  describe "scalability benchmarks" do
    @tag timeout: 120_000
    test "channel server scalability" do
      workspace = insert(:workspace)
      channels = insert_list(20, :channel, workspace: workspace)
      users = insert_list(100, :user)
      
      # Start multiple channel servers
      channel_pids = for channel <- channels do
        {:ok, pid} = ChannelServer.start_link(channel.id)
        {channel, pid}
      end
      
      IO.puts("\n📊 Scalability Test:")
      IO.puts("  Channels: #{length(channels)}")
      IO.puts("  Users: #{length(users)}")
      IO.puts("  Channel servers: #{length(channel_pids)}")
      
      # Distribute users across channels and measure performance
      {time_microseconds, _} = :timer.tc(fn ->
        tasks = for {channel, _pid} <- channel_pids do
          Task.async(fn ->
            # 5 users per channel
            channel_users = Enum.take_random(users, 5)
            
            for user <- channel_users do
              insert(:channel_membership, channel: channel, user: user)
              ChannelServer.join_channel(channel.id, user.id, "socket_#{user.id}")
              
              # Each user sends 10 messages
              for i <- 1..10 do
                ChannelServer.send_message(channel.id, user.id, "Scalability test #{i}", %{})
              end
            end
          end)
        end
        
        Task.await_many(tasks, 120_000)
      end)
      
      time_ms = time_microseconds / 1000
      total_messages = length(channels) * 5 * 10  # channels * users_per_channel * messages_per_user
      messages_per_second = total_messages / (time_microseconds / 1_000_000)
      
      IO.puts("  Total messages sent: #{total_messages}")
      IO.puts("  Total time: #{:io_lib.format('~.2f', [time_ms])} ms")
      IO.puts("  Messages per second: #{:io_lib.format('~.2f', [messages_per_second])}")
      
      # Verify all channel servers are responsive
      for {channel, pid} <- channel_pids do
        assert Process.alive?(pid), "Channel server should still be alive"
        
        state = ChannelServer.get_channel_state(channel.id)
        assert state.stats.connected_users == 5
        assert state.stats.messages_sent == 50
      end
      
      # Performance assertions
      assert messages_per_second >= 10, "Should handle at least 10 messages per second across all channels"
    end
  end
  
  # Helper functions
  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end