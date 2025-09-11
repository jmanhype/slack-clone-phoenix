defmodule SlackCloneWeb.Performance.WorkspacePerformanceTest do
  @moduledoc """
  Performance and load testing for workspace and channel operations.
  Tests response times, throughput, and system behavior under load.
  """
  use SlackCloneWeb.ConnCase, async: false  # Not async due to performance measurements
  use SlackClone.Factory

  alias SlackClone.{Workspaces, Channels, Messages}
  alias SlackClone.Guardian

  @moduletag :performance

  describe "Workspace API performance" do
    setup :setup_authenticated_user

    test "workspace creation performance under load", %{conn: conn} do
      # Measure time for sequential workspace creation
      {time_sequential, _} = :timer.tc(fn ->
        for i <- 1..10 do
          workspace_attrs = %{name: "Sequential #{i}", description: "Test workspace #{i}"}
          response = post(conn, ~p"/api/workspaces", workspace: workspace_attrs)
          assert response.status == 201
        end
      end)
      
      # Measure time for concurrent workspace creation
      {time_concurrent, _} = :timer.tc(fn ->
        1..10
        |> Enum.map(fn i ->
          Task.async(fn ->
            workspace_attrs = %{name: "Concurrent #{i}", description: "Test workspace #{i}"}
            post(conn, ~p"/api/workspaces", workspace: workspace_attrs)
          end)
        end)
        |> Enum.map(&Task.await(&1, 10000))
        |> Enum.each(&(assert &1.status == 201))
      end)
      
      sequential_ms = time_sequential / 1000
      concurrent_ms = time_concurrent / 1000
      
      IO.puts("Sequential workspace creation: #{sequential_ms}ms (#{sequential_ms/10}ms per workspace)")
      IO.puts("Concurrent workspace creation: #{concurrent_ms}ms (#{concurrent_ms/10}ms per workspace)")
      
      # Concurrent should be significantly faster
      assert concurrent_ms < sequential_ms * 0.8
      
      # Each workspace creation should be under 500ms
      assert sequential_ms / 10 < 500
      assert concurrent_ms / 10 < 500
    end

    test "workspace listing performance with large datasets", %{conn: conn, user: user} do
      # Create workspaces with varying amounts of data
      workspaces = for i <- 1..20 do
        workspace = insert(:workspace, owner: user, name: "Performance Workspace #{i}")
        
        # Add channels to each workspace
        channels = for j <- 1..5 do
          insert(:channel, workspace: workspace, name: "channel-#{j}")
        end
        
        # Add messages to channels
        for channel <- channels do
          for k <- 1..10 do
            insert(:message, channel: channel, user: user, content: "Message #{k}")
          end
        end
        
        workspace
      end
      
      # Measure workspace listing performance
      {time_list, response} = :timer.tc(fn ->
        get(conn, ~p"/api/workspaces")
      end)
      
      list_ms = time_list / 1000
      response_data = json_response(response, 200)["data"]
      
      IO.puts("Workspace listing with 20 workspaces: #{list_ms}ms")
      
      # Should return all workspaces
      assert length(response_data) == 20
      
      # Should complete under 1 second
      assert list_ms < 1000
      
      # Test individual workspace loading performance
      sample_workspace = List.first(workspaces)
      
      {time_show, show_response} = :timer.tc(fn ->
        get(conn, ~p"/api/workspaces/#{sample_workspace.id}")
      end)
      
      show_ms = time_show / 1000
      show_data = json_response(show_response, 200)["data"]
      
      IO.puts("Individual workspace loading: #{show_ms}ms")
      
      # Should include channel data
      assert length(show_data["channels"]) == 5
      
      # Should complete under 200ms
      assert show_ms < 200
    end

    test "workspace update performance", %{conn: conn, user: user} do
      workspace = insert(:workspace, owner: user)
      
      # Measure single update
      {time_single, _} = :timer.tc(fn ->
        update_attrs = %{description: "Updated description"}
        response = put(conn, ~p"/api/workspaces/#{workspace.id}", workspace: update_attrs)
        assert response.status == 200
      end)
      
      single_ms = time_single / 1000
      IO.puts("Single workspace update: #{single_ms}ms")
      
      # Should complete under 100ms
      assert single_ms < 100
      
      # Test concurrent updates (should be serialized properly)
      {time_concurrent, results} = :timer.tc(fn ->
        1..5
        |> Enum.map(fn i ->
          Task.async(fn ->
            update_attrs = %{description: "Concurrent update #{i}"}
            put(conn, ~p"/api/workspaces/#{workspace.id}", workspace: update_attrs)
          end)
        end)
        |> Enum.map(&Task.await(&1, 5000))
      end)
      
      concurrent_ms = time_concurrent / 1000
      successful_updates = Enum.count(results, &(&1.status == 200))
      
      IO.puts("Concurrent workspace updates: #{concurrent_ms}ms")
      
      # All updates should succeed
      assert successful_updates == 5
      
      # Should complete under 500ms total
      assert concurrent_ms < 500
    end
  end

  describe "Channel API performance" do
    setup :setup_authenticated_workspace

    test "channel creation performance", %{conn: conn, workspace: workspace} do
      # Measure bulk channel creation
      {time_bulk, _} = :timer.tc(fn ->
        for i <- 1..20 do
          channel_attrs = %{name: "perf-channel-#{i}", description: "Performance test channel #{i}"}
          response = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
          assert response.status == 201
        end
      end)
      
      bulk_ms = time_bulk / 1000
      IO.puts("Bulk channel creation (20 channels): #{bulk_ms}ms (#{bulk_ms/20}ms per channel)")
      
      # Average per channel should be under 100ms
      assert bulk_ms / 20 < 100
      
      # Test concurrent channel creation
      {time_concurrent, results} = :timer.tc(fn ->
        21..30
        |> Enum.map(fn i ->
          Task.async(fn ->
            channel_attrs = %{name: "concurrent-#{i}", description: "Concurrent channel #{i}"}
            post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
          end)
        end)
        |> Enum.map(&Task.await(&1, 5000))
      end)
      
      concurrent_ms = time_concurrent / 1000
      successful_creates = Enum.count(results, &(&1.status == 201))
      
      IO.puts("Concurrent channel creation (10 channels): #{concurrent_ms}ms")
      
      # All should succeed
      assert successful_creates == 10
      
      # Should be faster than sequential
      assert concurrent_ms < (bulk_ms / 20) * 10
    end

    test "channel listing performance with large datasets", %{conn: conn, workspace: workspace, user: user} do
      # Create many channels with messages
      channels = for i <- 1..50 do
        channel = insert(:channel, workspace: workspace, name: "list-perf-#{i}")
        
        # Add messages to some channels
        if rem(i, 5) == 0 do
          for j <- 1..20 do
            insert(:message, channel: channel, user: user, content: "Message #{j}")
          end
        end
        
        channel
      end
      
      # Measure channel listing
      {time_list, response} = :timer.tc(fn ->
        get(conn, ~p"/api/workspaces/#{workspace.id}/channels")
      end)
      
      list_ms = time_list / 1000
      response_data = json_response(response, 200)["data"]
      
      IO.puts("Channel listing (50 channels): #{list_ms}ms")
      
      # Should return all channels
      assert length(response_data) >= 50
      
      # Should complete under 300ms
      assert list_ms < 300
      
      # Each channel should include metadata
      sample_channel = List.first(response_data)
      assert Map.has_key?(sample_channel, "member_count")
      assert Map.has_key?(sample_channel, "is_private")
    end

    test "channel search and filtering performance", %{conn: conn, workspace: workspace, user: user} do
      # Create channels with different characteristics
      for i <- 1..30 do
        channel_name = if rem(i, 3) == 0, do: "special-#{i}", else: "regular-#{i}"
        is_private = rem(i, 7) == 0
        
        channel = insert(:channel, 
          workspace: workspace, 
          name: channel_name,
          is_private: is_private,
          description: "Channel #{i} description"
        )
        
        if is_private do
          insert(:channel_membership, channel: channel, user: user)
        end
      end
      
      # Test filtered listing performance
      {time_filter, response} = :timer.tc(fn ->
        get(conn, ~p"/api/workspaces/#{workspace.id}/channels?search=special")
      end)
      
      filter_ms = time_filter / 1000
      filtered_data = json_response(response, 200)["data"]
      
      IO.puts("Channel filtering: #{filter_ms}ms")
      
      # Should return only matching channels
      assert length(filtered_data) == 10  # Every 3rd channel
      
      # Should complete under 150ms
      assert filter_ms < 150
      
      # Verify all results match filter
      Enum.each(filtered_data, fn channel ->
        assert channel["name"] =~ "special"
      end)
    end
  end

  describe "Message API performance" do
    setup :setup_authenticated_channel

    test "message posting performance under high load", %{conn: conn, workspace: workspace, channel: channel} do
      # Test sequential message posting
      {time_sequential, _} = :timer.tc(fn ->
        for i <- 1..50 do
          message_attrs = %{content: "Sequential message #{i}", type: "text"}
          response = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", 
                         message: message_attrs)
          assert response.status == 201
        end
      end)
      
      sequential_ms = time_sequential / 1000
      IO.puts("Sequential message posting (50 messages): #{sequential_ms}ms (#{sequential_ms/50}ms per message)")
      
      # Test concurrent message posting
      {time_concurrent, results} = :timer.tc(fn ->
        51..100
        |> Enum.map(fn i ->
          Task.async(fn ->
            message_attrs = %{content: "Concurrent message #{i}", type: "text"}
            post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", 
                 message: message_attrs)
          end)
        end)
        |> Enum.map(&Task.await(&1, 10000))
      end)
      
      concurrent_ms = time_concurrent / 1000
      successful_posts = Enum.count(results, &(&1.status == 201))
      
      IO.puts("Concurrent message posting (50 messages): #{concurrent_ms}ms")
      
      # All should succeed
      assert successful_posts == 50
      
      # Concurrent should be significantly faster
      assert concurrent_ms < sequential_ms * 0.7
      
      # Average per message should be under 50ms
      assert sequential_ms / 50 < 50
    end

    test "message retrieval performance with large datasets", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      # Create large number of messages
      messages = for i <- 1..1000 do
        insert(:message, 
          channel: channel, 
          user: user, 
          content: "Performance test message #{i}",
          inserted_at: DateTime.add(DateTime.utc_now(), -i, :second)
        )
      end
      
      # Test message retrieval with different limits
      test_cases = [
        {10, "small"},
        {50, "medium"}, 
        {100, "large"},
        {500, "extra_large"}
      ]
      
      for {limit, size_name} <- test_cases do
        {time_retrieve, response} = :timer.tc(fn ->
          get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?limit=#{limit}")
        end)
        
        retrieve_ms = time_retrieve / 1000
        response_data = json_response(response, 200)["data"]
        
        IO.puts("Message retrieval #{size_name} (#{limit} messages): #{retrieve_ms}ms")
        
        # Should return requested number of messages
        assert length(response_data) == limit
        
        # Should complete under reasonable time based on size
        max_time = case size_name do
          "small" -> 50
          "medium" -> 100
          "large" -> 200
          "extra_large" -> 500
        end
        
        assert retrieve_ms < max_time
        
        # Messages should be in chronological order
        contents = Enum.map(response_data, & &1["content"])
        first_content = List.first(contents)
        last_content = List.last(contents)
        
        # Due to reverse chronological insert, first should have higher number
        assert first_content =~ "message #{1000 - limit + 1}"
        assert last_content =~ "message 1000"
      end
    end

    test "message search performance", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      # Create messages with searchable content
      search_terms = ["urgent", "meeting", "deadline", "project", "review"]
      
      for i <- 1..200 do
        term = Enum.random(search_terms)
        content = "Message #{i} contains #{term} keyword for testing"
        insert(:message, channel: channel, user: user, content: content)
      end
      
      # Test search performance for different terms
      for term <- search_terms do
        {time_search, response} = :timer.tc(fn ->
          get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?search=#{term}")
        end)
        
        search_ms = time_search / 1000
        results = json_response(response, 200)["data"]
        
        IO.puts("Message search for '#{term}': #{search_ms}ms (#{length(results)} results)")
        
        # Should complete under 200ms
        assert search_ms < 200
        
        # All results should contain the search term
        Enum.each(results, fn message ->
          assert message["content"] =~ term
        end)
        
        # Should have reasonable number of results (around 40 per term)
        assert length(results) >= 30
        assert length(results) <= 50
      end
    end

    test "message pagination performance", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      # Create messages for pagination testing
      for i <- 1..500 do
        insert(:message, 
          channel: channel, 
          user: user, 
          content: "Pagination test message #{i}",
          inserted_at: DateTime.add(DateTime.utc_now(), -i, :second)
        )
      end
      
      # Test pagination through all messages
      page_size = 50
      total_pages = div(500, page_size)
      page_times = []
      
      cursor = nil
      
      for page <- 1..total_pages do
        url = if cursor do
          ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?limit=#{page_size}&cursor=#{cursor}"
        else
          ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?limit=#{page_size}"
        end
        
        {time_page, response} = :timer.tc(fn ->
          get(conn, url)
        end)
        
        page_ms = time_page / 1000
        page_times = [page_ms | page_times]
        
        response_data = json_response(response, 200)
        messages = response_data["data"]
        pagination = response_data["pagination"]
        
        IO.puts("Pagination page #{page}: #{page_ms}ms (#{length(messages)} messages)")
        
        # Should return full page (except possibly last page)
        expected_count = if page == total_pages, do: 0, else: page_size
        assert length(messages) == expected_count || length(messages) == page_size
        
        # Should complete under 100ms per page
        assert page_ms < 100
        
        # Get cursor for next page
        cursor = pagination["next_cursor"]
        
        # Last page should not have next cursor
        if page == total_pages do
          assert cursor == nil
        end
      end
      
      avg_page_time = Enum.sum(page_times) / length(page_times)
      IO.puts("Average pagination time: #{avg_page_time}ms")
      
      # Average should be under 75ms
      assert avg_page_time < 75
    end
  end

  describe "Real-time performance simulation" do
    setup :setup_authenticated_channel

    test "simulates high-frequency message posting", %{conn: conn, workspace: workspace, channel: channel} do
      # Simulate real-time chat scenario with multiple users
      users = for i <- 1..5 do
        user = insert(:user, username: "user#{i}")
        insert(:channel_membership, channel: channel, user: user)
        {:ok, token, _} = Guardian.encode_and_sign(user)
        
        user_conn = 
          build_conn()
          |> put_req_header("accept", "application/json")
          |> put_req_header("authorization", "Bearer #{token}")
        
        {user, user_conn}
      end
      
      # Each user posts messages rapidly
      {total_time, _} = :timer.tc(fn ->
        tasks = 
          users
          |> Enum.with_index()
          |> Enum.flat_map(fn {{user, user_conn}, user_index} ->
            1..10
            |> Enum.map(fn msg_index ->
              Task.async(fn ->
                # Stagger messages slightly to simulate real typing
                Process.sleep(user_index * 10 + msg_index * 5)
                
                message_attrs = %{
                  content: "Real-time message #{msg_index} from #{user.username}",
                  type: "text"
                }
                
                post(user_conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", 
                     message: message_attrs)
              end)
            end)
          end)
        
        # Wait for all messages to be posted
        Enum.map(tasks, &Task.await(&1, 15000))
      end)
      
      total_ms = total_time / 1000
      IO.puts("High-frequency posting simulation (50 messages, 5 users): #{total_ms}ms")
      
      # Should complete under 5 seconds
      assert total_ms < 5000
      
      # Verify all messages were created
      response = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?limit=100")
      messages = json_response(response, 200)["data"]
      
      assert length(messages) >= 50
      
      # Verify message ordering is maintained
      timestamps = Enum.map(messages, fn msg ->
        {:ok, dt, _} = DateTime.from_iso8601(msg["inserted_at"])
        dt
      end)
      
      # Should be in chronological order
      sorted_timestamps = Enum.sort(timestamps, DateTime)
      assert timestamps == sorted_timestamps
    end

    test "measures system performance under sustained load", %{conn: conn, workspace: workspace, channel: channel, user: user} do
      # Create baseline load of existing messages
      for i <- 1..100 do
        insert(:message, channel: channel, user: user, content: "Baseline message #{i}")
      end
      
      # Measure system performance during sustained operations
      operations = [
        {:post_message, fn ->
          attrs = %{content: "Load test message #{:rand.uniform(1000)}", type: "text"}
          post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages", message: attrs)
        end},
        {:get_messages, fn ->
          get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}/messages?limit=20")
        end},
        {:get_channel, fn ->
          get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel.id}")
        end},
        {:get_workspace, fn ->
          get(conn, ~p"/api/workspaces/#{workspace.id}")
        end}
      ]
      
      # Run mixed operations concurrently
      {load_time, results} = :timer.tc(fn ->
        1..100
        |> Enum.map(fn _i ->
          {op_name, op_func} = Enum.random(operations)
          
          Task.async(fn ->
            {time, response} = :timer.tc(op_func)
            {op_name, time / 1000, response.status}
          end)
        end)
        |> Enum.map(&Task.await(&1, 10000))
      end)
      
      load_ms = load_time / 1000
      IO.puts("Sustained load test (100 mixed operations): #{load_ms}ms")
      
      # Analyze results by operation type
      operation_stats = 
        results
        |> Enum.group_by(fn {op_name, _time, _status} -> op_name end)
        |> Enum.map(fn {op_name, ops} ->
          times = Enum.map(ops, fn {_, time, _} -> time end)
          statuses = Enum.map(ops, fn {_, _, status} -> status end)
          
          avg_time = Enum.sum(times) / length(times)
          success_rate = Enum.count(statuses, &(&1 in [200, 201])) / length(statuses)
          
          {op_name, avg_time, success_rate, length(ops)}
        end)
      
      IO.puts("\nOperation Statistics:")
      for {op_name, avg_time, success_rate, count} <- operation_stats do
        IO.puts("  #{op_name}: #{avg_time}ms avg, #{success_rate * 100}% success, #{count} ops")
        
        # All operations should have high success rates
        assert success_rate >= 0.95
        
        # Average times should be reasonable
        max_time = case op_name do
          :post_message -> 100
          :get_messages -> 150
          :get_channel -> 75
          :get_workspace -> 100
        end
        
        assert avg_time < max_time
      end
      
      # Overall load test should complete in reasonable time
      assert load_ms < 15000  # 15 seconds for 100 operations
    end
  end

  # Test helper functions
  defp setup_authenticated_user(_context) do
    user = insert(:user)
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    
    conn = 
      build_conn()
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")
    
    %{conn: conn, user: user, token: token}
  end

  defp setup_authenticated_workspace(_context) do
    user = insert(:user)
    workspace = insert(:workspace, owner: user)
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    
    conn = 
      build_conn()
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")
    
    %{conn: conn, user: user, workspace: workspace, token: token}
  end

  defp setup_authenticated_channel(_context) do
    user = insert(:user)
    workspace = insert(:workspace, owner: user)
    channel = insert(:channel, workspace: workspace, is_private: false)
    
    # Add user to channel
    insert(:channel_membership, channel: channel, user: user, role: "member")
    
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    
    conn = 
      build_conn()
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")
    
    %{conn: conn, user: user, workspace: workspace, channel: channel, token: token}
  end
end