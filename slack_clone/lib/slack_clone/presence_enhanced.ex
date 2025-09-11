defmodule SlackClone.PresenceEnhanced do
  @moduledoc """
  Enhanced presence system with custom status, typing indicators, and history tracking.
  """

  import Ecto.Query, warn: false
  alias SlackClone.Repo
  alias SlackClone.PresenceEnhanced.{UserStatus, PresenceHistory, TypingIndicator, UserActivitySummary}
  alias SlackClone.Accounts.User
  alias SlackClone.Channels.Channel

  ## User Status Management

  @doc """
  Sets or updates a user's custom status.
  """
  def set_user_status(user_id, attrs \\ %{}) do
    case get_user_status(user_id) do
      nil ->
        %UserStatus{user_id: user_id}
        |> UserStatus.changeset(attrs)
        |> Repo.insert()
      
      existing_status ->
        existing_status
        |> UserStatus.changeset(attrs)
        |> Repo.update()
    end
    |> case do
      {:ok, status} ->
        # Broadcast status change
        broadcast_status_change(user_id, status)
        {:ok, status}
      
      error -> error
    end
  end

  @doc """
  Gets a user's current status.
  """
  def get_user_status(user_id) do
    UserStatus
    |> where([us], us.user_id == ^user_id)
    |> preload([:user])
    |> Repo.one()
  end

  @doc """
  Sets a user's DND (Do Not Disturb) status.
  """
  def set_dnd_status(user_id, is_dnd, until \\ nil) do
    attrs = %{is_dnd: is_dnd, dnd_until: until}
    set_user_status(user_id, attrs)
  end

  @doc """
  Clears expired custom statuses.
  """
  def clear_expired_statuses do
    now = DateTime.utc_now()
    
    UserStatus
    |> where([us], not is_nil(us.expires_at) and us.expires_at <= ^now)
    |> Repo.update_all(set: [
      custom_status: nil,
      status_emoji: nil,
      expires_at: nil,
      updated_at: now
    ])
  end

  @doc """
  Gets all users' statuses in a workspace.
  """
  def list_workspace_user_statuses(workspace_id) do
    UserStatus
    |> join(:inner, [us], u in User, on: u.id == us.user_id)
    |> join(:inner, [us, u], wm in "workspace_memberships", on: wm.user_id == u.id)
    |> where([us, u, wm], wm.workspace_id == ^workspace_id)
    |> preload([us, u], [user: u])
    |> Repo.all()
  end

  ## Typing Indicators

  @doc """
  Sets a typing indicator for a user in a channel or thread.
  """
  def set_typing_indicator(user_id, channel_id, thread_id \\ nil) do
    expires_at = DateTime.utc_now() |> DateTime.add(10, :second) # 10 second timeout

    %TypingIndicator{
      user_id: user_id,
      channel_id: channel_id,
      thread_id: thread_id,
      expires_at: expires_at
    }
    |> TypingIndicator.changeset(%{})
    |> Repo.insert(
      on_conflict: [set: [
        last_activity_at: DateTime.utc_now(),
        expires_at: expires_at,
        is_active: true,
        updated_at: DateTime.utc_now()
      ]],
      conflict_target: [:user_id, :channel_id, :thread_id]
    )
    |> case do
      {:ok, indicator} ->
        # Broadcast typing indicator
        broadcast_typing_indicator(indicator)
        {:ok, indicator}
      
      error -> error
    end
  end

  @doc """
  Stops a typing indicator for a user.
  """
  def stop_typing_indicator(user_id, channel_id, thread_id \\ nil) do
    TypingIndicator
    |> where([ti], ti.user_id == ^user_id and ti.channel_id == ^channel_id)
    |> where([ti], ti.thread_id == ^thread_id or (is_nil(^thread_id) and is_nil(ti.thread_id)))
    |> Repo.update_all(set: [is_active: false, updated_at: DateTime.utc_now()])

    # Broadcast typing stopped
    broadcast_typing_stopped(user_id, channel_id, thread_id)
  end

  @doc """
  Gets current typing indicators for a channel or thread.
  """
  def list_typing_indicators(channel_id, thread_id \\ nil) do
    now = DateTime.utc_now()

    TypingIndicator
    |> where([ti], ti.channel_id == ^channel_id)
    |> where([ti], ti.thread_id == ^thread_id or (is_nil(^thread_id) and is_nil(ti.thread_id)))
    |> where([ti], ti.is_active == true)
    |> where([ti], ti.expires_at > ^now)
    |> preload([:user])
    |> Repo.all()
  end

  @doc """
  Cleans up expired typing indicators.
  """
  def cleanup_expired_typing_indicators do
    now = DateTime.utc_now()
    
    TypingIndicator
    |> where([ti], ti.expires_at <= ^now or ti.is_active == false)
    |> Repo.delete_all()
  end

  ## Presence History Tracking

  @doc """
  Starts tracking presence for a user session.
  """
  def start_presence_session(user_id, workspace_id, opts \\ []) do
    session_id = Keyword.get(opts, :session_id, UUID.uuid4())
    device_type = Keyword.get(opts, :device_type, "web")
    user_agent = Keyword.get(opts, :user_agent)
    ip_address = Keyword.get(opts, :ip_address)

    %PresenceHistory{
      user_id: user_id,
      status: "online",
      session_id: session_id,
      device_type: device_type,
      user_agent: user_agent,
      ip_address: ip_address,
      changed_at: DateTime.utc_now(),
      is_online: true
    }
    |> PresenceHistory.changeset(%{})
    |> Repo.insert()
  end

  @doc """
  Ends a presence session.
  """
  def end_presence_session(session_id) do
    now = DateTime.utc_now()
    
    case get_active_presence_session(session_id) do
      nil -> {:error, :session_not_found}
      session ->
        duration = DateTime.diff(now, session.started_at, :second)
        
        session
        |> PresenceHistory.changeset(%{
          ended_at: now,
          duration_seconds: duration
        })
        |> Repo.update()
    end
  end

  @doc """
  Updates presence status for an active session.
  """
  def update_presence_status(session_id, status) do
    PresenceHistory
    |> where([ph], ph.session_id == ^session_id and is_nil(ph.ended_at))
    |> Repo.update_all(set: [status: status, updated_at: DateTime.utc_now()])
  end

  @doc """
  Gets presence statistics for a user.
  """
  def get_user_presence_stats(user_id, workspace_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    start_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    # Total time online
    total_online_time = 
      PresenceHistory
      |> where([ph], ph.user_id == ^user_id and ph.workspace_id == ^workspace_id)
      |> where([ph], ph.started_at > ^start_date)
      |> where([ph], not is_nil(ph.duration_seconds))
      |> Repo.aggregate(:sum, :duration_seconds) || 0

    # Session count
    session_count = 
      PresenceHistory
      |> where([ph], ph.user_id == ^user_id and ph.workspace_id == ^workspace_id)
      |> where([ph], ph.started_at > ^start_date)
      |> Repo.aggregate(:count)

    # Device breakdown
    device_stats = 
      PresenceHistory
      |> where([ph], ph.user_id == ^user_id and ph.workspace_id == ^workspace_id)
      |> where([ph], ph.started_at > ^start_date)
      |> group_by([ph], ph.device_type)
      |> select([ph], %{device_type: ph.device_type, count: count(ph.id)})
      |> Repo.all()
      |> Enum.into(%{}, fn %{device_type: type, count: count} -> {type, count} end)

    %{
      total_online_seconds: total_online_time,
      session_count: session_count,
      device_breakdown: device_stats,
      average_session_length: if(session_count > 0, do: div(total_online_time, session_count), else: 0)
    }
  end

  @doc """
  Gets workspace presence analytics.
  """
  def get_workspace_presence_analytics(workspace_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    start_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    # Active users by day
    daily_active_users = 
      PresenceHistory
      |> where([ph], ph.workspace_id == ^workspace_id)
      |> where([ph], ph.started_at > ^start_date)
      |> group_by([ph], fragment("DATE(?)", ph.started_at))
      |> select([ph], %{
        date: fragment("DATE(?)", ph.started_at),
        unique_users: count(ph.user_id, :distinct)
      })
      |> order_by([ph], asc: fragment("DATE(?)", ph.started_at))
      |> Repo.all()

    # Peak concurrent users (approximation)
    peak_users = 
      PresenceHistory
      |> where([ph], ph.workspace_id == ^workspace_id)
      |> where([ph], ph.started_at > ^start_date)
      |> where([ph], not is_nil(ph.duration_seconds))
      |> Repo.all()
      |> calculate_peak_concurrent_users()

    # Device type distribution
    device_distribution = 
      PresenceHistory
      |> where([ph], ph.workspace_id == ^workspace_id)
      |> where([ph], ph.started_at > ^start_date)
      |> group_by([ph], ph.device_type)
      |> select([ph], %{device_type: ph.device_type, sessions: count(ph.id)})
      |> Repo.all()

    %{
      daily_active_users: daily_active_users,
      peak_concurrent_users: peak_users,
      device_distribution: device_distribution
    }
  end

  ## User Activity Summary

  @doc """
  Updates daily activity summary for a user.
  """
  def update_user_activity_summary(user_id, workspace_id, activity_data) do
    date = Date.utc_today()
    
    %UserActivitySummary{
      user_id: user_id,
      summary_date: date,
      summary_type: "daily"
    }
    |> UserActivitySummary.changeset(activity_data)
    |> Repo.insert(
      on_conflict: [inc: [
        total_online_seconds: activity_data.total_online_seconds || 0,
        messages_sent: activity_data.messages_sent || 0,
        channels_visited: activity_data.channels_visited || 0,
        threads_participated: activity_data.threads_participated || 0,
        reactions_given: activity_data.reactions_given || 0,
        files_shared: activity_data.files_shared || 0
      ]],
      conflict_target: [:user_id, :summary_date]
    )
  end

  ## Private Functions

  defp get_active_presence_session(session_id) do
    PresenceHistory
    |> where([ph], ph.session_id == ^session_id and is_nil(ph.ended_at))
    |> Repo.one()
  end

  defp broadcast_status_change(user_id, status) do
    SlackCloneWeb.Endpoint.broadcast("presence:user:#{user_id}", "status_changed", %{
      user_id: user_id,
      status: status.status,
      custom_status: status.custom_status,
      status_emoji: status.status_emoji,
      is_dnd: status.is_dnd
    })
  end

  defp broadcast_typing_indicator(indicator) do
    topic = if indicator.thread_id do
      "typing:thread:#{indicator.thread_id}"
    else
      "typing:channel:#{indicator.channel_id}"
    end

    SlackCloneWeb.Endpoint.broadcast(topic, "user_typing", %{
      user_id: indicator.user_id,
      channel_id: indicator.channel_id,
      thread_id: indicator.thread_id
    })
  end

  defp broadcast_typing_stopped(user_id, channel_id, thread_id) do
    topic = if thread_id do
      "typing:thread:#{thread_id}"
    else
      "typing:channel:#{channel_id}"
    end

    SlackCloneWeb.Endpoint.broadcast(topic, "user_stopped_typing", %{
      user_id: user_id,
      channel_id: channel_id,
      thread_id: thread_id
    })
  end

  defp calculate_peak_concurrent_users(sessions) do
    # This is a simplified calculation
    # In production, you might want a more sophisticated approach
    sessions
    |> Enum.map(fn session ->
      start_time = session.started_at
      end_time = session.ended_at || DateTime.add(start_time, session.duration_seconds || 0, :second)
      {start_time, end_time}
    end)
    |> Enum.flat_map(fn {start_time, end_time} ->
      [{start_time, 1}, {end_time, -1}]
    end)
    |> Enum.sort_by(fn {time, _} -> time end)
    |> Enum.reduce({0, 0}, fn {_time, delta}, {current, max} ->
      new_current = current + delta
      {new_current, max(max, new_current)}
    end)
    |> elem(1)
  end
end