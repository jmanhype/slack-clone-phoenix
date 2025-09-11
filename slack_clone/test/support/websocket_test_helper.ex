defmodule SlackClone.WebSocketTestHelper do
  @moduledoc """
  Helper functions for WebSocket testing with proper authentication.
  """

  alias SlackClone.{Accounts, Guardian, Repo}
  alias SlackClone.Accounts.User

  @doc """
  Creates a test user and generates a valid JWT token for WebSocket connections.
  """
  def create_test_user_with_token(attrs \\ %{}) do
    user_attrs = Map.merge(%{
      email: "test#{System.unique_integer()}@example.com",
      password: "password123",
      name: "Test User"
    }, attrs)

    {:ok, user} = Accounts.register_user(user_attrs)
    {:ok, token, _claims} = Guardian.generate_jwt(user)
    
    {user, token}
  end

  @doc """
  Creates multiple test users with tokens for concurrent testing.
  """
  def create_test_users_with_tokens(count \\ 3) do
    1..count
    |> Enum.map(fn i ->
      create_test_user_with_token(%{
        email: "testuser#{i}@example.com",
        name: "Test User #{i}"
      })
    end)
  end

  @doc """
  Connects to WebSocket with proper authentication.
  """
  def connect_socket(token, user_id \\ nil, params \\ %{}) do
    socket_params = Map.merge(%{"token" => token}, params)
    
    case Phoenix.ChannelTest.connect(SlackCloneWeb.UserSocket, socket_params) do
      {:ok, socket} -> 
        if user_id do
          socket = Phoenix.Socket.assign(socket, :user_id, user_id)
        end
        {:ok, socket}
      error -> error
    end
  end

  @doc """
  Subscribes to a channel with authentication.
  """
  def join_channel(socket, channel, topic, payload \\ %{}) do
    Phoenix.ChannelTest.subscribe_and_join(socket, channel, topic, payload)
  end

  @doc """
  Creates test workspace and channels for testing.
  """
  def create_test_workspace_and_channels(user) do
    # For now, return mock data - in a real app this would create actual records
    workspace_id = "workspace_#{System.unique_integer()}"
    channel_id = "channel_#{System.unique_integer()}"
    
    %{
      workspace: %{id: workspace_id, name: "Test Workspace", user_id: user.id},
      channel: %{id: channel_id, name: "general", workspace_id: workspace_id}
    }
  end

  @doc """
  Clean up test data after tests.
  """
  def cleanup_test_data do
    # Delete test users created during tests
    Repo.delete_all(from u in User, where: like(u.email, "test%@example.com"))
  end

  @doc """
  Assert WebSocket message received within timeout.
  """
  def assert_websocket_message(expected_event, timeout \\ 1000) do
    assert_receive {^expected_event, _payload}, timeout
  end

  @doc """
  Push message to channel and assert response.
  """
  def push_and_assert(socket, event, payload, expected_reply \\ "ok", timeout \\ 1000) do
    ref = Phoenix.ChannelTest.push(socket, event, payload)
    assert_reply ref, ^expected_reply, _response, timeout
  end

  @doc """
  Test message broadcasting between multiple sockets.
  """
  def test_broadcast_between_sockets(sockets, channel_topic, event, payload) when is_list(sockets) do
    [first_socket | other_sockets] = sockets
    
    # Push from first socket
    Phoenix.ChannelTest.push(first_socket, event, payload)
    
    # Assert all other sockets receive the broadcast
    Enum.each(other_sockets, fn socket ->
      assert_broadcast ^event, ^payload, 1000
    end)
  end

  @doc """
  Performance test helper - measures WebSocket operation time.
  """
  def measure_websocket_performance(operation_fn) do
    start_time = System.monotonic_time(:microsecond)
    result = operation_fn.()
    end_time = System.monotonic_time(:microsecond)
    
    duration_ms = (end_time - start_time) / 1000
    {result, duration_ms}
  end

  @doc """
  Create multiple concurrent WebSocket connections for load testing.
  """
  def create_concurrent_connections(count, token_generator_fn \\ nil) do
    token_fn = token_generator_fn || fn -> 
      {_user, token} = create_test_user_with_token()
      token
    end

    1..count
    |> Task.async_stream(fn _i ->
      token = token_fn.()
      connect_socket(token)
    end, max_concurrency: count)
    |> Enum.map(fn {:ok, result} -> result end)
  end
end