defmodule SlackClone.Services.PresenceTrackerTest do
  use SlackClone.DataCase
  use ExMachina

  import SlackClone.Factory

  alias SlackClone.Services.PresenceTracker
  alias Phoenix.PubSub

  describe "GenServer lifecycle" do
    test "starts successfully with initial state" do
      assert {:ok, pid} = PresenceTracker.start_link()
      assert Process.alive?(pid)
      
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 0
      assert stats.away_users == 0
      assert stats.total_connections == 0
    end

    test "handles restart gracefully" do
      {:ok, pid1} = PresenceTracker.start_link()
      user = insert(:user)
      
      # Set user online
      PresenceTracker.user_online(user.id, "socket_1")
      
      # Kill and restart
      Process.exit(pid1, :kill)
      {:ok, _pid2} = PresenceTracker.start_link()
      
      # State should be reset
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 0
    end
  end

  describe "user online/offline tracking" do
    setup do
      {:ok, _pid} = PresenceTracker.start_link()
      user1 = insert(:user)
      user2 = insert(:user)
      
      %{user1: user1, user2: user2}
    end

    test "tracks user online status", %{user1: user1} do
      # Subscribe to presence updates
      PubSub.subscribe(SlackClone.PubSub, "presence:updates")
      
      metadata = %{"device" => "web", "location" => "NYC"}
      PresenceTracker.user_online(user1.id, "socket_1", metadata)
      
      # Should broadcast presence change
      assert_receive {:presence_diff, %{^user1.id => %{status: :online, metadata: ^metadata}}}
      
      # Should update stats
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 1
      assert stats.total_connections == 1
      
      # Should return correct presence
      presence = PresenceTracker.get_presence(user1.id)
      assert presence.status == :online
      assert presence.user_id == user1.id
      assert presence.metadata == metadata
      assert "socket_1" in presence.sockets
    end

    test "tracks multiple sockets for same user", %{user1: user1} do
      PresenceTracker.user_online(user1.id, "socket_1")
      PresenceTracker.user_online(user1.id, "socket_2")
      
      presence = PresenceTracker.get_presence(user1.id)
      assert length(presence.sockets) == 2
      assert "socket_1" in presence.sockets
      assert "socket_2" in presence.sockets
      
      # Should still count as one user
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 1
      assert stats.total_connections == 2
    end

    test "removes user when all sockets disconnect", %{user1: user1} do
      PubSub.subscribe(SlackClone.PubSub, "presence:updates")
      
      PresenceTracker.user_online(user1.id, "socket_1")
      PresenceTracker.user_online(user1.id, "socket_2")
      
      # Remove one socket
      PresenceTracker.user_offline(user1.id, "socket_1")
      
      presence = PresenceTracker.get_presence(user1.id)
      assert length(presence.sockets) == 1
      assert "socket_2" in presence.sockets
      
      # Remove last socket
      PresenceTracker.user_offline(user1.id, "socket_2")
      
      # Should broadcast offline
      assert_receive {:presence_diff, %{^user1.id => %{status: :offline}}}
      
      # Should remove from tracking
      presence = PresenceTracker.get_presence(user1.id)
      assert presence.status == :offline
      
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 0
      assert stats.total_connections == 0
    end

    test "handles user going offline without socket ID", %{user1: user1} do
      PubSub.subscribe(SlackClone.PubSub, "presence:updates")
      
      PresenceTracker.user_online(user1.id, "socket_1")
      PresenceTracker.user_offline(user1.id)  # No socket ID
      
      # Should remove all sockets and set offline
      assert_receive {:presence_diff, %{^user1.id => %{status: :offline}}}
      
      presence = PresenceTracker.get_presence(user1.id)
      assert presence.status == :offline
    end
  end

  describe "away status handling" do
    setup do
      {:ok, _pid} = PresenceTracker.start_link()
      user = insert(:user)
      
      %{user: user}
    end

    test "transitions user to away status", %{user: user} do
      PubSub.subscribe(SlackClone.PubSub, "presence:updates")
      
      PresenceTracker.user_online(user.id, "socket_1")
      assert_receive {:presence_diff, %{^user.id => %{status: :online}}}
      
      PresenceTracker.user_away(user.id)
      
      # Should broadcast away status
      assert_receive {:presence_diff, %{^user.id => %{status: :away}}}
      
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :away
      
      # Should update stats
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 0
      assert stats.away_users == 1
    end

    test "automatically transitions from online to away after timeout", %{user: user} do
      PubSub.subscribe(SlackClone.PubSub, "presence:updates")
      
      PresenceTracker.user_online(user.id, "socket_1")
      assert_receive {:presence_diff, %{^user.id => %{status: :online}}}
      
      # Wait for away timeout (5 minutes in production, but test with shorter timeout)
      # We'll trigger it manually for testing
      send(PresenceTracker, {:set_user_away, user.id})
      
      assert_receive {:presence_diff, %{^user.id => %{status: :away}}}
      
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :away
    end

    test "automatically transitions from away to offline after timeout", %{user: user} do
      PubSub.subscribe(SlackClone.PubSub, "presence:updates")
      
      PresenceTracker.user_online(user.id, "socket_1")
      PresenceTracker.user_away(user.id)
      
      # Clear the online message
      assert_receive {:presence_diff, %{^user.id => %{status: :online}}}
      assert_receive {:presence_diff, %{^user.id => %{status: :away}}}
      
      # Trigger offline timeout
      send(PresenceTracker, {:set_user_offline, user.id})
      
      assert_receive {:presence_diff, %{^user.id => %{status: :offline}}}
      
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :offline
      
      stats = PresenceTracker.get_stats()
      assert stats.away_users == 0
      assert stats.online_users == 0
    end

    test "resets to online when user becomes active again", %{user: user} do
      PubSub.subscribe(SlackClone.PubSub, "presence:updates")
      
      PresenceTracker.user_online(user.id, "socket_1")
      PresenceTracker.user_away(user.id)
      
      # Clear existing messages
      assert_receive {:presence_diff, %{^user.id => %{status: :online}}}
      assert_receive {:presence_diff, %{^user.id => %{status: :away}}}
      
      # User becomes active again
      new_metadata = %{"activity" => "typing"}
      PresenceTracker.user_online(user.id, "socket_1", new_metadata)
      
      assert_receive {:presence_diff, %{^user.id => %{status: :online, metadata: ^new_metadata}}}
      
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :online
      assert presence.metadata == new_metadata
      
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 1
      assert stats.away_users == 0
    end
  end

  describe "workspace presence" do
    setup do
      {:ok, _pid} = PresenceTracker.start_link()
      workspace = insert(:workspace)
      user1 = insert(:user)
      user2 = insert(:user)
      
      %{workspace: workspace, user1: user1, user2: user2}
    end

    test "filters presence by workspace", %{workspace: workspace, user1: user1, user2: user2} do
      # Set users online
      PresenceTracker.user_online(user1.id, "socket_1")
      PresenceTracker.user_online(user2.id, "socket_2")
      
      # Get workspace presence (for now returns all - would need workspace membership logic)
      presence = PresenceTracker.get_workspace_presence(workspace.id)
      
      assert Map.has_key?(presence, user1.id)
      assert Map.has_key?(presence, user2.id)
      
      assert presence[user1.id].status == :online
      assert presence[user2.id].status == :online
    end
  end

  describe "presence cleanup" do
    setup do
      {:ok, _pid} = PresenceTracker.start_link()
      user = insert(:user)
      
      %{user: user}
    end

    test "cleans up stale presences periodically", %{user: user} do
      PubSub.subscribe(SlackClone.PubSub, "presence:updates")
      
      PresenceTracker.user_online(user.id, "socket_1")
      assert_receive {:presence_diff, %{^user.id => %{status: :online}}}
      
      # Trigger cleanup manually
      send(PresenceTracker, :cleanup_stale_presences)
      
      # Since the presence was just created, it shouldn't be cleaned up
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :online
      
      # Update stats to simulate cleanup
      stats = PresenceTracker.get_stats()
      assert is_struct(stats.last_cleanup, DateTime)
    end

    test "removes stale connections during cleanup", %{user: user} do
      PubSub.subscribe(SlackClone.PubSub, "presence:updates")
      
      # Manually create a stale presence (this would normally be done by the cleanup process)
      PresenceTracker.user_online(user.id, "socket_1")
      assert_receive {:presence_diff, %{^user.id => %{status: :online}}}
      
      # Simulate stale timeout by sending offline event
      send(PresenceTracker, {:set_user_offline, user.id})
      
      assert_receive {:presence_diff, %{^user.id => %{status: :offline}}}
    end
  end

  describe "statistics tracking" do
    setup do
      {:ok, _pid} = PresenceTracker.start_link()
      user1 = insert(:user)
      user2 = insert(:user)
      user3 = insert(:user)
      
      %{user1: user1, user2: user2, user3: user3}
    end

    test "tracks accurate user counts", %{user1: user1, user2: user2, user3: user3} do
      # All users online
      PresenceTracker.user_online(user1.id, "socket_1")
      PresenceTracker.user_online(user2.id, "socket_2")
      PresenceTracker.user_online(user3.id, "socket_3")
      
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 3
      assert stats.away_users == 0
      assert stats.total_connections == 3
      
      # One user away
      PresenceTracker.user_away(user2.id)
      
      updated_stats = PresenceTracker.get_stats()
      assert updated_stats.online_users == 2
      assert updated_stats.away_users == 1
      assert updated_stats.total_connections == 3
      
      # One user offline
      PresenceTracker.user_offline(user3.id, "socket_3")
      
      final_stats = PresenceTracker.get_stats()
      assert final_stats.online_users == 1
      assert final_stats.away_users == 1
      assert final_stats.total_connections == 2
    end

    test "counts multiple connections per user correctly", %{user1: user1} do
      # User with multiple connections
      PresenceTracker.user_online(user1.id, "socket_1")
      PresenceTracker.user_online(user1.id, "socket_2")
      PresenceTracker.user_online(user1.id, "socket_3")
      
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 1
      assert stats.total_connections == 3
    end
  end

  describe "edge cases and error handling" do
    setup do
      {:ok, _pid} = PresenceTracker.start_link()
      user = insert(:user)
      
      %{user: user}
    end

    test "handles duplicate online requests", %{user: user} do
      PresenceTracker.user_online(user.id, "socket_1")
      PresenceTracker.user_online(user.id, "socket_1")  # Duplicate
      
      presence = PresenceTracker.get_presence(user.id)
      assert length(presence.sockets) == 1  # Should not duplicate socket
      
      stats = PresenceTracker.get_stats()
      assert stats.total_connections == 1
    end

    test "handles away request for non-existent user", %{user: user} do
      # User not online, try to set away
      PresenceTracker.user_away(user.id)
      
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :offline
      
      stats = PresenceTracker.get_stats()
      assert stats.away_users == 0
    end

    test "handles offline request for non-existent user", %{user: user} do
      # User not online, try to set offline
      PresenceTracker.user_offline(user.id, "socket_1")
      
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :offline
      
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 0
    end

    test "handles timer messages for non-existent users", %{user: user} do
      # Send timer message for user who isn't tracked
      send(PresenceTracker, {:set_user_away, user.id})
      send(PresenceTracker, {:set_user_offline, user.id})
      
      # Should not crash
      assert Process.alive?(Process.whereis(PresenceTracker))
      
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :offline
    end
  end

  describe "concurrency and race conditions" do
    setup do
      {:ok, _pid} = PresenceTracker.start_link()
      user = insert(:user)
      
      %{user: user}
    end

    test "handles rapid online/offline cycling", %{user: user} do
      # Rapidly cycle online/offline
      for _ <- 1..10 do
        PresenceTracker.user_online(user.id, "socket_1")
        PresenceTracker.user_offline(user.id, "socket_1")
      end
      
      # Should end up offline
      presence = PresenceTracker.get_presence(user.id)
      assert presence.status == :offline
      
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 0
    end

    test "handles multiple concurrent socket connections", %{user: user} do
      # Add multiple sockets concurrently
      tasks = for i <- 1..10 do
        Task.async(fn ->
          PresenceTracker.user_online(user.id, "socket_#{i}")
        end)
      end
      
      # Wait for all tasks
      Task.await_many(tasks)
      
      presence = PresenceTracker.get_presence(user.id)
      assert length(presence.sockets) == 10
      
      stats = PresenceTracker.get_stats()
      assert stats.online_users == 1
      assert stats.total_connections == 10
    end
  end
end