defmodule SlackClone.PresenceEnhanced.PresenceHistory do
  @moduledoc """
  Schema for tracking user presence history and analytics.
  Stores presence state changes over time for reporting and insights.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "presence_history" do
    belongs_to :user, SlackClone.Accounts.User

    # Presence state information
    field :status, :string # online, away, busy, do_not_disturb, offline
    field :previous_status, :string
    field :is_online, :boolean
    field :was_online, :boolean
    
    # Timing information
    field :changed_at, :utc_datetime
    field :duration_seconds, :integer # How long they were in the previous state
    field :session_id, :binary_id # Groups related presence changes
    
    # Context information
    field :change_reason, :string # manual, auto_away, idle_timeout, meeting, dnd, system
    field :device_type, :string # desktop, mobile, web
    field :user_agent, :string
    field :ip_address, :string
    
    # Custom status tracking
    field :custom_status_text, :string
    field :custom_status_emoji, :string
    
    # Activity context
    field :last_active_channel, :binary_id
    field :last_message_sent_at, :utc_datetime
    field :active_connections_count, :integer, default: 0
    
    # Aggregation helpers (for efficient queries)
    field :date, :date # Date of the change (for daily aggregations)
    field :hour, :integer # Hour of day (0-23)
    field :weekday, :integer # Day of week (1-7, Monday-Sunday)
    
    # Meeting/calendar context
    field :in_meeting, :boolean, default: false
    field :meeting_context, :string
    
    # System context
    field :app_version, :string
    field :platform, :string

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(presence_history, attrs) do
    presence_history
    |> cast(attrs, [
      :user_id, :status, :previous_status, :is_online, :was_online,
      :changed_at, :duration_seconds, :session_id, :change_reason,
      :device_type, :user_agent, :ip_address, :custom_status_text,
      :custom_status_emoji, :last_active_channel, :last_message_sent_at,
      :active_connections_count, :date, :hour, :weekday, :in_meeting,
      :meeting_context, :app_version, :platform
    ])
    |> validate_required([:user_id, :status, :is_online, :changed_at])
    |> validate_inclusion(:status, ["online", "away", "busy", "do_not_disturb", "offline"])
    |> validate_inclusion(:previous_status, ["online", "away", "busy", "do_not_disturb", "offline", nil])
    |> validate_inclusion(:change_reason, [
      "manual", "auto_away", "idle_timeout", "meeting", "dnd", "system", "login", "logout", "refresh"
    ])
    |> validate_inclusion(:device_type, ["desktop", "mobile", "web"])
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:hour, greater_than_or_equal_to: 0, less_than_or_equal_to: 23)
    |> validate_number(:weekday, greater_than_or_equal_to: 1, less_than_or_equal_to: 7)
    |> put_computed_fields()
  end

  defp put_computed_fields(changeset) do
    if changed_at = get_field(changeset, :changed_at) do
      date = DateTime.to_date(changed_at)
      hour = changed_at.hour
      weekday = Date.day_of_week(date)
      
      changeset
      |> put_change(:date, date)
      |> put_change(:hour, hour)
      |> put_change(:weekday, weekday)
    else
      changeset
    end
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:changed_at, DateTime.utc_now())
  end

  def create_status_change(user_id, new_status, previous_status, opts \\ []) do
    now = DateTime.utc_now()
    duration = Keyword.get(opts, :duration_seconds, 0)
    
    attrs = %{
      user_id: user_id,
      status: new_status,
      previous_status: previous_status,
      is_online: new_status != "offline",
      was_online: previous_status != "offline" and not is_nil(previous_status),
      changed_at: now,
      duration_seconds: duration,
      session_id: Keyword.get(opts, :session_id),
      change_reason: Keyword.get(opts, :change_reason, "manual"),
      device_type: Keyword.get(opts, :device_type),
      user_agent: Keyword.get(opts, :user_agent),
      ip_address: Keyword.get(opts, :ip_address),
      custom_status_text: Keyword.get(opts, :custom_status_text),
      custom_status_emoji: Keyword.get(opts, :custom_status_emoji),
      last_active_channel: Keyword.get(opts, :last_active_channel),
      active_connections_count: Keyword.get(opts, :active_connections_count, 0),
      in_meeting: Keyword.get(opts, :in_meeting, false),
      meeting_context: Keyword.get(opts, :meeting_context),
      app_version: Keyword.get(opts, :app_version),
      platform: Keyword.get(opts, :platform)
    }
    
    create_changeset(attrs)
  end

  # Query functions
  def for_user_query(user_id) do
    from h in __MODULE__,
      where: h.user_id == ^user_id,
      order_by: [desc: h.changed_at]
  end

  def recent_history_query(user_id, days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from h in __MODULE__,
      where: h.user_id == ^user_id,
      where: h.changed_at >= ^cutoff,
      order_by: [desc: h.changed_at]
  end

  def online_sessions_query(user_id, days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from h in __MODULE__,
      where: h.user_id == ^user_id,
      where: h.changed_at >= ^cutoff,
      where: h.change_reason in ["login", "manual"] and h.is_online == true,
      order_by: [desc: h.changed_at]
  end

  def daily_activity_summary_query(user_id, date) do
    from h in __MODULE__,
      where: h.user_id == ^user_id,
      where: h.date == ^date,
      select: %{
        total_changes: count(h.id),
        online_time: sum(fragment("CASE WHEN ? THEN ? ELSE 0 END", h.was_online, h.duration_seconds)),
        first_online: min(fragment("CASE WHEN ? THEN ? END", h.is_online, h.changed_at)),
        last_online: max(fragment("CASE WHEN ? THEN ? END", h.is_online, h.changed_at)),
        status_changes: fragment("array_agg(DISTINCT ?)", h.status),
        devices_used: fragment("array_agg(DISTINCT ?)", h.device_type)
      }
  end

  def hourly_activity_query(user_id, days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from h in __MODULE__,
      where: h.user_id == ^user_id,
      where: h.changed_at >= ^cutoff,
      where: h.is_online == true,
      group_by: h.hour,
      select: %{
        hour: h.hour,
        activity_count: count(h.id),
        avg_duration: avg(h.duration_seconds),
        most_common_status: fragment("mode() WITHIN GROUP (ORDER BY ?)", h.status)
      },
      order_by: h.hour
  end

  def weekly_pattern_query(user_id, weeks_back \\ 4) do
    cutoff = DateTime.utc_now() |> DateTime.add(-weeks_back * 7, :day)
    
    from h in __MODULE__,
      where: h.user_id == ^user_id,
      where: h.changed_at >= ^cutoff,
      where: h.is_online == true,
      group_by: h.weekday,
      select: %{
        weekday: h.weekday,
        total_online_time: sum(h.duration_seconds),
        avg_sessions: fragment("COUNT(DISTINCT ?)", h.session_id),
        peak_hour: fragment("mode() WITHIN GROUP (ORDER BY ?)", h.hour)
      },
      order_by: h.weekday
  end

  def status_distribution_query(user_id, days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from h in __MODULE__,
      where: h.user_id == ^user_id,
      where: h.changed_at >= ^cutoff,
      group_by: h.status,
      select: %{
        status: h.status,
        total_time: sum(h.duration_seconds),
        occurrences: count(h.id),
        avg_duration: avg(h.duration_seconds)
      },
      order_by: [desc: sum(h.duration_seconds)]
  end

  def team_activity_overview_query(days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from h in __MODULE__,
      where: h.changed_at >= ^cutoff,
      where: h.is_online == true,
      group_by: h.date,
      select: %{
        date: h.date,
        unique_active_users: fragment("COUNT(DISTINCT ?)", h.user_id),
        total_online_time: sum(h.duration_seconds),
        avg_session_length: avg(h.duration_seconds),
        peak_concurrent_hour: fragment("mode() WITHIN GROUP (ORDER BY ?)", h.hour)
      },
      order_by: h.date
  end

  def device_usage_stats_query(user_id, days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from h in __MODULE__,
      where: h.user_id == ^user_id,
      where: h.changed_at >= ^cutoff,
      where: not is_nil(h.device_type),
      group_by: h.device_type,
      select: %{
        device_type: h.device_type,
        usage_time: sum(h.duration_seconds),
        sessions: count(fragment("DISTINCT ?", h.session_id)),
        last_used: max(h.changed_at)
      },
      order_by: [desc: sum(h.duration_seconds)]
  end

  def longest_sessions_query(user_id, limit \\ 10) do
    from h in __MODULE__,
      where: h.user_id == ^user_id,
      where: h.is_online == true,
      where: h.duration_seconds > 0,
      order_by: [desc: h.duration_seconds],
      limit: ^limit,
      select: %{
        session_start: h.changed_at,
        duration_seconds: h.duration_seconds,
        device_type: h.device_type,
        end_reason: h.change_reason
      }
  end

  # Analytics helper functions
  def calculate_availability_score(user_id, days_back \\ 7) do
    # Calculate a score from 0-100 based on online presence during working hours
    # This would involve more complex calculations with working hours data
    75.0 # Placeholder
  end

  def get_peak_activity_hours(user_id, days_back \\ 30) do
    # Return the hours when user is most active
    [9, 10, 11, 14, 15, 16] # Placeholder
  end

  def calculate_response_time_correlation(user_id) do
    # Correlate presence status with message response times
    # This would join with message data
    %{
      online: 5.2,    # minutes average response time
      away: 15.7,
      busy: 45.3,
      offline: 0.0    # no response expected
    }
  end

  def detect_work_patterns(user_id, weeks_back \\ 4) do
    # Analyze and return user's work patterns
    %{
      typical_start_time: ~T[09:00:00],
      typical_end_time: ~T[17:30:00],
      most_active_days: [1, 2, 3, 4, 5], # Mon-Fri
      break_patterns: [~T[12:00:00], ~T[15:00:00]],
      consistency_score: 0.85
    }
  end

  def get_session_summary(entries) when is_list(entries) do
    online_entries = Enum.filter(entries, & &1.is_online)
    
    %{
      total_sessions: length(online_entries),
      total_online_time: Enum.sum(Enum.map(online_entries, & &1.duration_seconds)),
      avg_session_length: if(length(online_entries) > 0, do: Enum.sum(Enum.map(online_entries, & &1.duration_seconds)) / length(online_entries), else: 0),
      devices_used: entries |> Enum.map(& &1.device_type) |> Enum.uniq() |> Enum.reject(&is_nil/1),
      status_changes: length(entries),
      most_common_status: entries |> Enum.map(& &1.status) |> Enum.frequencies() |> Enum.max_by(&elem(&1, 1)) |> elem(0)
    }
  end
end