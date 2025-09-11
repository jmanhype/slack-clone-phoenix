defmodule SlackClone.Services.ChannelServerTest do
  use SlackClone.DataCase
  use ExMachina

  import SlackClone.Factory

  alias SlackClone.Services.ChannelServer
  alias SlackClone.Channels
  alias Phoenix.PubSub

  describe "GenServer lifecycle" do
    test "starts with valid channel_id" do
      channel = insert(:channel)
      
      assert {:ok, pid} = ChannelServer.start_link(channel.id)
      assert Process.alive?(pid)
      
      state = ChannelServer.get_channel_state(channel.id)
      assert state.channel.id == channel.id
      assert state.connected_users == %{}
      assert state.typing_users == []
      assert state.stats.connected_users == 0
    end

    test "fails to start with invalid channel_id" do
      invalid_id = Ecto.UUID.generate()
      
      assert {:error, :channel_not_found} = ChannelServer.start_link(invalid_id)
    end

    test "terminates gracefully and cleans up timers" do
      channel = insert(:channel)
      user = insert(:user)
      
      {:ok, pid} = ChannelServer.start_link(channel.id)
      
      # Start typing to create timer
      ChannelServer.update_typing(channel.id, user.id, true)
      
      # Kill the process
      Process.exit(pid, :kill)
      
      # Verify process is dead
      refute Process.alive?(pid)
    end
  end

  describe "user management" do
    setup do
      channel = insert(:channel)
      user1 = insert(:user)
      user2 = insert(:user) 
      
      {:ok, _pid} = ChannelServer.start_link(channel.id)
      
      %{channel: channel, user1: user1, user2: user2}
    end

    test "allows authorized users to join channel", %{channel: channel, user1: user1} do
      # Mock authorization to return true
      expect(Channels, :can_access?, fn _channel_id, _user_id -> true end)
      
      ChannelServer.join_channel(channel.id, user1.id, "socket_1")
      
      state = ChannelServer.get_channel_state(channel.id)
      assert Map.has_key?(state.connected_users, user1.id)
      assert state.stats.connected_users == 1
      
      user_connection = state.connected_users[user1.id]
      assert user_connection.user_id == user1.id
      assert "socket_1" in user_connection.sockets
    end

    test "denies unauthorized users", %{channel: channel, user1: user1} do
      # Mock authorization to return false
      expect(Channels, :can_access?, fn _channel_id, _user_id -> false end)
      
      ChannelServer.join_channel(channel.id, user1.id, "socket_1")
      
      state = ChannelServer.get_channel_state(channel.id)
      assert state.connected_users == %{}
      assert state.stats.connected_users == 0
    end

    test "tracks multiple sockets for same user", %{channel: channel, user1: user1} do
      expect(Channels, :can_access?, 2, fn _channel_id, _user_id -> true end)
      
      ChannelServer.join_channel(channel.id, user1.id, "socket_1")
      ChannelServer.join_channel(channel.id, user1.id, "socket_2")
      
      state = ChannelServer.get_channel_state(channel.id)
      user_connection = state.connected_users[user1.id]
      
      assert length(user_connection.sockets) == 2
      assert "socket_1" in user_connection.sockets
      assert "socket_2" in user_connection.sockets
      assert state.stats.connected_users == 1  # Still one unique user
    end

    test "removes user when all sockets disconnect", %{channel: channel, user1: user1} do
      expect(Channels, :can_access?, fn _channel_id, _user_id -> true end)
      
      ChannelServer.join_channel(channel.id, user1.id, "socket_1")
      ChannelServer.join_channel(channel.id, user1.id, "socket_2")
      
      # Remove one socket
      ChannelServer.leave_channel(channel.id, user1.id, "socket_1")
      state = ChannelServer.get_channel_state(channel.id)
      user_connection = state.connected_users[user1.id]
      assert length(user_connection.sockets) == 1
      assert state.stats.connected_users == 1
      
      # Remove last socket
      ChannelServer.leave_channel(channel.id, user1.id, "socket_2")
      final_state = ChannelServer.get_channel_state(channel.id)
      assert final_state.connected_users == %{}
      assert final_state.stats.connected_users == 0
    end

    test "broadcasts user join/leave events", %{channel: channel, user1: user1} do
      expect(Channels, :can_access?, fn _channel_id, _user_id -> true end)
      
      # Subscribe to user events
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:users")
      
      ChannelServer.join_channel(channel.id, user1.id, "socket_1")
      
      assert_receive {:user_change, ^user1.id, :joined}
      
      ChannelServer.leave_channel(channel.id, user1.id, "socket_1")
      
      assert_receive {:user_change, ^user1.id, :left}
    end
  end

  describe "message handling" do
    setup do
      channel = insert(:channel)
      user = insert(:user)
      
      {:ok, _pid} = ChannelServer.start_link(channel.id)
      
      # Join user to channel first
      expect(Channels, :can_access?, fn _channel_id, _user_id -> true end)
      ChannelServer.join_channel(channel.id, user.id, "socket_1")
      
      %{channel: channel, user: user}
    end

    test "processes messages from connected users", %{channel: channel, user: user} do
      # Subscribe to message events
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:messages")
      
      content = "Hello everyone!"
      metadata = %{"type" => "text"}
      
      ChannelServer.send_message(channel.id, user.id, content, metadata)
      
      # Should receive broadcast
      assert_receive {:new_message, message}
      assert message.content == content
      assert message.user_id == user.id
      assert message.channel_id == channel.id
      assert message.metadata == metadata
      
      # Should update recent messages
      state = ChannelServer.get_channel_state(channel.id)
      assert length(state.recent_messages) == 1
      assert hd(state.recent_messages).content == content
      
      # Should update stats
      assert state.stats.messages_sent == 1
    end

    test "ignores messages from non-connected users", %{channel: channel} do
      other_user = insert(:user)
      
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:messages")
      
      ChannelServer.send_message(channel.id, other_user.id, "Hello!", %{})
      
      # Should not receive broadcast
      refute_receive {:new_message, _message}
      
      # Should not update messages or stats
      state = ChannelServer.get_channel_state(channel.id)
      assert state.recent_messages == []
      assert state.stats.messages_sent == 0
    end

    test "limits recent message history", %{channel: channel, user: user} do
      # Send more than history limit messages
      for i <- 1..105 do
        ChannelServer.send_message(channel.id, user.id, "Message #{i}", %{})
      end
      
      state = ChannelServer.get_channel_state(channel.id)
      assert length(state.recent_messages) == 100  # Should be limited to @message_history_limit
      
      # Should have most recent messages
      recent_message = hd(state.recent_messages)
      assert recent_message.content == "Message 105"
    end

    test "updates last activity when user sends message", %{channel: channel, user: user} do
      initial_state = ChannelServer.get_channel_state(channel.id)
      initial_activity = initial_state.connected_users[user.id].last_activity
      
      # Wait a bit then send message
      Process.sleep(10)
      ChannelServer.send_message(channel.id, user.id, "Test message", %{})
      
      updated_state = ChannelServer.get_channel_state(channel.id)
      updated_activity = updated_state.connected_users[user.id].last_activity
      
      assert DateTime.compare(updated_activity, initial_activity) == :gt
    end
  end

  describe "typing indicators" do
    setup do
      channel = insert(:channel)
      user1 = insert(:user)
      user2 = insert(:user)
      
      {:ok, _pid} = ChannelServer.start_link(channel.id)
      
      # Join users to channel
      expect(Channels, :can_access?, 2, fn _channel_id, _user_id -> true end)
      ChannelServer.join_channel(channel.id, user1.id, "socket_1")
      ChannelServer.join_channel(channel.id, user2.id, "socket_2")
      
      %{channel: channel, user1: user1, user2: user2}
    end

    test "tracks typing users", %{channel: channel, user1: user1, user2: user2} do
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:typing")
      
      # User1 starts typing
      ChannelServer.update_typing(channel.id, user1.id, true)
      
      state = ChannelServer.get_channel_state(channel.id)
      assert MapSet.member?(state.typing_users, user1.id)
      assert state.stats.typing_users == 1
      
      assert_receive {:typing_change, typing_users}
      assert user1.id in typing_users
      
      # User2 starts typing
      ChannelServer.update_typing(channel.id, user2.id, true)
      
      updated_state = ChannelServer.get_channel_state(channel.id)
      assert MapSet.member?(updated_state.typing_users, user1.id)
      assert MapSet.member?(updated_state.typing_users, user2.id)
      assert updated_state.stats.typing_users == 2
      
      assert_receive {:typing_change, typing_users}
      assert user1.id in typing_users
      assert user2.id in typing_users
    end

    test "removes typing status when user stops typing", %{channel: channel, user1: user1} do
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:typing")
      
      # Start typing
      ChannelServer.update_typing(channel.id, user1.id, true)
      assert_receive {:typing_change, _}
      
      # Stop typing
      ChannelServer.update_typing(channel.id, user1.id, false)
      
      state = ChannelServer.get_channel_state(channel.id)
      refute MapSet.member?(state.typing_users, user1.id)
      assert state.stats.typing_users == 0
      
      assert_receive {:typing_change, typing_users}
      refute user1.id in typing_users
    end

    test "automatically stops typing after timeout", %{channel: channel, user1: user1} do
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:typing")
      
      # Start typing
      ChannelServer.update_typing(channel.id, user1.id, true)
      assert_receive {:typing_change, _}
      
      # Wait for timeout (3 seconds + buffer)
      Process.sleep(3100)
      
      state = ChannelServer.get_channel_state(channel.id)
      refute MapSet.member?(state.typing_users, user1.id)
      assert state.stats.typing_users == 0
      
      assert_receive {:typing_change, typing_users}
      refute user1.id in typing_users
    end

    test "removes typing status when user sends message", %{channel: channel, user1: user1} do
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:typing")
      
      # Start typing
      ChannelServer.update_typing(channel.id, user1.id, true)
      assert_receive {:typing_change, _}
      
      # Send message
      ChannelServer.send_message(channel.id, user1.id, "Hello!", %{})
      
      state = ChannelServer.get_channel_state(channel.id)
      refute MapSet.member?(state.typing_users, user1.id)
      assert state.stats.typing_users == 0
      
      # Should broadcast typing stop
      assert_receive {:typing_change, typing_users}
      refute user1.id in typing_users
    end

    test "ignores typing updates from non-connected users", %{channel: channel} do
      other_user = insert(:user)
      
      PubSub.subscribe(SlackClone.PubSub, "channel:#{channel.id}:typing")
      
      ChannelServer.update_typing(channel.id, other_user.id, true)
      
      state = ChannelServer.get_channel_state(channel.id)
      refute MapSet.member?(state.typing_users, other_user.id)
      
      refute_receive {:typing_change, _}
    end
  end

  describe "state queries" do
    setup do
      channel = insert(:channel)
      user1 = insert(:user)
      user2 = insert(:user)
      
      {:ok, _pid} = ChannelServer.start_link(channel.id)
      
      %{channel: channel, user1: user1, user2: user2}
    end

    test "returns channel state", %{channel: channel} do
      state = ChannelServer.get_channel_state(channel.id)
      
      assert state.channel.id == channel.id
      assert is_map(state.connected_users)
      assert is_list(state.typing_users)
      assert is_map(state.stats)
    end

    test "returns connected users info", %{channel: channel, user1: user1} do
      expect(Channels, :can_access?, fn _channel_id, _user_id -> true end)
      
      ChannelServer.join_channel(channel.id, user1.id, "socket_1")
      
      users = ChannelServer.get_connected_users(channel.id)
      
      assert length(users) == 1
      user_info = hd(users)
      assert user_info.user_id == user1.id
      assert user_info.socket_count == 1
      assert is_struct(user_info.joined_at, DateTime)
      assert is_struct(user_info.last_activity, DateTime)
    end

    test "returns recent messages with limit", %{channel: channel, user1: user1} do
      expect(Channels, :can_access?, fn _channel_id, _user_id -> true end)
      ChannelServer.join_channel(channel.id, user1.id, "socket_1")
      
      # Send some messages
      for i <- 1..10 do
        ChannelServer.send_message(channel.id, user1.id, "Message #{i}", %{})
      end
      
      # Get limited messages
      messages = ChannelServer.get_recent_messages(channel.id, 5)
      assert length(messages) == 5
      
      # Should be most recent first
      first_message = hd(messages)
      assert first_message.content == "Message 10"
    end

    test "returns channel statistics", %{channel: channel, user1: user1, user2: user2} do
      expect(Channels, :can_access?, 2, fn _channel_id, _user_id -> true end)
      
      # Join users
      ChannelServer.join_channel(channel.id, user1.id, "socket_1") 
      ChannelServer.join_channel(channel.id, user2.id, "socket_2")
      
      # Send messages and start typing
      ChannelServer.send_message(channel.id, user1.id, "Hello!", %{})
      ChannelServer.update_typing(channel.id, user2.id, true)
      
      stats = ChannelServer.get_stats(channel.id)
      
      assert stats.connected_users == 2
      assert stats.messages_sent == 1
      assert stats.typing_users == 1
      assert is_struct(stats.last_message, DateTime)
      assert is_struct(stats.uptime, DateTime)
    end
  end

  describe "error handling" do
    test "handles invalid channel operations gracefully" do
      invalid_id = Ecto.UUID.generate()
      
      # These should not crash
      assert :ok == ChannelServer.join_channel(invalid_id, 1, "socket_1")
      assert :ok == ChannelServer.leave_channel(invalid_id, 1, "socket_1") 
      assert :ok == ChannelServer.send_message(invalid_id, 1, "test", %{})
      assert :ok == ChannelServer.update_typing(invalid_id, 1, true)
    end
  end
end