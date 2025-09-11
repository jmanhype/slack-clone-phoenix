defmodule SlackCloneWeb.WebSocketPerformanceTest do
  @moduledoc """
  Comprehensive performance testing for WebSocket real-time features.
  Tests throughput, latency, memory usage, and scalability.
  """
  use SlackCloneWeb.ChannelCase, async: false
  
  alias SlackClone.WebSocketTestHelper
  alias SlackCloneWeb.{UserSocket, WorkspaceChannel, ChannelChannel}

  @concurrent_users 50
  @messages_per_user 10
  @test_duration_ms 30_000
  @latency_threshold_ms 100
  @memory_threshold_mb 50

  setup_all do
    # Create multiple test users for performance testing
    users_with_tokens = WebSocketTestHelper.create_test_users_with_tokens(@concurrent_users)
    
    on_exit(fn ->
      WebSocketTestHelper.cleanup_test_data()
    end)
    
    %{users_with_tokens: users_with_tokens}
  end

  describe "WebSocket connection performance" do
    test "concurrent connection establishment", %{users_with_tokens: users_with_tokens} do
      {results, duration_ms} = WebSocketTestHelper.measure_websocket_performance(fn ->
        # Establish concurrent connections
        connections = users_with_tokens
        |> Task.async_stream(fn {user, token} ->
          WebSocketTestHelper.connect_socket(token, user.id)
        end, max_concurrency: @concurrent_users, timeout: 10_000)
        |> Enum.map(fn {:ok, result} -> result end)
        
        connections
      end)
      
      # Verify all connections succeeded
      successful_connections = Enum.count(results, fn
        {:ok, _socket} -> true
        _ -> false
      end)
      
      assert successful_connections == @concurrent_users, 
        "Expected #{@concurrent_users} successful connections, got #{successful_connections}"
      
      # Performance assertions
      avg_connection_time = duration_ms / @concurrent_users
      assert avg_connection_time < 500, 
        "Average connection time too high: #{avg_connection_time}ms per connection"
      
      IO.puts("\n🚀 CONNECTION PERFORMANCE:")
      IO.puts("   ✅ Concurrent Users: #{@concurrent_users}")
      IO.puts("   ✅ Total Time: #{Float.round(duration_ms, 2)}ms")
      IO.puts("   ✅ Avg per Connection: #{Float.round(avg_connection_time, 2)}ms")
      IO.puts("   ✅ Connections/sec: #{Float.round(@concurrent_users / (duration_ms / 1000), 2)}")
    end

    test "connection memory usage", %{users_with_tokens: users_with_tokens} do
      initial_memory = :erlang.memory(:total)
      
      # Establish connections
      connections = Enum.map(users_with_tokens, fn {user, token} ->
        {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
        socket
      end)
      
      :timer.sleep(1000) # Allow memory to stabilize
      final_memory = :erlang.memory(:total)
      
      memory_increase_mb = (final_memory - initial_memory) / (1024 * 1024)
      memory_per_connection_kb = (final_memory - initial_memory) / @concurrent_users / 1024
      
      assert memory_increase_mb < @memory_threshold_mb, 
        "Memory usage too high: #{Float.round(memory_increase_mb, 2)}MB"
      
      IO.puts("\n💾 MEMORY PERFORMANCE:")
      IO.puts("   ✅ Total Memory Increase: #{Float.round(memory_increase_mb, 2)}MB")
      IO.puts("   ✅ Per Connection: #{Float.round(memory_per_connection_kb, 2)}KB")
      IO.puts("   ✅ Connections: #{@concurrent_users}")
      
      # Cleanup connections
      Enum.each(connections, fn socket ->
        close(socket)
      end)
    end
  end

  describe "message throughput performance" do
    test "high-volume message broadcasting", %{users_with_tokens: users_with_tokens} do
      # Take subset for this intensive test
      test_users = Enum.take(users_with_tokens, 10)
      
      # Setup connections and join channels
      {sockets, test_data} = setup_connected_sockets_with_channels(test_users)
      channel_id = test_data.channel.id
      
      # Measure message broadcasting performance
      {_result, duration_ms} = WebSocketTestHelper.measure_websocket_performance(fn ->
        # Send multiple messages from each socket
        test_users
        |> Enum.with_index()
        |> Task.async_stream(fn {{_user, _token}, index} ->
          socket = Enum.at(sockets, index)
          
          # Send messages rapidly
          1..@messages_per_user
          |> Enum.each(fn msg_num ->
            message_payload = %{
              "content" => "Performance test message #{msg_num} from user #{index}",
              "type" => "text"
            }
            push(socket, "new_message", message_payload)
          end)
        end, max_concurrency: 10)
        |> Enum.to_list()
      end)
      
      total_messages = length(test_users) * @messages_per_user
      messages_per_second = total_messages / (duration_ms / 1000)
      
      IO.puts("\n📨 MESSAGE THROUGHPUT:")
      IO.puts("   ✅ Total Messages: #{total_messages}")
      IO.puts("   ✅ Duration: #{Float.round(duration_ms, 2)}ms")
      IO.puts("   ✅ Messages/sec: #{Float.round(messages_per_second, 2)}")
      IO.puts("   ✅ Avg Latency: #{Float.round(duration_ms / total_messages, 2)}ms per message")
      
      # Performance assertions
      assert messages_per_second > 100, 
        "Message throughput too low: #{Float.round(messages_per_second, 2)} msg/sec"
    end

    test "typing indicator performance with debouncing" do
      # Test typing indicators don't overwhelm the system
      {user, token} = WebSocketTestHelper.create_test_user_with_token()
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      test_data = WebSocketTestHelper.create_test_workspace_and_channels(user)
      channel_id = test_data.channel.id
      
      {:ok, _reply, socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          ChannelChannel, 
          "channel:#{channel_id}"
        )
      
      # Rapid typing events (should be debounced)
      {_result, duration_ms} = WebSocketTestHelper.measure_websocket_performance(fn ->
        1..50
        |> Enum.each(fn _i ->
          push(socket, "typing_start", %{})
          :timer.sleep(10) # Rapid typing
        end)
        
        push(socket, "typing_stop", %{})
      end)
      
      IO.puts("\n⌨️  TYPING PERFORMANCE:")
      IO.puts("   ✅ 50 rapid typing events processed in #{Float.round(duration_ms, 2)}ms")
      IO.puts("   ✅ Debouncing should reduce server load")
      
      # Typing should be fast even with debouncing
      assert duration_ms < 2000, "Typing indicator processing too slow: #{duration_ms}ms"
    end
  end

  describe "presence tracking performance" do
    test "large workspace presence updates" do
      # Create larger group for presence testing
      test_users = Enum.take(users_with_tokens, 20)
      
      # Setup connections to workspace
      {sockets, test_data} = setup_connected_sockets_with_workspace(test_users)
      workspace_id = test_data.workspace.id
      
      # Measure presence update performance
      {_result, duration_ms} = WebSocketTestHelper.measure_websocket_performance(fn ->
        # Simultaneous presence updates
        sockets
        |> Task.async_stream(fn socket ->
          push(socket, "update_presence", %{"status" => "active", "activity" => "coding"})
        end, max_concurrency: 20)
        |> Enum.to_list()
      end)
      
      presence_updates_per_second = length(test_users) / (duration_ms / 1000)
      
      IO.puts("\n👥 PRESENCE PERFORMANCE:")
      IO.puts("   ✅ Users: #{length(test_users)}")
      IO.puts("   ✅ Duration: #{Float.round(duration_ms, 2)}ms")
      IO.puts("   ✅ Updates/sec: #{Float.round(presence_updates_per_second, 2)}")
      
      assert presence_updates_per_second > 10, 
        "Presence updates too slow: #{Float.round(presence_updates_per_second, 2)} updates/sec"
    end
  end

  describe "authentication performance" do
    test "JWT verification performance under load" do
      # Create many tokens for testing
      tokens = 1..100
      |> Enum.map(fn _i ->
        {_user, token} = WebSocketTestHelper.create_test_user_with_token()
        token
      end)
      
      # Measure JWT verification performance
      {results, duration_ms} = WebSocketTestHelper.measure_websocket_performance(fn ->
        tokens
        |> Task.async_stream(fn token ->
          WebSocketTestHelper.connect_socket(token)
        end, max_concurrency: 50, timeout: 10_000)
        |> Enum.map(fn {:ok, result} -> result end)
      end)
      
      successful_auths = Enum.count(results, fn
        {:ok, _socket} -> true
        _ -> false
      end)
      
      auths_per_second = successful_auths / (duration_ms / 1000)
      avg_auth_time = duration_ms / successful_auths
      
      IO.puts("\n🔐 AUTHENTICATION PERFORMANCE:")
      IO.puts("   ✅ Successful Auths: #{successful_auths}/#{length(tokens)}")
      IO.puts("   ✅ Auths/sec: #{Float.round(auths_per_second, 2)}")
      IO.puts("   ✅ Avg Auth Time: #{Float.round(avg_auth_time, 2)}ms")
      
      assert auths_per_second > 50, 
        "Authentication too slow: #{Float.round(auths_per_second, 2)} auths/sec"
      assert avg_auth_time < 100, 
        "Average auth time too high: #{Float.round(avg_auth_time, 2)}ms"
    end
  end

  describe "error handling and recovery" do
    test "graceful handling of connection spikes" do
      # Simulate connection spike
      spike_size = 100
      
      {results, duration_ms} = WebSocketTestHelper.measure_websocket_performance(fn ->
        1..spike_size
        |> Task.async_stream(fn _i ->
          {user, token} = WebSocketTestHelper.create_test_user_with_token()
          result = WebSocketTestHelper.connect_socket(token, user.id)
          
          # Immediately disconnect to test cleanup
          case result do
            {:ok, socket} -> close(socket)
            error -> error
          end
          
          result
        end, max_concurrency: spike_size, timeout: 15_000)
        |> Enum.map(fn {:ok, result} -> result end)
      end)
      
      successful_connections = Enum.count(results, fn
        {:ok, _socket} -> true
        _ -> false
      end)
      
      success_rate = successful_connections / spike_size * 100
      
      IO.puts("\n⚡ SPIKE HANDLING:")
      IO.puts("   ✅ Spike Size: #{spike_size} connections")
      IO.puts("   ✅ Success Rate: #{Float.round(success_rate, 1)}%")
      IO.puts("   ✅ Duration: #{Float.round(duration_ms, 2)}ms")
      
      # Should handle at least 80% of spike successfully
      assert success_rate > 80, 
        "Connection spike handling poor: #{Float.round(success_rate, 1)}% success rate"
    end

    test "memory cleanup after mass disconnections" do
      initial_memory = :erlang.memory(:total)
      
      # Create and immediately destroy many connections
      connections = 1..50
      |> Enum.map(fn _i ->
        {user, token} = WebSocketTestHelper.create_test_user_with_token()
        {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
        socket
      end)
      
      peak_memory = :erlang.memory(:total)
      
      # Close all connections
      Enum.each(connections, fn socket ->
        close(socket)
      end)
      
      # Allow cleanup time
      :timer.sleep(2000)
      :erlang.garbage_collect()
      
      final_memory = :erlang.memory(:total)
      
      memory_recovered_mb = (peak_memory - final_memory) / (1024 * 1024)
      memory_leak_mb = (final_memory - initial_memory) / (1024 * 1024)
      
      IO.puts("\n🧹 MEMORY CLEANUP:")
      IO.puts("   ✅ Memory Recovered: #{Float.round(memory_recovered_mb, 2)}MB")
      IO.puts("   ✅ Potential Leak: #{Float.round(memory_leak_mb, 2)}MB")
      
      # Should recover most memory and have minimal leaks
      assert memory_leak_mb < 10, 
        "Potential memory leak: #{Float.round(memory_leak_mb, 2)}MB after cleanup"
    end
  end

  # Helper functions
  defp setup_connected_sockets_with_channels(users_with_tokens) do
    [{first_user, _} | _] = users_with_tokens
    test_data = WebSocketTestHelper.create_test_workspace_and_channels(first_user)
    
    sockets = Enum.map(users_with_tokens, fn {user, token} ->
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      {:ok, _reply, socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          ChannelChannel, 
          "channel:#{test_data.channel.id}"
        )
      
      socket
    end)
    
    {sockets, test_data}
  end
  
  defp setup_connected_sockets_with_workspace(users_with_tokens) do
    [{first_user, _} | _] = users_with_tokens
    test_data = WebSocketTestHelper.create_test_workspace_and_channels(first_user)
    
    sockets = Enum.map(users_with_tokens, fn {user, token} ->
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      {:ok, _reply, socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          WorkspaceChannel, 
          "workspace:#{test_data.workspace.id}"
        )
      
      socket
    end)
    
    {sockets, test_data}
  end
end
