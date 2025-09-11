defmodule SlackCloneWeb.UserSocket do
  @moduledoc """
  Main WebSocket handler for real-time communication.
  Handles authentication and channel routing for workspace and channel communications.
  """
  use Phoenix.Socket

  # Socket channels
  channel "workspace:*", SlackCloneWeb.WorkspaceChannel
  channel "channel:*", SlackCloneWeb.ChannelChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case verify_user_token(token) do
      {:ok, user} ->
        socket = 
          socket
          |> assign(:current_user, user)
          |> assign(:user_id, user.id)
        
        {:ok, socket}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  # Socket IDs are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.SlackCloneWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  # Private helper functions
  
  defp verify_user_token(token) do
    case Phoenix.Token.verify(SlackCloneWeb.Endpoint, "user socket", token, max_age: 86400) do
      {:ok, user_id} ->
        # Load user from database
        case load_user(user_id) do
          nil -> {:error, :user_not_found}
          user -> {:ok, user}
        end

      {:error, _reason} ->
        {:error, :invalid_token}
    end
  end

  defp load_user(user_id) do
    # Load user from database using Accounts context
    try do
      SlackClone.Accounts.get_user!(user_id)
    rescue
      Ecto.NoResultsError -> nil
    end
  end
end