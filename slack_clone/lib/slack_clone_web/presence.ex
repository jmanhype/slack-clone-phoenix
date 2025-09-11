defmodule SlackCloneWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and workspaces.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :slack_clone,
    pubsub_server: SlackClone.PubSub

  @doc """
  Track a user's presence in a workspace.
  """
  def track_user_in_workspace(workspace_id, user_id, user_data \\ %{}) do
    topic = "workspace:#{workspace_id}"
    key = "user:#{user_id}"
    
    payload = Map.merge(user_data, %{
      online_at: System.system_time(:second),
      user_id: user_id
    })
    
    track(self(), topic, key, payload)
  end

  @doc """
  Track a user's presence in a specific channel.
  """
  def track_user_in_channel(channel_id, user_id, user_data \\ %{}) do
    topic = "channel:#{channel_id}"
    key = "user:#{user_id}"
    
    payload = Map.merge(user_data, %{
      online_at: System.system_time(:second),
      user_id: user_id
    })
    
    track(self(), topic, key, payload)
  end

  @doc """
  Get the list of users present in a workspace.
  """
  def list_workspace_users(workspace_id) do
    topic = "workspace:#{workspace_id}"
    list(topic)
    |> Enum.map(fn {_key, %{metas: [meta | _]}} -> meta end)
  end

  @doc """
  Get the list of users present in a channel.
  """
  def list_channel_users(channel_id) do
    topic = "channel:#{channel_id}"
    list(topic)
    |> Enum.map(fn {_key, %{metas: [meta | _]}} -> meta end)
  end

  @doc """
  Update user status (e.g., typing indicator).
  """
  def update_user_status(workspace_id, user_id, status) do
    topic = "workspace:#{workspace_id}"
    key = "user:#{user_id}"
    
    update(self(), topic, key, fn meta ->
      Map.put(meta, :status, status)
    end)
  end

  @doc """
  Check if a user is online in a workspace.
  """
  def user_online?(workspace_id, user_id) do
    topic = "workspace:#{workspace_id}"
    key = "user:#{user_id}"
    
    case get_by_key(topic, key) do
      [] -> false
      _ -> true
    end
  end
end