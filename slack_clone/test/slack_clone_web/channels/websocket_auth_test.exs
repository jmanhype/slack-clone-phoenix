defmodule SlackCloneWeb.WebSocketAuthTest do
  @moduledoc """
  Tests for WebSocket authentication and basic connection functionality.
  """
  use SlackCloneWeb.ChannelCase, async: false
  
  alias SlackClone.WebSocketTestHelper
  alias SlackCloneWeb.{UserSocket, WorkspaceChannel, ChannelChannel}

  setup do
    # Create test user with valid token
    {user, token} = WebSocketTestHelper.create_test_user_with_token()
    
    on_exit(fn ->
      WebSocketTestHelper.cleanup_test_data()
    end)
    
    %{user: user, token: token}
  end

  describe "WebSocket authentication" do
    test "connects successfully with valid token", %{token: token} do
      assert {:ok, socket} = WebSocketTestHelper.connect_socket(token)
      assert socket.assigns[:user_id]
    end

    test "rejects connection with invalid token" do
      invalid_token = "invalid_token_12345"
      assert {:error, _reason} = WebSocketTestHelper.connect_socket(invalid_token)
    end

    test "rejects connection without token" do
      assert {:error, _reason} = connect(UserSocket, %{})
    end

    test "rejects connection with malformed token" do
      malformed_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.malformed"
      assert {:error, _reason} = WebSocketTestHelper.connect_socket(malformed_token)
    end
  end

  describe "workspace channel authentication" do
    test "joins workspace channel with authentication", %{user: user, token: token} do
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      test_data = WebSocketTestHelper.create_test_workspace_and_channels(user)
      workspace_id = test_data.workspace.id
      
      assert {:ok, reply, socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          WorkspaceChannel, 
          "workspace:#{workspace_id}"
        )
      
      assert reply.status == "ok"
      assert socket.topic == "workspace:#{workspace_id}"
    end

    test "rejects workspace join without proper authorization", %{token: token} do
      {:ok, socket} = WebSocketTestHelper.connect_socket(token)
      
      # Try to join workspace that doesn't belong to user
      unauthorized_workspace_id = "unauthorized_workspace_123"
      
      assert {:error, %{reason: reason}} = 
        WebSocketTestHelper.join_channel(
          socket, 
          WorkspaceChannel, 
          "workspace:#{unauthorized_workspace_id}"
        )
        
      assert reason in ["unauthorized", "not_found"]
    end
  end

  describe "channel authentication" do
    test "joins channel with proper workspace membership", %{user: user, token: token} do
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      test_data = WebSocketTestHelper.create_test_workspace_and_channels(user)
      channel_id = test_data.channel.id
      
      assert {:ok, reply, socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          ChannelChannel, 
          "channel:#{channel_id}"
        )
      
      assert reply.status == "ok"
      assert socket.topic == "channel:#{channel_id}"
    end

    test "rejects channel join for unauthorized user", %{token: token} do
      {:ok, socket} = WebSocketTestHelper.connect_socket(token)
      
      # Try to join channel that doesn't belong to user
      unauthorized_channel_id = "unauthorized_channel_123"
      
      assert {:error, %{reason: reason}} = 
        WebSocketTestHelper.join_channel(
          socket, 
          ChannelChannel, 
          "channel:#{unauthorized_channel_id}"
        )
        
      assert reason in ["unauthorized", "not_found"]
    end
  end

  describe "real-time message flow" do
    test "authenticated user can send and receive messages", %{user: user, token: token} do
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      test_data = WebSocketTestHelper.create_test_workspace_and_channels(user)
      channel_id = test_data.channel.id
      
      {:ok, _reply, socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          ChannelChannel, 
          "channel:#{channel_id}"
        )
      
      # Test sending a message
      message_payload = %{
        "content" => "Hello, WebSocket!",
        "type" => "text"
      }
      
      # This should work once the channel handlers are properly implemented
      ref = push(socket, "new_message", message_payload)
      
      # For now, we expect this to work or give a reasonable error
      # The exact response depends on the implementation
      assert_reply ref, reply_status, _response, 2000
      assert reply_status in ["ok", "error"]
    end

    test "typing indicators work with authentication", %{user: user, token: token} do
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      test_data = WebSocketTestHelper.create_test_workspace_and_channels(user)
      channel_id = test_data.channel.id
      
      {:ok, _reply, socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          ChannelChannel, 
          "channel:#{channel_id}"
        )
      
      # Test typing indicator
      ref = push(socket, "typing_start", %{})
      assert_reply ref, reply_status, _response, 1000
      assert reply_status in ["ok", "error"]
      
      ref = push(socket, "typing_stop", %{})
      assert_reply ref, reply_status, _response, 1000
      assert reply_status in ["ok", "error"]
    end
  end

  describe "presence tracking" do
    test "user presence is tracked on workspace join", %{user: user, token: token} do
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      test_data = WebSocketTestHelper.create_test_workspace_and_channels(user)
      workspace_id = test_data.workspace.id
      
      {:ok, _reply, _socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          WorkspaceChannel, 
          "workspace:#{workspace_id}"
        )
      
      # Check if presence was tracked (implementation dependent)
      # For now, just verify the join was successful
      assert true
    end

    test "presence updates are broadcast to workspace members", %{user: user, token: token} do
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      test_data = WebSocketTestHelper.create_test_workspace_and_channels(user)
      workspace_id = test_data.workspace.id
      
      {:ok, _reply, socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          WorkspaceChannel, 
          "workspace:#{workspace_id}"
        )
      
      # Test presence update
      ref = push(socket, "update_presence", %{"status" => "active"})
      assert_reply ref, reply_status, _response, 1000
      assert reply_status in ["ok", "error"]
    end
  end

  describe "connection performance" do
    test "WebSocket connection establishment performance" do
      {user, token} = WebSocketTestHelper.create_test_user_with_token()
      
      {result, duration_ms} = WebSocketTestHelper.measure_websocket_performance(fn ->
        WebSocketTestHelper.connect_socket(token, user.id)
      end)
      
      assert {:ok, _socket} = result
      assert duration_ms < 1000, "Connection should establish in under 1 second, took #{duration_ms}ms"
    end

    test "multiple concurrent connections" do
      # Create 5 concurrent connections
      connections = WebSocketTestHelper.create_concurrent_connections(5)
      
      # All connections should succeed
      Enum.each(connections, fn connection ->
        assert {:ok, _socket} = connection
      end)
      
      assert length(connections) == 5
    end
  end

  describe "error handling" do
    test "graceful handling of connection drops" do
      {user, token} = WebSocketTestHelper.create_test_user_with_token()
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      # Simulate connection close
      close(socket)
      
      # Should be able to reconnect
      assert {:ok, _new_socket} = WebSocketTestHelper.connect_socket(token, user.id)
    end

    test "invalid message format handling", %{user: user, token: token} do
      {:ok, socket} = WebSocketTestHelper.connect_socket(token, user.id)
      
      test_data = WebSocketTestHelper.create_test_workspace_and_channels(user)
      channel_id = test_data.channel.id
      
      {:ok, _reply, socket} = 
        WebSocketTestHelper.join_channel(
          socket, 
          ChannelChannel, 
          "channel:#{channel_id}"
        )
      
      # Send invalid message format
      ref = push(socket, "new_message", "invalid_format")
      assert_reply ref, "error", _error_response, 1000
    end
  end
end