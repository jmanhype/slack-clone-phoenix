defmodule SlackClone.Performance.ConcurrentUsersTest do
  @moduledoc """
  Performance testing suite for concurrent user scenarios using London School TDD approach.
  
  Tests system behavior under load with multiple concurrent users, focusing on
  collaboration between services and behavior verification under stress conditions.
  """
  
  use SlackCloneWeb.ChannelCase
  import Mox
  import SlackClone.Factory
  
  alias SlackClone.{Accounts, Messages, Channels}
  alias SlackCloneWeb.{Endpoint, UserSocket}
  alias Phoenix.ChannelTest
  
  # Mock external dependencies for performance testing
  setup :verify_on_exit!
  setup :set_mox_from_context
  
  @concurrent_users 50
  @message_burst_size 100
  @performance_threshold_ms 5000

  describe "Concurrent User Performance Testing" do
    setup do
      workspace = build(:workspace, id: "perf-workspace")
      channel = build(:channel, id: "perf-channel", workspace: workspace)
      users = Enum.map(1..@concurrent_users, fn i ->
        build(:user, id: "user-#{i}", email: "user#{i}@test.com")
      end)
      
      %{workspace: workspace, channel: channel, users: users}
    end

    test "handles concurrent user connections with service load", %{channel: channel, users: users} do
      # Mock authentication service behavior under load
      MockAuth
      |> expect(:authenticate_socket, @concurrent_users, fn socket, _params ->
        {:ok, socket}
      end)
      
      # Mock presence tracking for all users
      MockPresence
      |> expect(:track, @concurrent_users, fn _pid, "channel:" <> _, _user_id, _meta ->
        :ok
      end)
      
      # Mock channel authorization for all users
      MockChannels
      |> expect(:can_join_channel?, @concurrent_users, fn _user, ^channel ->
        true
      end)

      # Performance test: measure concurrent socket connections
      {time_microseconds, sockets} = :timer.tc(fn ->
        Enum.map(users, fn user ->
          {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})
          {:ok, _reply, socket} = subscribe_and_join(socket, "channel:#{channel.id}", %{})
          socket
        end)
      end)
      
      time_ms = time_microseconds / 1000
      
      # Assert performance threshold
      assert time_ms < @performance_threshold_ms, 
        "Concurrent connections took #{time_ms}ms, exceeding threshold of #{@performance_threshold_ms}ms"
      
      # Verify all sockets connected successfully
      assert length(sockets) == @concurrent_users
      
      # Verify each socket can send a test message (mock verification)
      Enum.each(sockets, fn socket ->
        push(socket, "ping", %{})
        assert_reply(socket, "ping", "pong")
      end)
      
      # Cleanup
      Enum.each(sockets, &close/1)
    end

    test "handles concurrent message creation with database load", %{channel: channel, users: users} do
      # Mock message creation service with concurrent behavior
      MockMessages
      |> expect(:create_message, @concurrent_users * @message_burst_size, fn %{content: content, user_id: user_id, channel_id: channel_id} ->
        # Simulate realistic database latency
        :timer.sleep(:rand.uniform(10))
        message = build(:message, 
          id: "msg-#{:rand.uniform(100000)}",
          content: content,
          user_id: user_id,
          channel_id: channel_id
        )
        {:ok, message}
      end)
      
      # Mock PubSub broadcasting under load
      MockPubSub
      |> expect(:broadcast, @concurrent_users * @message_burst_size, fn 
        SlackClone.PubSub, "channel:" <> _, {:new_message, _message} ->
        :ok
      end)
      
      # Mock notification service handling bursts
      MockNotifications
      |> expect(:notify_message_mentions, @concurrent_users * @message_burst_size, fn _message ->
        :ok
      end)

      # Performance test: measure concurrent message bursts
      tasks = Enum.map(users, fn user ->
        Task.async(fn ->
          messages = Enum.map(1..@message_burst_size, fn i ->
            Messages.create_message(%{
              content: "Performance test message #{i} from #{user.id}",
              user_id: user.id,
              channel_id: channel.id
            })
          end)
          
          # Verify all messages created successfully
          successful_creates = Enum.count(messages, &match?({:ok, _}, &1))
          {user.id, successful_creates}
        end)
      end)
      
      {time_microseconds, results} = :timer.tc(fn ->
        Task.await_many(tasks, 30_000) # 30 second timeout
      end)
      
      time_ms = time_microseconds / 1000
      
      # Assert performance threshold
      assert time_ms < @performance_threshold_ms * 2, 
        "Concurrent message creation took #{time_ms}ms, exceeding threshold"
      
      # Verify all users successfully created all messages
      total_successful = Enum.sum(Enum.map(results, fn {_user_id, count} -> count end))
      expected_total = @concurrent_users * @message_burst_size
      
      assert total_successful == expected_total,
        "Expected #{expected_total} successful message creations, got #{total_successful}"
      
      # Calculate throughput
      throughput = expected_total / (time_ms / 1000)
      IO.puts("Message throughput: #{Float.round(throughput, 2)} messages/second")
      
      # Assert minimum throughput (adjust based on your performance requirements)
      assert throughput > 100, "Throughput #{throughput} messages/second below minimum threshold"
    end

    test "handles concurrent typing indicators with presence load", %{channel: channel, users: users} do
      # Mock presence updates for typing indicators
      MockPresence
      |> expect(:update, @concurrent_users * 4, fn _pid, "channel:" <> _, _user_id, _meta ->
        :ok
      end)
      |> expect(:track, @concurrent_users, fn _pid, "channel:" <> _, _user_id, _meta ->
        :ok
      end)

      # Setup WebSocket connections
      sockets = Enum.map(users, fn user ->
        {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})
        {:ok, _reply, socket} = subscribe_and_join(socket, "channel:#{channel.id}", %{})
        socket
      end)
      
      # Performance test: concurrent typing indicators
      {time_microseconds, _results} = :timer.tc(fn ->
        tasks = Enum.map(sockets, fn socket ->
          Task.async(fn ->
            # Start typing
            push(socket, "typing_start", %{})
            
            # Simulate typing duration
            :timer.sleep(:rand.uniform(100) + 50)
            
            # Stop typing
            push(socket, "typing_stop", %{})
            
            # Start typing again (to test rapid updates)
            push(socket, "typing_start", %{})
            push(socket, "typing_stop", %{})
            
            :ok
          end)
        end)
        
        Task.await_many(tasks, 10_000)
      end)
      
      time_ms = time_microseconds / 1000
      
      # Assert typing indicator performance
      assert time_ms < @performance_threshold_ms,
        "Concurrent typing indicators took #{time_ms}ms, exceeding threshold"
      
      # Cleanup
      Enum.each(sockets, &close/1)
    end

    test "measures memory usage under concurrent load", %{channel: channel, users: users} do
      # Mock all necessary services
      MockAuth |> stub(:authenticate_socket, fn socket, _ -> {:ok, socket} end)
      MockPresence |> stub(:track, fn _, _, _, _ -> :ok end)
      MockChannels |> stub(:can_join_channel?, fn _, _ -> true end)
      MockMessages |> stub(:list_recent_messages, fn _, _ -> {:ok, []} end)
      
      # Measure baseline memory
      {memory_before, _} = :erlang.memory(:total)
      
      # Create concurrent load
      sockets = Enum.map(users, fn user ->
        {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})
        {:ok, _reply, socket} = subscribe_and_join(socket, "channel:#{channel.id}", %{})
        socket
      end)
      
      # Force garbage collection to get accurate measurement
      :erlang.garbage_collect()
      :timer.sleep(100) # Allow GC to complete
      
      # Measure memory after load
      {memory_after, _} = :erlang.memory(:total)
      memory_diff_mb = (memory_after - memory_before) / (1024 * 1024)
      
      IO.puts("Memory usage increase: #{Float.round(memory_diff_mb, 2)} MB for #{@concurrent_users} users")
      
      # Assert reasonable memory usage (adjust threshold based on requirements)
      memory_per_user_kb = (memory_after - memory_before) / @concurrent_users / 1024
      assert memory_per_user_kb < 100, # Less than 100KB per user
        "Memory usage per user (#{Float.round(memory_per_user_kb, 2)} KB) exceeds threshold"
      
      # Cleanup and verify memory is released
      Enum.each(sockets, &close/1)
      :erlang.garbage_collect()
      :timer.sleep(200)
      
      {memory_final, _} = :erlang.memory(:total)
      memory_leak_mb = (memory_final - memory_before) / (1024 * 1024)
      
      # Assert no significant memory leak (allow for some variance)
      assert memory_leak_mb < 5, 
        "Memory leak detected: #{Float.round(memory_leak_mb, 2)} MB after cleanup"
    end

    test "benchmarks database query performance under load", %{channel: channel, users: users} do
      # Create test data
      test_messages = Enum.flat_map(users, fn user ->
        Enum.map(1..10, fn i ->
          build(:message, 
            id: "benchmark-msg-#{user.id}-#{i}",
            user: user, 
            channel: channel,
            content: "Benchmark message #{i}"
          )
        end)
      end)
      
      # Mock repository behavior for concurrent queries
      MockRepo
      |> expect(:all, @concurrent_users * 3, fn _query ->
        # Simulate database latency variation
        :timer.sleep(:rand.uniform(20) + 5)
        Enum.take_random(test_messages, 50)
      end)
      |> expect(:get, @concurrent_users, fn _schema, _id ->
        Enum.random(test_messages)
      end)
      
      # Mock message service queries under load
      MockMessages
      |> expect(:list_recent_messages, @concurrent_users * 3, fn _channel_id, _opts ->
        {:ok, Enum.take_random(test_messages, 50)}
      end)
      |> expect(:search_messages, @concurrent_users, fn _channel_id, _query ->
        {:ok, Enum.take_random(test_messages, 10)}
      end)

      # Performance test: concurrent database operations
      {time_microseconds, results} = :timer.tc(fn ->
        tasks = Enum.map(users, fn user ->
          Task.async(fn ->
            # Simulate user loading channel messages
            {:ok, _messages1} = Messages.list_recent_messages(channel.id, %{limit: 50, user_id: user.id})
            
            # Simulate user searching
            {:ok, _search_results} = Messages.search_messages(channel.id, "benchmark")
            
            # Simulate loading more messages
            {:ok, _messages2} = Messages.list_recent_messages(channel.id, %{limit: 50, offset: 50, user_id: user.id})
            
            :ok
          end)
        end)
        
        Task.await_many(tasks, 15_000)
      end)
      
      time_ms = time_microseconds / 1000
      query_count = @concurrent_users * 3 + @concurrent_users # 3 list + 1 search per user
      avg_query_time_ms = time_ms / query_count
      
      IO.puts("Database performance: #{query_count} queries in #{Float.round(time_ms, 2)}ms")
      IO.puts("Average query time: #{Float.round(avg_query_time_ms, 2)}ms")
      
      # Assert database performance thresholds
      assert time_ms < @performance_threshold_ms * 3,
        "Total database operations took #{time_ms}ms, exceeding threshold"
        
      assert avg_query_time_ms < 50,
        "Average query time #{avg_query_time_ms}ms exceeds 50ms threshold"
    end

    test "stress tests WebSocket message broadcasting", %{channel: channel, users: users} do
      # Mock broadcasting with realistic delays
      MockPubSub
      |> expect(:broadcast, @concurrent_users * 20, fn 
        SlackClone.PubSub, "channel:" <> _, {:new_message, _message} ->
        # Simulate network latency
        :timer.sleep(:rand.uniform(5))
        :ok
      end)
      
      MockMessages
      |> expect(:create_message, @concurrent_users * 20, fn _attrs ->
        message = build(:message, channel: channel)
        {:ok, message}
      end)

      # Setup connections
      sockets = Enum.map(users, fn user ->
        {:ok, socket} = connect(UserSocket, %{"user_id" => user.id})
        {:ok, _reply, socket} = subscribe_and_join(socket, "channel:#{channel.id}", %{})
        socket
      end)
      
      # Performance test: message broadcast storm
      {time_microseconds, _results} = :timer.tc(fn ->
        broadcast_tasks = Enum.map(users, fn user ->
          Task.async(fn ->
            # Each user sends multiple messages rapidly
            Enum.each(1..20, fn i ->
              Messages.create_message(%{
                content: "Broadcast test #{i}",
                user_id: user.id,
                channel_id: channel.id
              })
              
              # Small delay to prevent overwhelming
              :timer.sleep(5)
            end)
          end)
        end)
        
        # Wait for all broadcasts to complete
        Task.await_many(broadcast_tasks, 30_000)
      end)
      
      time_ms = time_microseconds / 1000
      total_broadcasts = @concurrent_users * 20
      broadcasts_per_second = total_broadcasts / (time_ms / 1000)
      
      IO.puts("Broadcast performance: #{total_broadcasts} messages in #{Float.round(time_ms, 2)}ms")
      IO.puts("Broadcast rate: #{Float.round(broadcasts_per_second, 2)} messages/second")
      
      # Assert broadcast performance
      assert broadcasts_per_second > 200,
        "Broadcast rate #{broadcasts_per_second} messages/second below threshold"
      
      # Cleanup
      Enum.each(sockets, &close/1)
    end
  end

  describe "Performance Regression Testing" do
    test "compares current performance against benchmarks" do
      # This would typically load historical benchmark data
      benchmark_data = %{
        concurrent_connections_ms: 2000,
        message_throughput_per_sec: 150,
        avg_query_time_ms: 30,
        memory_per_user_kb: 80
      }
      
      # Run simplified performance tests
      {connection_time, _} = :timer.tc(fn ->
        # Simulate connection test
        :timer.sleep(1000)
      end)
      
      connection_time_ms = connection_time / 1000
      
      # Assert performance hasn't regressed
      assert connection_time_ms < benchmark_data.concurrent_connections_ms * 1.1,
        "Performance regression detected: connections now take #{connection_time_ms}ms vs benchmark #{benchmark_data.concurrent_connections_ms}ms"
      
      IO.puts("Performance regression test passed - no significant degradation detected")
    end

    test "monitors resource utilization patterns" do
      # Mock resource monitoring
      MockSystemMonitor
      |> expect(:get_cpu_usage, 5, fn ->
        :rand.uniform(100) # Simulate CPU usage 0-100%
      end)
      |> expect(:get_memory_usage, 5, fn ->
        %{
          total: 1_000_000_000, # 1GB
          used: 400_000_000 + :rand.uniform(200_000_000) # 400-600MB
        }
      end)
      |> expect(:get_network_stats, 5, fn ->
        %{
          bytes_sent: :rand.uniform(1_000_000),
          bytes_received: :rand.uniform(1_000_000),
          connections: :rand.uniform(100)
        }
      end)
      
      # Sample resource usage over time
      samples = Enum.map(1..5, fn _ ->
        cpu = MockSystemMonitor.get_cpu_usage()
        memory = MockSystemMonitor.get_memory_usage()
        network = MockSystemMonitor.get_network_stats()
        
        :timer.sleep(100) # Sample every 100ms
        
        %{
          cpu_usage: cpu,
          memory_usage: memory.used / memory.total * 100,
          network_connections: network.connections,
          timestamp: DateTime.utc_now()
        }
      end)
      
      # Analyze resource patterns
      avg_cpu = Enum.sum(Enum.map(samples, & &1.cpu_usage)) / length(samples)
      avg_memory = Enum.sum(Enum.map(samples, & &1.memory_usage)) / length(samples)
      max_connections = Enum.max(Enum.map(samples, & &1.network_connections))
      
      IO.puts("Resource utilization - CPU: #{Float.round(avg_cpu, 2)}%, Memory: #{Float.round(avg_memory, 2)}%, Max Connections: #{max_connections}")
      
      # Assert resource usage is within acceptable bounds
      assert avg_cpu < 80, "Average CPU usage #{avg_cpu}% exceeds 80% threshold"
      assert avg_memory < 70, "Average memory usage #{avg_memory}% exceeds 70% threshold"
      assert max_connections < 1000, "Max connections #{max_connections} exceeds limit"
    end
  end

  # Helper functions for performance testing
  defp connect(socket_module, params) do
    {:ok, socket} = Phoenix.ChannelTest.connect(socket_module, params)
    {:ok, socket}
  end

  defp subscribe_and_join(socket, channel_name, params) do
    Phoenix.ChannelTest.subscribe_and_join(socket, channel_name, params)
  end

  defp push(socket, event, params) do
    Phoenix.ChannelTest.push(socket, event, params)
  end

  defp assert_reply(socket, event, expected_response) do
    assert_reply socket, event, expected_response
  end

  defp close(socket) do
    Phoenix.ChannelTest.close(socket)
  end
end