defmodule SlackCloneWeb.BrowserRealTimeTest do
  @moduledoc """
  Browser-based integration tests for real-time features using Phoenix LiveView and WebSockets.
  Tests end-to-end real-time functionality including WebSocket connections, 
  LiveView updates, and user interactions.
  """
  use SlackCloneWeb.ConnCase
  use Phoenix.LiveViewTest

  import Phoenix.ChannelTest
  alias SlackCloneWeb.{UserSocket, WorkspaceChannel, ChannelChannel}

  @endpoint SlackCloneWeb.Endpoint

  describe "LiveView Real-time Integration" do
    setup do
      # Create test user and session
      user = %{
        id: "test_user_123",
        name: "Test User",
        email: "test@example.com",
        avatar_url: "/images/default-avatar.png"
      }
      
      conn = build_conn()
      |> assign(:current_user, user)
      |> put_session(:user_token, Phoenix.Token.sign(@endpoint, "user session", user.id))
      
      %{conn: conn, user: user}
    end

    test "workspace live view establishes WebSocket connection", %{conn: conn} do
      workspace_id = "test_workspace"
      
      {:ok, view, html} = live(conn, "/workspace/#{workspace_id}")
      
      # Check that the page loads with WebSocket connection setup
      assert html =~ "workspace"
      assert has_element?(view, "[data-workspace-id='#{workspace_id}']")
      
      # Verify that WebSocket connection JavaScript is present
      assert html =~ "socket" or html =~ "WebSocket"
    end

    test "channel live view connects to channel WebSocket", %{conn: conn} do
      workspace_id = "test_workspace"
      channel_id = "general"
      
      {:ok, view, html} = live(conn, "/workspace/#{workspace_id}/channel/#{channel_id}")
      
      # Check that the channel page loads
      assert html =~ "channel"
      assert has_element?(view, "[data-channel-id='#{channel_id}']")
      
      # Should have message input and send functionality
      assert has_element?(view, "form[phx-submit]") or 
             has_element?(view, "input[type='text']") or
             has_element?(view, "textarea")
    end

    test "real-time presence updates in LiveView", %{conn: conn} do
      workspace_id = "test_workspace"
      
      {:ok, view, _html} = live(conn, "/workspace/#{workspace_id}")
      
      # Simulate presence update
      presence_data = %{
        "user_456" => %{
          metas: [%{name: "New User", status: "online", joined_at: System.system_time(:second)}]
        }
      }
      
      # Send presence update to the LiveView
      send(view.pid, {:presence_update, presence_data})
      
      # Check if presence is updated in the view
      assert render(view) =~ "New User" or
             has_element?(view, "[data-user-id='user_456']")
    end

    test "LiveView handles real-time channel updates", %{conn: conn} do
      workspace_id = "test_workspace"
      
      {:ok, view, _html} = live(conn, "/workspace/#{workspace_id}")
      
      # Simulate new channel creation
      new_channel = %{
        id: "new_channel_123",
        name: "announcements",
        description: "Important announcements",
        type: "public"
      }
      
      send(view.pid, {:channel_created, new_channel})
      
      # Should show the new channel in the sidebar
      assert render(view) =~ "announcements" or
             has_element?(view, "[data-channel-id='new_channel_123']")
    end

    test "message input and sending in LiveView", %{conn: conn} do
      workspace_id = "test_workspace"
      channel_id = "general"
      
      {:ok, view, _html} = live(conn, "/workspace/#{workspace_id}/channel/#{channel_id}")
      
      # Try to send a message through the form
      if has_element?(view, "form[phx-submit]") do
        form_data = %{"message" => %{"content" => "Hello from LiveView test!"}}
        render_submit(view, :send_message, form_data)
        
        # Check that the form was processed (might show loading state or clear input)
        html = render(view)
        assert html != ""  # Basic sanity check
      end
    end

    test "typing indicators work in real-time", %{conn: conn} do
      workspace_id = "test_workspace"
      channel_id = "general"
      
      {:ok, view, _html} = live(conn, "/workspace/#{workspace_id}/channel/#{channel_id}")
      
      # Simulate typing event from another user
      typing_data = %{
        user_id: "other_user",
        user_name: "Other User",
        channel_id: channel_id
      }
      
      send(view.pid, {:typing_start, typing_data})
      
      # Should show typing indicator
      html = render(view)
      assert html =~ "typing" or html =~ "Other User" or 
             has_element?(view, "[data-typing]")
    end
  end

  describe "WebSocket Authentication Flow" do
    test "WebSocket connects with valid session token" do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      
      # Test direct socket connection
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      assert socket.assigns.current_user.id == user_id
      assert socket.id == "user_socket:#{user_id}"
    end

    test "WebSocket rejects invalid authentication" do
      # Test various invalid auth scenarios
      assert connect(UserSocket, %{"token" => "invalid"}) == :error
      assert connect(UserSocket, %{}) == :error
      assert connect(UserSocket, %{"token" => nil}) == :error
    end

    test "token verification with different user scenarios" do
      # Valid user
      valid_token = Phoenix.Token.sign(@endpoint, "user socket", "valid_user")
      {:ok, socket} = connect(UserSocket, %{"token" => valid_token})
      assert socket.assigns.current_user.id == "valid_user"
      
      # Invalid user (returns nil from load_user)
      invalid_token = Phoenix.Token.sign(@endpoint, "user socket", "invalid")
      assert connect(UserSocket, %{"token" => invalid_token}) == :error
    end
  end

  describe "Real-time Error Handling" do
    setup do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      %{socket: socket}
    end

    test "graceful handling of channel disconnections", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, channel_socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Forcefully close the channel
      Process.exit(channel_socket.channel_pid, :kill)
      
      # Should be able to rejoin without issues
      {:ok, _reply, _new_socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
    end

    test "network interruption simulation", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, workspace_socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Simulate network issues by sending malformed data
      Process.send(workspace_socket.channel_pid, {:invalid_data, "corrupted"}, [])
      
      # Channel should remain stable
      assert Process.alive?(workspace_socket.channel_pid)
      
      # Should still respond to valid messages
      ref = push(workspace_socket, "get_workspace_info", %{})
      assert_reply ref, :ok
    end

    test "concurrent message handling", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, channel_socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Send multiple messages concurrently
      tasks = for i <- 1..10 do
        Task.async(fn ->
          push(channel_socket, "send_message", %{
            "content" => "Concurrent message #{i}",
            "temp_id" => "temp_#{i}"
          })
        end)
      end
      
      # Wait for all tasks to complete
      Enum.each(tasks, &Task.await/1)
      
      # Channel should remain responsive
      assert Process.alive?(channel_socket.channel_pid)
    end
  end

  describe "PubSub Message Broadcasting" do
    setup do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      %{socket: socket}
    end

    test "workspace-level broadcasts reach all subscribers", %{socket: socket} do
      workspace_id = "test_workspace"
      
      # Create multiple connections to same workspace
      {:ok, _reply, socket1} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Create second socket for different user
      user_id2 = "test_user_456"
      token2 = Phoenix.Token.sign(@endpoint, "user socket", user_id2)
      {:ok, socket2} = connect(UserSocket, %{"token" => token2})
      {:ok, _reply, socket2} = subscribe_and_join(socket2, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Broadcast workspace event
      workspace_event = %{id: "new_channel", name: "updates", type: "public"}
      
      send(socket1.channel_pid, {:channel_created, workspace_event})
      send(socket2.channel_pid, {:channel_created, workspace_event})
      
      # Both should receive the event
      assert_push "channel_created", %{channel: ^workspace_event}, socket1
      assert_push "channel_created", %{channel: ^workspace_event}, socket2
    end

    test "channel-level broadcasts are isolated", %{socket: socket} do
      # Join two different channels
      {:ok, _reply, channel1} = subscribe_and_join(socket, ChannelChannel, "channel:general")
      {:ok, _reply, channel2} = subscribe_and_join(socket, ChannelChannel, "channel:random")
      
      # Send message to channel1
      message_data = %{id: "msg_123", content: "Test message", user_id: "sender"}
      send(channel1.channel_pid, {:new_message, message_data})
      
      # Only channel1 should receive it
      assert_push "new_message", %{message: ^message_data}, channel1
      
      # channel2 should not receive it (no message within timeout)
      refute_push "new_message", channel2, 100
    end

    test "presence broadcasts work across channels", %{socket: socket} do
      workspace_id = "test_workspace"
      channel_id = "general"
      
      # Join both workspace and channel
      {:ok, _reply, workspace_socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      {:ok, _reply, channel_socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Both should receive presence state
      assert_push "workspace_state", %{online_users: _}, workspace_socket
      assert_push "presence_state", _, channel_socket
      
      # Status change should propagate
      push(workspace_socket, "user_status_change", %{"status" => "busy"})
      
      # Should receive presence updates
      assert_push "presence_diff", _, workspace_socket
    end
  end

  describe "Performance and Load Testing" do
    setup do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      %{socket: socket}
    end

    test "multiple simultaneous connections", %{socket: base_socket} do
      workspace_id = "test_workspace"
      
      # Create multiple concurrent connections
      sockets = for i <- 1..5 do
        user_id = "load_test_user_#{i}"
        token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
        {:ok, socket} = connect(UserSocket, %{"token" => token})
        {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
        socket
      end
      
      # All should be connected successfully
      assert length(sockets) == 5
      Enum.each(sockets, fn socket ->
        assert Process.alive?(socket.channel_pid)
      end)
      
      # Cleanup
      Enum.each(sockets, &close/1)
    end

    test "high-frequency message simulation", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, channel_socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Simulate rapid message events
      start_time = System.monotonic_time(:millisecond)
      
      for i <- 1..50 do
        message_data = %{
          id: "rapid_msg_#{i}",
          content: "Rapid message #{i}",
          user_id: "rapid_sender"
        }
        send(channel_socket.channel_pid, {:new_message, message_data})
      end
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # Should handle rapidly without crashing
      assert Process.alive?(channel_socket.channel_pid)
      assert duration < 1000  # Should complete within 1 second
    end

    test "memory usage under load", %{socket: socket} do
      initial_memory = :erlang.memory(:total)
      
      # Create load by joining many channels
      channel_sockets = for i <- 1..10 do
        channel_id = "load_channel_#{i}"
        {:ok, _reply, channel_socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
        channel_socket
      end
      
      # Memory should not grow excessively
      loaded_memory = :erlang.memory(:total)
      memory_increase = loaded_memory - initial_memory
      
      # Allow for reasonable memory increase (10MB limit for test)
      assert memory_increase < 10_000_000
      
      # Cleanup
      Enum.each(channel_sockets, &close/1)
      
      # Force garbage collection
      :erlang.garbage_collect()
      
      final_memory = :erlang.memory(:total)
      # Memory should be released after cleanup
      assert final_memory <= loaded_memory
    end
  end
end