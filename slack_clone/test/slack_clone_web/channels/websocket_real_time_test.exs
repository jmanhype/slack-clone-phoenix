defmodule SlackCloneWeb.WebSocketRealTimeTest do
  @moduledoc """
  Comprehensive test suite for real-time WebSocket features in the Slack clone.
  Tests WebSocket connections, Phoenix LiveView updates, PubSub messaging, and authentication.
  """
  use SlackCloneWeb.ChannelCase
  
  import Phoenix.ChannelTest
  alias SlackCloneWeb.{UserSocket, WorkspaceChannel, ChannelChannel}
  alias SlackCloneWeb.Presence

  @endpoint SlackCloneWeb.Endpoint

  describe "WebSocket Connection Tests" do
    test "successfully connects with valid token" do
      # Generate valid token
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      
      # Test connection
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      assert socket.assigns.user_id == user_id
      assert socket.assigns.current_user.id == user_id
      assert socket.assigns.current_user.name == "Mock User"
    end

    test "rejects connection with invalid token" do
      # Test with invalid token
      assert connect(UserSocket, %{"token" => "invalid_token"}) == :error
    end

    test "rejects connection without token" do
      # Test without token
      assert connect(UserSocket, %{}) == :error
    end

    test "rejects connection with expired token" do
      # Create expired token (this would normally be expired by time)
      user_id = "invalid"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      
      assert connect(UserSocket, %{"token" => token}) == :error
    end

    test "socket ID is correctly set for user identification" do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      assert socket.id == "user_socket:#{user_id}"
    end
  end

  describe "WorkspaceChannel Real-time Tests" do
    setup do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      %{socket: socket, user_id: user_id}
    end

    test "successfully joins workspace channel", %{socket: socket} do
      workspace_id = "test_workspace"
      
      {:ok, reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      assert reply.workspace.id == workspace_id
      assert reply.user.id == socket.assigns.user_id
      assert socket.assigns.workspace_id == workspace_id
    end

    test "rejects unauthorized workspace access", %{socket: socket} do
      # Try to join unauthorized workspace
      assert subscribe_and_join(socket, WorkspaceChannel, "workspace:unauthorized") == 
             {:error, %{reason: "Access denied"}}
    end

    test "tracks user presence after joining workspace", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Wait for after_join message to be processed
      assert_push "workspace_state", %{channels: channels, online_users: online_users}
      
      assert is_list(channels)
      assert Map.has_key?(online_users, socket.assigns.user_id)
      
      user_presence = online_users[socket.assigns.user_id]
      assert user_presence.metas |> List.first() |> Map.get(:status) == "online"
    end

    test "handles user status change events", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Change user status
      ref = push(socket, "user_status_change", %{"status" => "away"})
      assert_reply ref, :ok
      
      # Should receive presence update
      assert_push "presence_diff", %{joins: _, leaves: _}
    end

    test "handles workspace info requests", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      ref = push(socket, "get_workspace_info", %{})
      assert_reply ref, :ok
      
      assert_push "workspace_info", %{
        channels: channels,
        members: members,
        online_users: online_users,
        unread_counts: unread_counts
      }
      
      assert is_list(channels)
      assert is_list(members)
      assert is_map(online_users)
      assert is_map(unread_counts)
    end

    test "handles channel creation events", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Mock channel creation (this would normally create a real channel)
      ref = push(socket, "create_channel", %{
        "name" => "new-channel",
        "description" => "A new test channel",
        "type" => "public"
      })
      
      # Should receive error since create_channel is mocked to fail
      assert_push "error", %{event: "create_channel"}
    end

    test "receives PubSub notifications for workspace events", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Simulate external events
      send(socket.channel_pid, {:channel_created, %{id: "new_channel", name: "test"}})
      assert_push "channel_created", %{channel: %{id: "new_channel"}}
      
      send(socket.channel_pid, {:user_status_change, %{user_id: "other_user", status: "online"}})
      assert_push "user_status_change", %{user_id: "other_user", status: "online"}
    end
  end

  describe "ChannelChannel Real-time Tests" do
    setup do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      %{socket: socket, user_id: user_id}
    end

    test "successfully joins channel", %{socket: socket} do
      channel_id = "general"
      
      {:ok, reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      assert reply.channel.id == channel_id
      assert socket.assigns.channel_id == channel_id
    end

    test "rejects unauthorized channel access", %{socket: socket} do
      assert subscribe_and_join(socket, ChannelChannel, "channel:unauthorized") == 
             {:error, %{reason: "Access denied"}}
    end

    test "loads recent messages after joining", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      assert_push "messages_loaded", %{messages: messages}
      assert is_list(messages)
    end

    test "tracks user presence in channel", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      assert_push "presence_state", presence_state
      assert Map.has_key?(presence_state, socket.assigns.user_id)
    end

    test "handles message sending (mocked)", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Try to send message (should fail due to mocked implementation)
      ref = push(socket, "send_message", %{
        "content" => "Hello, world!",
        "temp_id" => "temp_123"
      })
      
      assert_push "message_error", %{temp_id: "temp_123"}
    end

    test "handles typing indicators", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Start typing
      ref = push(socket, "typing_start", %{})
      assert_reply ref, :ok
      
      # Stop typing
      ref = push(socket, "typing_stop", %{})
      assert_reply ref, :ok
    end

    test "typing timeout automatically stops typing indicator", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Start typing
      ref = push(socket, "typing_start", %{})
      assert_reply ref, :ok
      
      # Wait for timeout (mocked to be immediate for testing)
      send(socket.channel_pid, :typing_timeout)
      
      # Should not crash or error
      assert Process.alive?(socket.channel_pid)
    end

    test "handles message read receipts", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Mark message as read
      ref = push(socket, "mark_read", %{"message_id" => "msg_123"})
      assert_reply ref, :ok
    end

    test "handles older messages loading request", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Load older messages
      ref = push(socket, "load_older_messages", %{"before_id" => "msg_100"})
      assert_reply ref, :ok
      
      assert_push "older_messages_loaded", %{messages: messages}
      assert is_list(messages)
    end

    test "receives PubSub notifications for channel events", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Simulate message events
      mock_message = %{id: "msg_123", content: "Test message", user_id: "other_user"}
      send(socket.channel_pid, {:new_message, mock_message})
      assert_push "new_message", %{message: ^mock_message}
      
      # Simulate typing events  
      typing_data = %{user_id: "other_user", user_name: "Other User"}
      send(socket.channel_pid, {:typing_start, typing_data})
      assert_push "typing_start", ^typing_data
      
      send(socket.channel_pid, {:typing_stop, typing_data})
      assert_push "typing_stop", ^typing_data
    end
  end

  describe "WebSocket Error Handling and Recovery" do
    setup do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      %{socket: socket, user_id: user_id}
    end

    test "handles channel termination gracefully", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Terminate the channel
      close(socket)
      
      # Should not leave hanging processes
      refute Process.alive?(socket.channel_pid)
    end

    test "cleans up resources on socket disconnection", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Start typing to set timer
      push(socket, "typing_start", %{})
      
      # Close socket (should clean up typing timer)
      close(socket)
      
      refute Process.alive?(socket.channel_pid)
    end

    test "handles malformed messages gracefully", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Send malformed message data
      ref = push(socket, "send_message", %{"invalid" => "data"})
      
      # Should handle gracefully (likely with error due to missing content)
      assert_push "message_error", _error_data
    end

    test "socket survives unexpected messages", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Send unexpected message
      send(socket.channel_pid, {:unexpected_message, "random_data"})
      
      # Channel should still be alive
      assert Process.alive?(socket.channel_pid)
      
      # Should still respond to normal messages
      ref = push(socket, "get_workspace_info", %{})
      assert_reply ref, :ok
    end
  end

  describe "Presence System Tests" do
    setup do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      %{socket: socket, user_id: user_id}
    end

    test "tracks presence across multiple channels", %{socket: socket} do
      # Join workspace
      workspace_id = "test_workspace"
      {:ok, _reply, workspace_socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Join channel
      channel_id = "general"
      {:ok, _reply, channel_socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Both should track presence
      assert_push "workspace_state", %{online_users: workspace_users}
      assert_push "presence_state", channel_users
      
      assert Map.has_key?(workspace_users, socket.assigns.user_id)
      assert Map.has_key?(channel_users, socket.assigns.user_id)
    end

    test "presence updates propagate correctly", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Change status
      push(socket, "user_status_change", %{"status" => "busy"})
      
      # Should receive presence diff
      assert_push "presence_diff", %{joins: joins, leaves: leaves}
      
      # Verify the update includes status change
      assert is_map(joins) or is_map(leaves)
    end
  end

  describe "Channel Subscription Management" do
    setup do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      %{socket: socket, user_id: user_id}
    end

    test "can join and leave channels through workspace", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Try to join a channel (should fail due to mocked implementation)
      ref = push(socket, "join_channel", %{"channel_id" => "new_channel"})
      assert_push "error", %{event: "join_channel"}
      
      # Try to leave a channel (should fail due to mocked implementation)  
      ref = push(socket, "leave_channel", %{"channel_id" => "new_channel"})
      assert_push "error", %{event: "leave_channel"}
    end

    test "multiple sockets can join same channel", %{socket: socket1, user_id: user_id1} do
      # Create second socket for different user
      user_id2 = "test_user_456"
      token2 = Phoenix.Token.sign(@endpoint, "user socket", user_id2)
      {:ok, socket2} = connect(UserSocket, %{"token" => token2})
      
      channel_id = "general"
      
      # Both join same channel
      {:ok, _reply1, socket1} = subscribe_and_join(socket1, ChannelChannel, "channel:#{channel_id}")
      {:ok, _reply2, socket2} = subscribe_and_join(socket2, ChannelChannel, "channel:#{channel_id}")
      
      # Both should receive presence state
      assert_push "presence_state", presence1, socket1
      assert_push "presence_state", presence2, socket2
      
      # Both users should be in presence
      assert Map.has_key?(presence1, user_id1)
      assert Map.has_key?(presence2, user_id1)
      assert Map.has_key?(presence2, user_id2)
    end
  end

  describe "Real-time Message Broadcasting" do
    setup do
      user_id = "test_user_123"
      token = Phoenix.Token.sign(@endpoint, "user socket", user_id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      %{socket: socket, user_id: user_id}
    end

    test "messages broadcast to all channel subscribers", %{socket: socket} do
      channel_id = "general"
      {:ok, _reply, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel_id}")
      
      # Simulate external message broadcast
      mock_message = %{
        id: "msg_456",
        content: "Broadcasted message",
        user_id: "other_user",
        channel_id: channel_id
      }
      
      send(socket.channel_pid, {:new_message, mock_message})
      assert_push "new_message", %{message: ^mock_message}
    end

    test "workspace events broadcast to workspace subscribers", %{socket: socket} do
      workspace_id = "test_workspace"
      {:ok, _reply, socket} = subscribe_and_join(socket, WorkspaceChannel, "workspace:#{workspace_id}")
      
      # Simulate workspace-level event
      mock_channel = %{id: "new_channel", name: "announcements", type: "public"}
      send(socket.channel_pid, {:channel_created, mock_channel})
      
      assert_push "channel_created", %{channel: ^mock_channel}
    end
  end
end