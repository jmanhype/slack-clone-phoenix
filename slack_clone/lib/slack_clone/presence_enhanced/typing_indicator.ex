defmodule SlackClone.PresenceEnhanced.TypingIndicator do
  @moduledoc """
  Schema for tracking typing indicators and real-time typing status.
  Provides efficient typing indicator management with automatic cleanup.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "typing_indicators" do
    belongs_to :user, SlackClone.Accounts.User
    belongs_to :channel, SlackClone.Chat.Channel
    belongs_to :thread, SlackClone.Chat.Message, foreign_key: :thread_id

    # Typing state
    field :is_typing, :boolean, default: true
    field :started_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :last_activity_at, :utc_datetime
    
    # Context information
    field :device_type, :string # desktop, mobile, web
    field :input_method, :string # keyboard, voice, paste
    field :message_length, :integer, default: 0
    field :cursor_position, :integer, default: 0
    
    # Typing behavior analytics
    field :typing_speed_wpm, :float # words per minute
    field :pause_count, :integer, default: 0
    field :backspace_count, :integer, default: 0
    field :total_characters_typed, :integer, default: 0
    
    # Session and connection info
    field :session_id, :string
    field :connection_id, :string
    field :user_agent, :string
    
    # Auto-cleanup status
    field :cleanup_scheduled, :boolean, default: false
    field :cleanup_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(typing_indicator, attrs) do
    typing_indicator
    |> cast(attrs, [
      :user_id, :channel_id, :thread_id, :is_typing, :started_at, :expires_at,
      :last_activity_at, :device_type, :input_method, :message_length,
      :cursor_position, :typing_speed_wpm, :pause_count, :backspace_count,
      :total_characters_typed, :session_id, :connection_id, :user_agent,
      :cleanup_scheduled, :cleanup_at
    ])
    |> validate_required([:user_id, :channel_id, :started_at])
    |> validate_inclusion(:device_type, ["desktop", "mobile", "web"])
    |> validate_inclusion(:input_method, ["keyboard", "voice", "paste", "unknown"])
    |> validate_number(:message_length, greater_than_or_equal_to: 0)
    |> validate_number(:cursor_position, greater_than_or_equal_to: 0)
    |> validate_number(:typing_speed_wpm, greater_than_or_equal_to: 0.0)
    |> validate_number(:pause_count, greater_than_or_equal_to: 0)
    |> validate_number(:backspace_count, greater_than_or_equal_to: 0)
    |> validate_number(:total_characters_typed, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :channel_id, :thread_id])
  end

  def create_changeset(attrs) do
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, 30, :second) # Default 30 second expiration
    
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:started_at, now)
    |> put_change(:expires_at, expires_at)
    |> put_change(:last_activity_at, now)
    |> put_change(:cleanup_at, DateTime.add(expires_at, 60, :second))
  end

  def update_typing_activity(indicator, attrs \\ %{}) do
    now = DateTime.utc_now()
    new_expires_at = DateTime.add(now, 30, :second)
    
    changes = %{
      is_typing: true,
      last_activity_at: now,
      expires_at: new_expires_at,
      cleanup_at: DateTime.add(new_expires_at, 60, :second)
    }
    
    # Update typing analytics if provided
    changes = changes
    |> maybe_update_message_length(attrs)
    |> maybe_update_typing_stats(indicator, attrs)
    
    indicator
    |> change(changes)
  end

  def stop_typing(indicator) do
    now = DateTime.utc_now()
    
    indicator
    |> change(%{
      is_typing: false,
      last_activity_at: now,
      cleanup_scheduled: true,
      cleanup_at: DateTime.add(now, 5, :second) # Clean up in 5 seconds
    })
  end

  defp maybe_update_message_length(changes, attrs) do
    case Map.get(attrs, :message_length) do
      nil -> changes
      length when is_integer(length) -> Map.put(changes, :message_length, length)
      _ -> changes
    end
  end

  defp maybe_update_typing_stats(changes, indicator, attrs) do
    changes = case Map.get(attrs, :cursor_position) do
      nil -> changes
      pos when is_integer(pos) -> Map.put(changes, :cursor_position, pos)
      _ -> changes
    end
    
    changes = case Map.get(attrs, :typing_speed_wpm) do
      nil -> changes
      speed when is_number(speed) -> Map.put(changes, :typing_speed_wpm, speed)
      _ -> changes
    end
    
    # Update character counts
    if new_chars = Map.get(attrs, :characters_added) do
      Map.put(changes, :total_characters_typed, indicator.total_characters_typed + new_chars)
    else
      changes
    end
  end

  def calculate_typing_speed(indicator, time_window_seconds \\ 10) do
    if indicator.total_characters_typed > 0 and indicator.started_at do
      elapsed_seconds = DateTime.diff(DateTime.utc_now(), indicator.started_at, :second)
      
      if elapsed_seconds > 0 do
        # Approximate words per minute (assuming 5 characters per word)
        chars_per_second = indicator.total_characters_typed / elapsed_seconds
        words_per_minute = (chars_per_second * 60) / 5
        Float.round(words_per_minute, 1)
      else
        0.0
      end
    else
      0.0
    end
  end

  # Query functions
  def active_in_channel_query(channel_id, thread_id \\ nil) do
    query = from t in __MODULE__,
      where: t.channel_id == ^channel_id,
      where: t.is_typing == true,
      where: t.expires_at > ^DateTime.utc_now()
    
    if thread_id do
      from t in query, where: t.thread_id == ^thread_id
    else
      from t in query, where: is_nil(t.thread_id)
    end
  end

  def for_user_query(user_id) do
    from t in __MODULE__,
      where: t.user_id == ^user_id,
      where: t.is_typing == true,
      where: t.expires_at > ^DateTime.utc_now()
  end

  def expired_indicators_query do
    from t in __MODULE__,
      where: t.expires_at <= ^DateTime.utc_now() or
             (t.is_typing == false and t.cleanup_at <= ^DateTime.utc_now())
  end

  def recent_typing_activity_query(user_id, hours_back \\ 1) do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours_back, :hour)
    
    from t in __MODULE__,
      where: t.user_id == ^user_id,
      where: t.started_at >= ^cutoff,
      order_by: [desc: t.started_at]
  end

  def channel_typing_stats_query(channel_id, days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from t in __MODULE__,
      where: t.channel_id == ^channel_id,
      where: t.started_at >= ^cutoff,
      select: %{
        total_sessions: count(t.id),
        unique_typers: fragment("COUNT(DISTINCT ?)", t.user_id),
        avg_typing_speed: avg(t.typing_speed_wpm),
        total_characters: sum(t.total_characters_typed),
        avg_session_length: avg(fragment("EXTRACT(EPOCH FROM (? - ?))", t.expires_at, t.started_at))
      }
  end

  def user_typing_patterns_query(user_id, days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from t in __MODULE__,
      where: t.user_id == ^user_id,
      where: t.started_at >= ^cutoff,
      select: %{
        total_sessions: count(t.id),
        avg_typing_speed: avg(t.typing_speed_wpm),
        total_characters: sum(t.total_characters_typed),
        avg_message_length: avg(t.message_length),
        most_used_device: fragment("mode() WITHIN GROUP (ORDER BY ?)", t.device_type),
        peak_typing_hour: fragment("mode() WITHIN GROUP (ORDER BY EXTRACT(HOUR FROM ?))", t.started_at)
      }
  end

  def typing_heatmap_query(channel_id, days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from t in __MODULE__,
      where: t.channel_id == ^channel_id,
      where: t.started_at >= ^cutoff,
      group_by: [
        fragment("EXTRACT(HOUR FROM ?)", t.started_at),
        fragment("EXTRACT(DOW FROM ?)", t.started_at)
      ],
      select: %{
        hour: fragment("EXTRACT(HOUR FROM ?)", t.started_at),
        day_of_week: fragment("EXTRACT(DOW FROM ?)", t.started_at),
        typing_sessions: count(t.id),
        unique_users: fragment("COUNT(DISTINCT ?)", t.user_id)
      },
      order_by: [
        fragment("EXTRACT(DOW FROM ?)", t.started_at),
        fragment("EXTRACT(HOUR FROM ?)", t.started_at)
      ]
  end

  # Helper functions for real-time typing indicators
  def get_typing_users_display(channel_id, thread_id \\ nil, current_user_id \\ nil) do
    active_in_channel_query(channel_id, thread_id)
    |> maybe_exclude_current_user(current_user_id)
    |> SlackClone.Repo.all()
    |> Enum.map(&format_typing_user/1)
  end

  defp maybe_exclude_current_user(query, nil), do: query
  defp maybe_exclude_current_user(query, user_id) do
    from t in query, where: t.user_id != ^user_id
  end

  defp format_typing_user(indicator) do
    # This would typically join with user data
    %{
      user_id: indicator.user_id,
      device_type: indicator.device_type,
      typing_speed: indicator.typing_speed_wpm,
      started_at: indicator.started_at
    }
  end

  def format_typing_indicator_message(typing_users) when is_list(typing_users) do
    case length(typing_users) do
      0 -> nil
      1 -> "#{hd(typing_users).user_id} is typing..."
      2 -> 
        [first, second] = typing_users
        "#{first.user_id} and #{second.user_id} are typing..."
      count when count <= 5 ->
        names = Enum.map(typing_users, & &1.user_id)
        "#{Enum.join(Enum.take(names, -1), ", ")} and #{List.last(names)} are typing..."
      count ->
        "#{count} people are typing..."
    end
  end

  def should_show_typing_indicator?(indicator) do
    indicator.is_typing and
    DateTime.compare(indicator.expires_at, DateTime.utc_now()) == :gt and
    DateTime.diff(DateTime.utc_now(), indicator.started_at, :second) >= 1 # Show after 1 second delay
  end

  def estimate_message_completion_time(indicator) do
    if indicator.typing_speed_wpm > 0 and indicator.message_length > 0 do
      remaining_chars = max(0, indicator.message_length - indicator.total_characters_typed)
      chars_per_second = (indicator.typing_speed_wpm * 5) / 60 # Convert WPM to chars/sec
      
      if chars_per_second > 0 do
        estimated_seconds = remaining_chars / chars_per_second
        DateTime.add(DateTime.utc_now(), round(estimated_seconds), :second)
      else
        nil
      end
    else
      nil
    end
  end

  # Cleanup functions
  def cleanup_expired_indicators do
    from(t in __MODULE__, where: t.expires_at <= ^DateTime.utc_now() or
                                  (t.is_typing == false and t.cleanup_at <= ^DateTime.utc_now()))
    |> SlackClone.Repo.delete_all()
  end

  def cleanup_old_indicators(days_back \\ 1) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from(t in __MODULE__, where: t.started_at < ^cutoff)
    |> SlackClone.Repo.delete_all()
  end

  def get_typing_analytics_summary(channel_id, days_back \\ 7) do
    stats = channel_typing_stats_query(channel_id, days_back)
    |> SlackClone.Repo.one()
    
    %{
      activity_level: classify_typing_activity(stats.total_sessions),
      engagement_score: calculate_engagement_score(stats),
      avg_typing_speed: Float.round(stats.avg_typing_speed || 0.0, 1),
      participation_rate: stats.unique_typers
    }
  end

  defp classify_typing_activity(session_count) do
    cond do
      session_count >= 100 -> "very_high"
      session_count >= 50 -> "high" 
      session_count >= 20 -> "medium"
      session_count >= 5 -> "low"
      true -> "very_low"
    end
  end

  defp calculate_engagement_score(stats) do
    # Simple engagement score based on typing activity
    base_score = min(stats.total_sessions * 2, 100)
    speed_bonus = min((stats.avg_typing_speed || 0) / 2, 20)
    
    round(base_score + speed_bonus)
  end
end