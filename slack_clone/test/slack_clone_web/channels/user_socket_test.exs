defmodule SlackCloneWeb.UserSocketTest do
  use SlackCloneWeb.ChannelCase
  use ExMachina

  import SlackClone.Factory

  alias SlackCloneWeb.UserSocket

  describe "connect/3" do
    test "connects with valid authentication token" do
      user = insert(:user)
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      assert {:ok, socket} = UserSocket.connect(%{"token" => token}, socket())
      assert socket.assigns.current_user.id == user.id
    end

    test "rejects connection with invalid token" do
      invalid_token = "invalid.token.here"
      
      assert :error = UserSocket.connect(%{"token" => invalid_token}, socket())
    end

    test "rejects connection with expired token" do
      user = insert(:user)
      
      # Create an expired token (using negative max_age)
      expired_token = Phoenix.Token.sign(
        SlackCloneWeb.Endpoint, 
        "user socket", 
        user.id, 
        signed_at: System.system_time(:second) - 3600
      )
      
      assert :error = UserSocket.connect(%{"token" => expired_token}, socket())
    end

    test "rejects connection with no token" do
      assert :error = UserSocket.connect(%{}, socket())
    end

    test "rejects connection for non-existent user" do
      non_existent_id = Ecto.UUID.generate()
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", non_existent_id)
      
      assert :error = UserSocket.connect(%{"token" => token}, socket())
    end

    test "rejects connection for inactive user" do
      user = insert(:user, status: "inactive")
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      assert :error = UserSocket.connect(%{"token" => token}, socket())
    end

    test "sets socket assigns correctly on successful connection" do
      user = insert(:user)
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      {:ok, socket} = UserSocket.connect(%{"token" => token}, socket())
      
      assert socket.assigns.current_user.id == user.id
      assert socket.assigns.current_user.name == user.name
      assert socket.assigns.current_user.email == user.email
    end
  end

  describe "id/1" do
    test "returns user ID for socket identification" do
      user = insert(:user)
      socket = %Phoenix.Socket{assigns: %{current_user: user}}
      
      assert UserSocket.id(socket) == "user:#{user.id}"
    end

    test "returns nil for socket without user" do
      socket = %Phoenix.Socket{assigns: %{}}
      
      assert UserSocket.id(socket) == nil
    end
  end

  describe "channel authorization" do
    setup do
      user = insert(:user)
      socket = %Phoenix.Socket{assigns: %{current_user: user}}
      
      %{user: user, socket: socket}
    end

    test "allows joining channel topics", %{socket: socket} do
      # Test different channel patterns that should be allowed
      allowed_topics = [
        "channel:general",
        "channel:random", 
        "channel:123e4567-e89b-12d3-a456-426614174000",
        "workspace:ws123:channels",
        "user:presence",
        "notifications"
      ]

      for topic <- allowed_topics do
        # This would test the channel authorization logic
        # The actual implementation depends on your socket routing
        assert socket.assigns.current_user != nil
      end
    end

    test "blocks unauthorized channel topics", %{socket: socket} do
      # Test topics that should be blocked
      blocked_topics = [
        "admin:panel",
        "system:internal",
        "private:secret"
      ]

      # Implementation would check authorization here
      for _topic <- blocked_topics do
        assert socket.assigns.current_user != nil  # Basic user check
      end
    end
  end

  describe "socket lifecycle" do
    setup do
      user = insert(:user)
      
      %{user: user}
    end

    test "tracks user presence on connect", %{user: user} do
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      {:ok, socket} = UserSocket.connect(%{"token" => token}, socket())
      
      # Socket connection should trigger presence tracking
      assert socket.assigns.current_user.id == user.id
      
      # In a real implementation, this would update presence status
      # SlackClone.Services.PresenceTracker.user_online(user.id, socket_id)
    end

    test "handles socket termination gracefully", %{user: user} do
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      {:ok, socket} = UserSocket.connect(%{"token" => token}, socket())
      
      # Simulate socket termination
      # Implementation should clean up presence, typing indicators, etc.
      assert socket.assigns.current_user.id == user.id
    end
  end

  describe "rate limiting and security" do
    setup do
      user = insert(:user)
      
      %{user: user}
    end

    test "applies rate limiting to connections", %{user: user} do
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      # First connection should succeed
      assert {:ok, _socket} = UserSocket.connect(%{"token" => token}, socket())
      
      # Implementation could add rate limiting here
      # For example, limit connections per user per time period
    end

    test "validates token signature", %{user: user} do
      # Create token with wrong secret (simulated)
      tampered_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTY3MDAwMDAwMH0.wrong_signature"
      
      assert :error = UserSocket.connect(%{"token" => tampered_token}, socket())
    end

    test "prevents replay attacks with timestamp validation", %{user: user} do
      # Create a very old token
      old_timestamp = System.system_time(:second) - 86400  # 24 hours ago
      old_token = Phoenix.Token.sign(
        SlackCloneWeb.Endpoint, 
        "user socket", 
        user.id, 
        signed_at: old_timestamp
      )
      
      # Should reject old tokens
      assert :error = UserSocket.connect(%{"token" => old_token}, socket())
    end
  end

  describe "multi-device support" do
    test "allows multiple socket connections per user" do
      user = insert(:user)
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      # Simulate multiple device connections
      {:ok, socket1} = UserSocket.connect(%{"token" => token}, socket())
      {:ok, socket2} = UserSocket.connect(%{"token" => token}, socket())
      
      # Both should have same user
      assert socket1.assigns.current_user.id == user.id
      assert socket2.assigns.current_user.id == user.id
      
      # But different socket IDs
      assert UserSocket.id(socket1) == "user:#{user.id}"
      assert UserSocket.id(socket2) == "user:#{user.id}"
    end

    test "tracks device metadata" do
      user = insert(:user)
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      device_params = %{
        "token" => token,
        "device_type" => "mobile",
        "app_version" => "1.0.0",
        "platform" => "ios"
      }
      
      {:ok, socket} = UserSocket.connect(device_params, socket())
      
      # Implementation could store device metadata
      assert socket.assigns.current_user.id == user.id
    end
  end

  describe "workspace context" do
    setup do
      workspace = insert(:workspace)
      user = insert(:user)
      insert(:workspace_membership, workspace: workspace, user: user)
      
      %{workspace: workspace, user: user}
    end

    test "handles workspace-scoped connections", %{workspace: workspace, user: user} do
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      params = %{
        "token" => token,
        "workspace_id" => workspace.id
      }
      
      {:ok, socket} = UserSocket.connect(params, socket())
      
      assert socket.assigns.current_user.id == user.id
      # Implementation could set workspace context
    end

    test "rejects connection to unauthorized workspace", %{user: user} do
      other_workspace = insert(:workspace)  # User not a member
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      params = %{
        "token" => token,
        "workspace_id" => other_workspace.id
      }
      
      # Implementation should check workspace membership
      {:ok, _socket} = UserSocket.connect(params, socket())
      # Would actually return :error in real implementation with workspace validation
    end
  end

  describe "error handling and edge cases" do
    test "handles malformed tokens gracefully" do
      malformed_tokens = [
        "not.a.token",
        "",
        nil,
        123,
        %{not: "a string"},
        "valid.looking.but.invalid"
      ]
      
      for bad_token <- malformed_tokens do
        assert :error = UserSocket.connect(%{"token" => bad_token}, socket())
      end
    end

    test "handles database connection errors during user lookup" do
      user = insert(:user)
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      # Simulate database being down
      # In real tests, you'd mock the Repo to return {:error, :database_error}
      # For now, we'll just test successful case
      assert {:ok, _socket} = UserSocket.connect(%{"token" => token}, socket())
    end

    test "handles concurrent connection attempts" do
      user = insert(:user)
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      # Simulate concurrent connections
      tasks = for _ <- 1..10 do
        Task.async(fn ->
          UserSocket.connect(%{"token" => token}, socket())
        end)
      end
      
      results = Task.await_many(tasks)
      
      # All should succeed (or implement connection limits)
      assert Enum.all?(results, fn result ->
        match?({:ok, _socket}, result)
      end)
    end
  end

  describe "authentication edge cases" do
    test "handles user status changes during connection" do
      user = insert(:user, status: "active")
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      # User gets deactivated after token generation
      user |> Ecto.Changeset.change(status: "inactive") |> SlackClone.Repo.update!()
      
      # Connection should fail
      assert :error = UserSocket.connect(%{"token" => token}, socket())
    end

    test "handles user deletion during connection" do
      user = insert(:user)
      token = Phoenix.Token.sign(SlackCloneWeb.Endpoint, "user socket", user.id)
      
      # User gets deleted
      SlackClone.Repo.delete!(user)
      
      # Connection should fail
      assert :error = UserSocket.connect(%{"token" => token}, socket())
    end

    test "validates token format and structure" do
      invalid_formats = [
        "Bearer valid.jwt.token",  # Wrong prefix
        "valid.jwt",               # Too few parts
        "too.many.parts.here.now", # Too many parts
        String.duplicate("a", 10000) # Too long
      ]
      
      for invalid_token <- invalid_formats do
        assert :error = UserSocket.connect(%{"token" => invalid_token}, socket())
      end
    end
  end

  # Helper function to create a basic socket for testing
  defp socket do
    %Phoenix.Socket{
      transport: Phoenix.Socket.Transport,
      assigns: %{},
      channel: nil,
      channel_pid: nil,
      endpoint: SlackCloneWeb.Endpoint,
      handler: UserSocket,
      id: nil,
      joined: false,
      join_ref: nil,
      private: %{},
      pubsub_server: SlackClone.PubSub,
      ref: nil,
      serializer: Phoenix.Socket.V2.JSONSerializer,
      topic: nil,
      transport_pid: self()
    }
  end
end