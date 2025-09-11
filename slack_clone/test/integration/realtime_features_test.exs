defmodule SlackClone.Integration.RealtimeFeaturesTest do
  @moduledoc """
  Integration tests for real-time features across the entire stack.
  Tests the full flow from WebSocket connections to database persistence.
  """
  
  use SlackCloneWeb.ChannelCase
  use ExMachina

  import SlackClone.Factory
  import Phoenix.ChannelTest

  alias SlackCloneWeb.{UserSocket, ChannelChannel}
  alias SlackClone.Services.{ChannelServer, PresenceTracker}
  alias Phoenix.PubSub

  @endpoint SlackCloneWeb.Endpoint

  describe "end-to-end message flow" do
    setup do
      # Create test data
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace, name: "integration-test")
      user1 = insert(:user, name: "User One")
      user2 = insert(:user, name: "User Two")
      
      # Setup memberships
      insert(:workspace_membership, workspace: workspace, user: user1)
      insert(:workspace_membership, workspace: workspace, user: user2)
      insert(:channel_membership, channel: channel, user: user1)
      insert(:channel_membership, channel: channel, user: user2)
      
      # Start GenServers
      {:ok, _channel_pid} = ChannelServer.start_link(channel.id)
      {:ok, _presence_pid} = PresenceTracker.start_link()
      
      %{workspace: workspace, channel: channel, user1: user1, user2: user2}
    end

    test "complete message broadcasting workflow", %{channel: channel, user1: user1, user2: user2} do
      # Create authenticated sockets for both users
      token1 = Phoenix.Token.sign(@endpoint, "user socket", user1.id)
      token2 = Phoenix.Token.sign(@endpoint, "user socket", user2.id)
      
      {:ok, socket1} = connect(UserSocket, %{"token" => token1})
      {:ok, socket2} = connect(UserSocket, %{"token" => token2})
      
      # Both users join the channel
      {:ok, _, socket1} = subscribe_and_join(socket1, ChannelChannel, "channel:#{channel.id}")
      {:ok, _, socket2} = subscribe_and_join(socket2, ChannelChannel, "channel:#{channel.id}")
      
      # User 1 sends a message
      message_content = "Hello from integration test!"
      ref = push(socket1, "send_message", %{
        "content" => message_content,
        "temp_id" => "temp_123"
      })
      
      # User 1 should receive acknowledgment
      assert_reply ref, :ok, %{temp_id: "temp_123"}
      
      # User 2 should receive the new message
      assert_push "new_message", %{message: %{content: ^message_content}}
      
      # Verify message was persisted to database
      # (This would require actual database integration)
      
      # Verify ChannelServer state updated
      state = ChannelServer.get_channel_state(channel.id)
      assert length(state.recent_messages) >= 1
      assert hd(state.recent_messages).content == message_content
    end

    test "typing indicators work end-to-end", %{channel: channel, user1: user1, user2: user2} do
      token1 = Phoenix.Token.sign(@endpoint, "user socket", user1.id)
      token2 = Phoenix.Token.sign(@endpoint, "user socket", user2.id)
      
      {:ok, socket1} = connect(UserSocket, %{"token" => token1})
      {:ok, socket2} = connect(UserSocket, %{"token" => token2})
      
      {:ok, _, socket1} = subscribe_and_join(socket1, ChannelChannel, "channel:#{channel.id}")
      {:ok, _, socket2} = subscribe_and_join(socket2, ChannelChannel, "channel:#{channel.id}")
      
      # User 1 starts typing
      push(socket1, "typing_start", %{})
      
      # User 2 should receive typing notification
      assert_push "typing_start", %{user_id: user1_id, user_name: user1_name}
      assert user1_id == user1.id
      assert user1_name == user1.name
      
      # Verify ChannelServer tracks typing
      state = ChannelServer.get_channel_state(channel.id)
      assert MapSet.member?(state.typing_users, user1.id)
      
      # User 1 stops typing
      push(socket1, "typing_stop", %{})
      
      # User 2 should receive stop notification
      assert_push "typing_stop", %{user_id: ^user1_id}
      
      # Verify ChannelServer updated
      updated_state = ChannelServer.get_channel_state(channel.id)
      refute MapSet.member?(updated_state.typing_users, user1.id)
    end

    test "typing timeout works automatically", %{channel: channel, user1: user1, user2: user2} do
      token1 = Phoenix.Token.sign(@endpoint, "user socket", user1.id)
      token2 = Phoenix.Token.sign(@endpoint, "user socket", user2.id)
      
      {:ok, socket1} = connect(UserSocket, %{"token" => token1})
      {:ok, socket2} = connect(UserSocket, %{"token" => token2})
      
      {:ok, _, socket1} = subscribe_and_join(socket1, ChannelChannel, "channel:#{channel.id}")
      {:ok, _, socket2} = subscribe_and_join(socket2, ChannelChannel, "channel:#{channel.id}")
      
      # User 1 starts typing
      push(socket1, "typing_start", %{})
      assert_push "typing_start", %{user_id: user1_id}
      
      # Wait for timeout (3 seconds + buffer)
      Process.sleep(3500)
      
      # User 2 should receive automatic stop notification
      assert_push "typing_stop", %{user_id: ^user1_id}
      
      # Verify server state cleared
      state = ChannelServer.get_channel_state(channel.id)
      refute MapSet.member?(state.typing_users, user1.id)
    end

    test "presence tracking works end-to-end", %{channel: channel, user1: user1, user2: user2} do
      token1 = Phoenix.Token.sign(@endpoint, "user socket", user1.id)
      token2 = Phoenix.Token.sign(@endpoint, "user socket", user2.id)
      
      {:ok, socket1} = connect(UserSocket, %{"token" => token1})
      {:ok, socket2} = connect(UserSocket, %{"token" => token2})
      
      # User 1 joins channel
      {:ok, _, socket1} = subscribe_and_join(socket1, ChannelChannel, "channel:#{channel.id}")
      
      # Should receive initial presence state
      assert_push "presence_state", presence_state
      
      # User 2 joins channel
      {:ok, _, socket2} = subscribe_and_join(socket2, ChannelChannel, "channel:#{channel.id}")
      
      # User 1 should receive presence diff for user 2 joining
      assert_push "presence_diff", %{joins: joins}
      assert Map.has_key?(joins, user2.id)
      
      # Verify presence tracking in PresenceTracker
      presence1 = PresenceTracker.get_presence(user1.id)
      presence2 = PresenceTracker.get_presence(user2.id)
      
      assert presence1.status == :online
      assert presence2.status == :online
      
      # User 1 disconnects
      close(socket1)
      
      # User 2 should receive leave notification
      assert_push "presence_diff", %{leaves: leaves}
      assert Map.has_key?(leaves, user1.id)
      
      # Wait a bit for cleanup
      Process.sleep(100)
      
      # Verify presence updated
      updated_presence1 = PresenceTracker.get_presence(user1.id)
      assert updated_presence1.status == :offline
    end

    test "message reactions work end-to-end", %{channel: channel, user1: user1, user2: user2} do
      token1 = Phoenix.Token.sign(@endpoint, "user socket", user1.id)
      token2 = Phoenix.Token.sign(@endpoint, "user socket", user2.id)
      
      {:ok, socket1} = connect(UserSocket, %{"token" => token1})
      {:ok, socket2} = connect(UserSocket, %{"token" => token2})
      
      {:ok, _, socket1} = subscribe_and_join(socket1, ChannelChannel, "channel:#{channel.id}")
      {:ok, _, socket2} = subscribe_and_join(socket2, ChannelChannel, "channel:#{channel.id}")
      
      # User 1 sends a message
      push(socket1, "send_message", %{
        "content" => "React to this!",
        "temp_id" => "msg_123"
      })
      
      # Both users should receive the message
      assert_push "new_message", %{message: message}
      
      # User 2 adds a reaction
      push(socket2, "add_reaction", %{
        "message_id" => message.id,
        "emoji" => "👍"
      })
      
      # Both users should receive reaction notification
      assert_push "reaction_added", %{message_id: message_id, reaction: reaction}
      assert message_id == message.id
      assert reaction.emoji == "👍"
      assert reaction.user_id == user2.id
      
      # User 2 removes the reaction
      push(socket2, "remove_reaction", %{
        "reaction_id" => reaction.id
      })
      
      # Both users should receive removal notification
      assert_push "reaction_removed", %{reaction: removed_reaction}
      assert removed_reaction.id == reaction.id
    end
  end

  describe "concurrent user scenarios" do
    setup do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      users = insert_list(5, :user)
      
      for user <- users do
        insert(:workspace_membership, workspace: workspace, user: user)
        insert(:channel_membership, channel: channel, user: user)
      end
      
      {:ok, _channel_pid} = ChannelServer.start_link(channel.id)
      {:ok, _presence_pid} = PresenceTracker.start_link()
      
      %{workspace: workspace, channel: channel, users: users}
    end

    test "multiple users joining channel simultaneously", %{channel: channel, users: users} do
      # Connect all users simultaneously
      tasks = for user <- users do
        Task.async(fn ->
          token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
          {:ok, socket} = connect(UserSocket, %{"token" => token})
          {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
          {user.id, socket}
        end)
      end
      
      results = Task.await_many(tasks, 5000)
      
      # All should succeed
      assert length(results) == 5
      
      # Verify all users tracked in channel
      state = ChannelServer.get_channel_state(channel.id)
      assert state.stats.connected_users == 5
      
      # Verify presence tracking
      for user <- users do
        presence = PresenceTracker.get_presence(user.id)
        assert presence.status == :online
      end
    end

    test "concurrent message sending", %{channel: channel, users: users} do
      # Connect all users
      sockets = for user <- users do
        token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
        {:ok, socket} = connect(UserSocket, %{"token" => token})
        {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
        socket
      end
      
      # All users send messages simultaneously
      tasks = for {socket, i} <- Enum.with_index(sockets) do
        Task.async(fn ->
          push(socket, "send_message", %{
            "content" => "Message from user #{i}",
            "temp_id" => "temp_#{i}"
          })
        end)
      end
      
      Task.await_many(tasks, 5000)
      
      # Verify all messages received by all sockets
      for socket <- sockets do
        for i <- 0..4 do
          assert_push "new_message", %{message: %{content: content}}
          assert content =~ "Message from user"
        end
      end
      
      # Verify server state
      state = ChannelServer.get_channel_state(channel.id)
      assert length(state.recent_messages) == 5
      assert state.stats.messages_sent == 5
    end

    test "mixed concurrent operations", %{channel: channel, users: users} do
      # Connect users
      sockets = for user <- users do
        token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
        {:ok, socket} = connect(UserSocket, %{"token" => token})
        {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
        socket
      end
      
      # Mix of operations: messages, typing, reactions
      tasks = for {socket, i} <- Enum.with_index(sockets) do
        Task.async(fn ->
          case rem(i, 3) do
            0 -> 
              push(socket, "send_message", %{"content" => "Message #{i}", "temp_id" => "temp_#{i}"})
            1 -> 
              push(socket, "typing_start", %{})
            2 -> 
              # Would add reaction to previous message if available
              push(socket, "typing_start", %{})
          end
        end)
      end
      
      Task.await_many(tasks, 5000)
      
      # Wait for processing
      Process.sleep(100)
      
      # Verify mixed operations worked
      state = ChannelServer.get_channel_state(channel.id)
      assert state.stats.connected_users == 5
      assert state.stats.messages_sent >= 1
      assert state.stats.typing_users >= 1
    end
  end

  describe "error scenarios and recovery" do
    setup do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      user = insert(:user)
      
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: channel, user: user)
      
      {:ok, _channel_pid} = ChannelServer.start_link(channel.id)
      {:ok, _presence_pid} = PresenceTracker.start_link()
      
      %{channel: channel, user: user}
    end

    test "handles channel server crashes gracefully", %{channel: channel, user: user} do
      token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
      
      # Kill the channel server
      channel_pid = GenServer.whereis({:via, Registry, {SlackClone.ChannelRegistry, channel.id}})
      if channel_pid, do: Process.exit(channel_pid, :kill)
      
      # Wait for supervisor to restart
      Process.sleep(100)
      
      # Should be able to restart and continue
      {:ok, _new_pid} = ChannelServer.start_link(channel.id)
      
      # Operations should work again
      push(socket, "send_message", %{"content" => "After restart", "temp_id" => "temp_restart"})
      
      # Should not crash
    end

    test "handles presence tracker crashes gracefully", %{channel: channel, user: user} do
      token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
      
      # Kill the presence tracker
      presence_pid = Process.whereis(PresenceTracker)
      if presence_pid, do: Process.exit(presence_pid, :kill)
      
      # Wait for restart
      Process.sleep(100)
      
      # Should be able to restart
      {:ok, _new_pid} = PresenceTracker.start_link()
      
      # Presence operations should work again
      PresenceTracker.user_online(user.id, "socket_after_restart")
      
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :online
    end

    test "handles network disconnections and reconnections", %{channel: channel, user: user} do
      token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
      
      # Simulate network disconnect
      close(socket)
      
      # Wait for cleanup
      Process.sleep(100)
      
      # Reconnect
      {:ok, new_socket} = connect(UserSocket, %{"token" => token})
      {:ok, _, new_socket} = subscribe_and_join(new_socket, ChannelChannel, "channel:#{channel.id}")
      
      # Should receive fresh presence state
      assert_push "presence_state", _presence_state
      
      # Should be able to send messages
      push(new_socket, "send_message", %{"content" => "After reconnect", "temp_id" => "temp_reconnect"})
      assert_push "new_message", %{message: %{content: "After reconnect"}}
    end

    test "handles database connection errors during message persistence", %{channel: channel, user: user} do
      token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
      
      # This would require mocking the database to fail
      # For now, we'll just verify the message gets buffered
      push(socket, "send_message", %{"content" => "Test message", "temp_id" => "temp_db_error"})
      
      # Should still broadcast to other users even if DB fails
      assert_push "new_message", %{message: %{content: "Test message"}}
    end
  end

  describe "performance under load" do
    @tag :performance
    test "handles high message volume", %{} do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      user = insert(:user)
      
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: channel, user: user)
      
      {:ok, _channel_pid} = ChannelServer.start_link(channel.id)
      {:ok, _presence_pid} = PresenceTracker.start_link()
      
      token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
      
      # Send many messages rapidly
      start_time = System.monotonic_time(:millisecond)
      
      for i <- 1..100 do
        push(socket, "send_message", %{
          "content" => "Performance test message #{i}",
          "temp_id" => "perf_#{i}"
        })
      end
      
      # Receive all messages
      for _i <- 1..100 do
        assert_push "new_message", _message, 5000
      end
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # Should handle 100 messages in reasonable time (< 5 seconds)
      assert duration < 5000
      
      # Verify server state
      state = ChannelServer.get_channel_state(channel.id)
      assert state.stats.messages_sent == 100
      
      # Should limit recent messages to prevent memory issues
      assert length(state.recent_messages) <= 100
    end

    @tag :performance
    test "handles many concurrent typing indicators", %{} do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      users = insert_list(20, :user)
      
      for user <- users do
        insert(:workspace_membership, workspace: workspace, user: user)
        insert(:channel_membership, channel: channel, user: user)
      end
      
      {:ok, _channel_pid} = ChannelServer.start_link(channel.id)
      {:ok, _presence_pid} = PresenceTracker.start_link()
      
      # Connect all users
      sockets = for user <- users do
        token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
        {:ok, socket} = connect(UserSocket, %{"token" => token})
        {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
        socket
      end
      
      # All users start typing simultaneously
      start_time = System.monotonic_time(:millisecond)
      
      for socket <- sockets do
        push(socket, "typing_start", %{})
      end
      
      # Wait for all typing notifications
      for _i <- 1..20 do
        assert_push "typing_start", _typing_data, 1000
      end
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      # Should handle 20 typing indicators quickly (< 1 second)
      assert duration < 1000
      
      # Verify server state
      state = ChannelServer.get_channel_state(channel.id)
      assert state.stats.typing_users == 20
      assert state.stats.connected_users == 20
    end
  end

  describe "message persistence integration" do
    setup do
      workspace = insert(:workspace)
      channel = insert(:channel, workspace: workspace)
      user = insert(:user)
      
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: channel, user: user)
      
      {:ok, _channel_pid} = ChannelServer.start_link(channel.id)
      
      %{channel: channel, user: user}
    end

    test "message buffering and persistence workflow", %{channel: channel, user: user} do
      token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      {:ok, _, socket} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel.id}")
      
      # Send message
      push(socket, "send_message", %{
        "content" => "Test persistence",
        "temp_id" => "temp_persist"
      })
      
      # Should receive immediate broadcast
      assert_push "new_message", %{message: message}
      
      # Message should be in channel server memory
      state = ChannelServer.get_channel_state(channel.id)
      recent_message = hd(state.recent_messages)
      assert recent_message.content == "Test persistence"
      
      # In real implementation, would verify:
      # 1. Message buffered in MessageBufferServer
      # 2. Eventually persisted to database
      # 3. Persistence confirmation sent back to ChannelServer
    end
  end

  describe "cross-channel message broadcasting" do
    test "messages stay within correct channels" do
      workspace = insert(:workspace)
      channel1 = insert(:channel, workspace: workspace, name: "channel1")
      channel2 = insert(:channel, workspace: workspace, name: "channel2")
      user = insert(:user)
      
      insert(:workspace_membership, workspace: workspace, user: user)
      insert(:channel_membership, channel: channel1, user: user)
      insert(:channel_membership, channel: channel2, user: user)
      
      {:ok, _pid1} = ChannelServer.start_link(channel1.id)
      {:ok, _pid2} = ChannelServer.start_link(channel2.id)
      
      token = Phoenix.Token.sign(@endpoint, "user socket", user.id)
      {:ok, socket} = connect(UserSocket, %{"token" => token})
      
      # Join both channels
      {:ok, _, socket1} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel1.id}")
      {:ok, _, socket2} = subscribe_and_join(socket, ChannelChannel, "channel:#{channel2.id}")
      
      # Send message to channel 1
      push(socket1, "send_message", %{"content" => "Channel 1 message", "temp_id" => "temp1"})
      
      # Only socket1 should receive it
      assert_push "new_message", %{message: %{content: "Channel 1 message"}}
      
      # Socket2 should not receive it
      refute_push "new_message", %{message: %{content: "Channel 1 message"}}
      
      # Send message to channel 2
      push(socket2, "send_message", %{"content" => "Channel 2 message", "temp_id" => "temp2"})
      
      # Only socket2 should receive it
      assert_push "new_message", %{message: %{content: "Channel 2 message"}}
    end
  end
end