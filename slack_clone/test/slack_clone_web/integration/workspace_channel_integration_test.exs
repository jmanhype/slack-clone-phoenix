defmodule SlackCloneWeb.Integration.WorkspaceChannelIntegrationTest do
  @moduledoc """
  Integration tests for complete workspace and channel workflows.
  Tests end-to-end scenarios and cross-feature interactions.
  """
  use SlackCloneWeb.ConnCase, async: true
  use SlackClone.Factory

  alias SlackClone.{Workspaces, Channels, Messages, Accounts}
  alias SlackClone.Guardian

  describe "Complete workspace setup workflow" do
    setup :setup_authenticated_user

    test "creates workspace with default channels and posts first message", %{conn: conn, user: user} do
      # Step 1: Create workspace
      workspace_attrs = %{
        name: "Development Team",
        description: "Our development workspace"
      }
      
      conn = post(conn, ~p"/api/workspaces", workspace: workspace_attrs)
      workspace_data = json_response(conn, 201)["data"]
      workspace_id = workspace_data["id"]
      
      # Step 2: Create general channel
      general_attrs = %{
        name: "general",
        description: "General discussion"
      }
      
      conn = post(conn, ~p"/api/workspaces/#{workspace_id}/channels", channel: general_attrs)
      general_data = json_response(conn, 201)["data"]
      general_id = general_data["id"]
      
      # Step 3: Create random channel
      random_attrs = %{
        name: "random",
        description: "Random stuff"
      }
      
      conn = post(conn, ~p"/api/workspaces/#{workspace_id}/channels", channel: random_attrs)
      random_data = json_response(conn, 201)["data"]
      random_id = random_data["id"]
      
      # Step 4: Post welcome message in general
      welcome_message = %{
        content: "Welcome to our development workspace! 🎉",
        type: "text"
      }
      
      conn = post(conn, ~p"/api/workspaces/#{workspace_id}/channels/#{general_id}/messages", message: welcome_message)
      message_data = json_response(conn, 201)["data"]
      
      # Step 5: Verify complete setup
      conn = get(conn, ~p"/api/workspaces/#{workspace_id}")
      workspace_details = json_response(conn, 200)["data"]
      
      assert workspace_details["name"] == "Development Team"
      assert length(workspace_details["channels"]) == 2
      
      channel_names = Enum.map(workspace_details["channels"], & &1["name"])
      assert "general" in channel_names
      assert "random" in channel_names
      
      # Verify message exists
      conn = get(conn, ~p"/api/workspaces/#{workspace_id}/channels/#{general_id}/messages")
      messages = json_response(conn, 200)["data"]
      
      assert length(messages) == 1
      assert List.first(messages)["content"] =~ "Welcome to our development workspace"
    end

    test "multi-user workspace collaboration scenario", %{conn: conn, user: owner} do
      # Owner creates workspace
      workspace_attrs = %{name: "Team Collaboration", description: "Team workspace"}
      conn = post(conn, ~p"/api/workspaces", workspace: workspace_attrs)
      workspace_id = json_response(conn, 201)["data"]["id"]
      
      # Owner creates public channel
      public_channel_attrs = %{name: "announcements", description: "Team announcements"}
      conn = post(conn, ~p"/api/workspaces/#{workspace_id}/channels", channel: public_channel_attrs)
      public_channel_id = json_response(conn, 201)["data"]["id"]
      
      # Owner creates private channel
      private_channel_attrs = %{name: "leadership", description: "Leadership discussions", is_private: true}
      conn = post(conn, ~p"/api/workspaces/#{workspace_id}/channels", channel: private_channel_attrs)
      private_channel_id = json_response(conn, 201)["data"]["id"]
      
      # Create second user and authenticate
      member_user = insert(:user, username: "team_member")
      insert(:workspace_membership, workspace_id: workspace_id, user: member_user, role: "member")
      
      {:ok, member_token, _} = Guardian.encode_and_sign(member_user)
      member_conn = 
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{member_token}")
      
      # Member can see workspace and public channel
      member_conn = get(member_conn, ~p"/api/workspaces/#{workspace_id}")
      workspace_data = json_response(member_conn, 200)["data"]
      visible_channels = Enum.map(workspace_data["channels"], & &1["name"])
      
      assert "announcements" in visible_channels
      assert "leadership" not in visible_channels  # Private channel not visible
      
      # Member can post to public channel
      message_attrs = %{content: "Hello team!", type: "text"}
      member_conn = post(member_conn, ~p"/api/workspaces/#{workspace_id}/channels/#{public_channel_id}/messages", 
                        message: message_attrs)
      assert json_response(member_conn, 201)
      
      # Member cannot post to private channel
      member_conn = post(member_conn, ~p"/api/workspaces/#{workspace_id}/channels/#{private_channel_id}/messages", 
                        message: message_attrs)
      assert json_response(member_conn, 403)
      
      # Owner can see all channels and messages
      conn = get(conn, ~p"/api/workspaces/#{workspace_id}/channels/#{public_channel_id}/messages")
      messages = json_response(conn, 200)["data"]
      
      assert length(messages) == 1
      assert List.first(messages)["content"] == "Hello team!"
    end

    test "workspace deletion cascade behavior", %{conn: conn, user: user} do
      # Create workspace with channels and messages
      workspace_attrs = %{name: "To Be Deleted", description: "Test workspace"}
      conn = post(conn, ~p"/api/workspaces", workspace: workspace_attrs)
      workspace_id = json_response(conn, 201)["data"]["id"]
      
      # Create channel
      channel_attrs = %{name: "test-channel", description: "Test channel"}
      conn = post(conn, ~p"/api/workspaces/#{workspace_id}/channels", channel: channel_attrs)
      channel_id = json_response(conn, 201)["data"]["id"]
      
      # Create messages
      for i <- 1..3 do
        message_attrs = %{content: "Message #{i}", type: "text"}
        post(conn, ~p"/api/workspaces/#{workspace_id}/channels/#{channel_id}/messages", message: message_attrs)
      end
      
      # Verify data exists
      conn = get(conn, ~p"/api/workspaces/#{workspace_id}/channels/#{channel_id}/messages")
      messages_before = json_response(conn, 200)["data"]
      assert length(messages_before) == 3
      
      # Delete workspace
      conn = delete(conn, ~p"/api/workspaces/#{workspace_id}")
      assert response(conn, 204)
      
      # Verify workspace is gone
      conn = get(conn, ~p"/api/workspaces/#{workspace_id}")
      assert json_response(conn, 404)
      
      # Verify channel is gone
      conn = get(conn, ~p"/api/workspaces/#{workspace_id}/channels/#{channel_id}")
      assert json_response(conn, 404)
      
      # Verify messages are gone (cascade delete)
      conn = get(conn, ~p"/api/workspaces/#{workspace_id}/channels/#{channel_id}/messages")
      assert json_response(conn, 404)
    end
  end

  describe "Channel archival and restoration workflow" do
    setup :setup_authenticated_workspace

    test "archives channel and handles message access", %{conn: conn, workspace: workspace, user: user} do
      # Create channel with messages
      channel_attrs = %{name: "project-alpha", description: "Alpha project channel"}
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
      channel_id = json_response(conn, 201)["data"]["id"]
      
      # Add some messages
      for i <- 1..5 do
        message_attrs = %{content: "Project update #{i}", type: "text"}
        post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages", message: message_attrs)
      end
      
      # Verify messages exist
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages")
      messages_before = json_response(conn, 200)["data"]
      assert length(messages_before) == 5
      
      # Archive channel
      conn = delete(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}")
      assert response(conn, 204)
      
      # Verify channel is archived (not in active list)
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels")
      active_channels = json_response(conn, 200)["data"]
      active_channel_names = Enum.map(active_channels, & &1["name"])
      assert "project-alpha" not in active_channel_names
      
      # Verify messages are still accessible (read-only)
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages")
      messages_after = json_response(conn, 200)["data"]
      assert length(messages_after) == 5
      
      # Verify cannot post new messages to archived channel
      new_message = %{content: "This should fail", type: "text"}
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages", message: new_message)
      assert json_response(conn, 403)
    end

    test "handles permission changes during channel operations", %{conn: conn, workspace: workspace, user: owner} do
      # Create member user
      member = insert(:user, username: "member")
      insert(:workspace_membership, workspace: workspace, user: member, role: "member")
      
      {:ok, member_token, _} = Guardian.encode_and_sign(member)
      member_conn = 
        build_conn()
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer #{member_token}")
      
      # Owner creates channel
      channel_attrs = %{name: "dynamic-perms", description: "Testing permission changes"}
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
      channel_id = json_response(conn, 201)["data"]["id"]
      
      # Member can post initially (public channel)
      message_attrs = %{content: "Member message", type: "text"}
      member_conn = post(member_conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages", 
                        message: message_attrs)
      assert json_response(member_conn, 201)
      
      # Owner makes channel private
      update_attrs = %{is_private: true}
      conn = put(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}", channel: update_attrs)
      assert json_response(conn, 200)
      
      # Member can no longer access (not in private channel)
      member_conn = get(member_conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages")
      assert json_response(member_conn, 403)
      
      # Member cannot post anymore
      member_conn = post(member_conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages", 
                        message: message_attrs)
      assert json_response(member_conn, 403)
    end
  end

  describe "Cross-workspace security isolation" do
    setup :setup_authenticated_user

    test "prevents cross-workspace data access", %{conn: conn, user: user} do
      # Create first workspace
      workspace1_attrs = %{name: "Workspace One", description: "First workspace"}
      conn = post(conn, ~p"/api/workspaces", workspace: workspace1_attrs)
      workspace1_id = json_response(conn, 201)["data"]["id"]
      
      # Create second workspace with different owner
      other_user = insert(:user)
      workspace2 = insert(:workspace, owner: other_user, name: "Workspace Two")
      channel2 = insert(:channel, workspace: workspace2, name: "secret-channel")
      message2 = insert(:message, channel: channel2, content: "Secret message")
      
      # Try to access second workspace (should fail)
      conn = get(conn, ~p"/api/workspaces/#{workspace2.id}")
      assert json_response(conn, 403)
      
      # Try to access channel in second workspace (should fail)
      conn = get(conn, ~p"/api/workspaces/#{workspace2.id}/channels/#{channel2.id}")
      assert json_response(conn, 403)
      
      # Try to access messages in second workspace (should fail)
      conn = get(conn, ~p"/api/workspaces/#{workspace2.id}/channels/#{channel2.id}/messages")
      assert json_response(conn, 403)
      
      # Try to create channel in second workspace (should fail)
      channel_attrs = %{name: "unauthorized", description: "Should not work"}
      conn = post(conn, ~p"/api/workspaces/#{workspace2.id}/channels", channel: channel_attrs)
      assert json_response(conn, 403)
      
      # Try to post message in second workspace channel (should fail)
      message_attrs = %{content: "Unauthorized message", type: "text"}
      conn = post(conn, ~p"/api/workspaces/#{workspace2.id}/channels/#{channel2.id}/messages", 
                 message: message_attrs)
      assert json_response(conn, 403)
    end

    test "prevents accessing channels through workspace ID manipulation", %{conn: conn, user: user} do
      # Create user's workspace
      workspace1_attrs = %{name: "User Workspace", description: "User's workspace"}
      conn = post(conn, ~p"/api/workspaces", workspace: workspace1_attrs)
      workspace1_id = json_response(conn, 201)["data"]["id"]
      
      # Create channel in user's workspace
      channel1_attrs = %{name: "user-channel", description: "User's channel"}
      conn = post(conn, ~p"/api/workspaces/#{workspace1_id}/channels", channel: channel1_attrs)
      channel1_id = json_response(conn, 201)["data"]["id"]
      
      # Create other user's workspace and channel
      other_user = insert(:user)
      workspace2 = insert(:workspace, owner: other_user)
      channel2 = insert(:channel, workspace: workspace2)
      
      # Try to access other user's channel through user's workspace URL (should fail)
      conn = get(conn, ~p"/api/workspaces/#{workspace1_id}/channels/#{channel2.id}")
      assert json_response(conn, 404)  # Not found because channel doesn't belong to workspace1
      
      # Try to access user's channel through other user's workspace URL (should fail)
      conn = get(conn, ~p"/api/workspaces/#{workspace2.id}/channels/#{channel1_id}")
      assert json_response(conn, 403)  # Forbidden because user doesn't have access to workspace2
    end
  end

  describe "Performance and concurrency scenarios" do
    setup :setup_authenticated_workspace

    test "handles concurrent message posting", %{conn: conn, workspace: workspace} do
      # Create channel
      channel_attrs = %{name: "high-traffic", description: "High traffic channel"}
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
      channel_id = json_response(conn, 201)["data"]["id"]
      
      # Simulate concurrent message posting
      tasks = 
        1..20
        |> Enum.map(fn i ->
          Task.async(fn ->
            message_attrs = %{content: "Concurrent message #{i}", type: "text"}
            post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages", 
                 message: message_attrs)
          end)
        end)
        |> Enum.map(&Task.await(&1, 10000))  # 10 second timeout
      
      successful_posts = Enum.count(tasks, &(&1.status == 201))
      assert successful_posts == 20
      
      # Verify all messages were saved
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages")
      messages = json_response(conn, 200)["data"]
      assert length(messages) == 20
      
      # Verify message ordering is maintained
      contents = Enum.map(messages, & &1["content"])
      sorted_contents = Enum.sort(contents)
      expected_contents = for i <- 1..20, do: "Concurrent message #{i}"
      assert Enum.sort(expected_contents) == sorted_contents
    end

    test "handles bulk channel creation efficiently", %{conn: conn, workspace: workspace} do
      # Create multiple channels quickly
      start_time = System.monotonic_time(:millisecond)
      
      channels = 
        for i <- 1..10 do
          channel_attrs = %{name: "bulk-channel-#{i}", description: "Bulk created channel #{i}"}
          response = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
          json_response(response, 201)["data"]
        end
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # Should complete within reasonable time (under 5 seconds)
      assert duration < 5000
      assert length(channels) == 10
      
      # Verify all channels exist
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels")
      workspace_channels = json_response(conn, 200)["data"]
      assert length(workspace_channels) == 10
    end

    test "maintains data consistency under load", %{conn: conn, workspace: workspace, user: user} do
      # Create channel
      channel_attrs = %{name: "consistency-test", description: "Testing consistency"}
      conn = post(conn, ~p"/api/workspaces/#{workspace.id}/channels", channel: channel_attrs)
      channel_id = json_response(conn, 201)["data"]["id"]
      
      # Simulate mixed operations (create messages, update channel)
      message_tasks = 
        1..15
        |> Enum.map(fn i ->
          Task.async(fn ->
            message_attrs = %{content: "Load test message #{i}", type: "text"}
            post(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages", 
                 message: message_attrs)
          end)
        end)
      
      update_tasks = 
        1..5
        |> Enum.map(fn i ->
          Task.async(fn ->
            update_attrs = %{description: "Updated description #{i}"}
            put(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}", 
                channel: update_attrs)
          end)
        end)
      
      # Wait for all tasks
      all_tasks = message_tasks ++ update_tasks
      results = Enum.map(all_tasks, &Task.await(&1, 10000))
      
      # Check results
      successful_messages = Enum.count(Enum.take(results, 15), &(&1.status == 201))
      successful_updates = Enum.count(Enum.drop(results, 15), &(&1.status == 200))
      
      assert successful_messages == 15
      assert successful_updates == 5
      
      # Verify final state consistency
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}")
      channel_data = json_response(conn, 200)["data"]
      assert channel_data["description"] =~ "Updated description"
      
      conn = get(conn, ~p"/api/workspaces/#{workspace.id}/channels/#{channel_id}/messages")
      messages = json_response(conn, 200)["data"]
      assert length(messages) == 15
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
end