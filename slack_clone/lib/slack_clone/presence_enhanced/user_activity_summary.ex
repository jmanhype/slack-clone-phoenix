defmodule SlackClone.PresenceEnhanced.UserActivitySummary do
  @moduledoc """
  Schema for tracking daily/weekly/monthly user activity summaries.
  Provides pre-aggregated activity data for efficient dashboard queries.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_activity_summaries" do
    belongs_to :user, SlackClone.Accounts.User

    # Summary period information
    field :summary_date, :date
    field :summary_type, :string # daily, weekly, monthly
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime
    
    # Activity metrics
    field :total_online_seconds, :integer, default: 0
    field :active_sessions, :integer, default: 0
    field :longest_session_seconds, :integer, default: 0
    field :average_session_seconds, :integer, default: 0
    
    # Communication activity
    field :messages_sent, :integer, default: 0
    field :messages_received, :integer, default: 0
    field :threads_participated, :integer, default: 0
    field :reactions_given, :integer, default: 0
    field :reactions_received, :integer, default: 0
    field :mentions_given, :integer, default: 0
    field :mentions_received, :integer, default: 0
    
    # Channel activity
    field :channels_visited, :integer, default: 0
    field :most_active_channel_id, :binary_id
    field :channel_activity_distribution, :map, default: %{}
    
    # Presence patterns
    field :status_changes, :integer, default: 0
    field :most_common_status, :string
    field :status_distribution, :map, default: %{} # %{"online" => 80.5, "away" => 19.5}
    
    # Working hours analysis
    field :peak_activity_hour, :integer # 0-23
    field :first_activity_time, :time
    field :last_activity_time, :time
    field :working_hours_seconds, :integer, default: 0
    field :after_hours_seconds, :integer, default: 0
    
    # Device usage
    field :devices_used, {:array, :string}, default: []
    field :primary_device, :string
    field :device_switch_count, :integer, default: 0
    
    # Engagement metrics
    field :response_time_minutes_avg, :float, default: 0.0
    field :typing_sessions, :integer, default: 0
    field :average_typing_speed_wpm, :float, default: 0.0
    field :interruption_count, :integer, default: 0 # How many times status was interrupted
    
    # Collaboration metrics
    field :unique_collaborators, :integer, default: 0
    field :direct_messages_sent, :integer, default: 0
    field :group_messages_sent, :integer, default: 0
    field :files_shared, :integer, default: 0
    field :files_downloaded, :integer, default: 0
    
    # Meeting and calendar integration
    field :meetings_attended, :integer, default: 0
    field :meeting_minutes_total, :integer, default: 0
    field :dnd_minutes_total, :integer, default: 0
    
    # Productivity scores (0-100)
    field :availability_score, :float, default: 0.0
    field :responsiveness_score, :float, default: 0.0
    field :collaboration_score, :float, default: 0.0
    field :engagement_score, :float, default: 0.0
    field :overall_productivity_score, :float, default: 0.0
    
    # Comparison metrics (vs previous period)
    field :online_time_change_percent, :float, default: 0.0
    field :activity_change_percent, :float, default: 0.0
    field :engagement_change_percent, :float, default: 0.0
    
    # Health and well-being indicators
    field :work_life_balance_score, :float, default: 0.0
    field :break_frequency_score, :float, default: 0.0
    field :consistent_schedule_score, :float, default: 0.0
    
    # Raw data references
    field :presence_entries_count, :integer, default: 0
    field :typing_entries_count, :integer, default: 0
    field :notification_entries_count, :integer, default: 0
    
    # Data quality and completeness
    field :data_completeness_percent, :float, default: 100.0
    field :calculation_errors, {:array, :string}, default: []
    field :last_calculated_at, :utc_datetime
    field :calculation_duration_ms, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(summary, attrs) do
    summary
    |> cast(attrs, [
      :user_id, :summary_date, :summary_type, :period_start, :period_end,
      :total_online_seconds, :active_sessions, :longest_session_seconds,
      :average_session_seconds, :messages_sent, :messages_received,
      :threads_participated, :reactions_given, :reactions_received,
      :mentions_given, :mentions_received, :channels_visited,
      :most_active_channel_id, :channel_activity_distribution, :status_changes,
      :most_common_status, :status_distribution, :peak_activity_hour,
      :first_activity_time, :last_activity_time, :working_hours_seconds,
      :after_hours_seconds, :devices_used, :primary_device, :device_switch_count,
      :response_time_minutes_avg, :typing_sessions, :average_typing_speed_wpm,
      :interruption_count, :unique_collaborators, :direct_messages_sent,
      :group_messages_sent, :files_shared, :files_downloaded, :meetings_attended,
      :meeting_minutes_total, :dnd_minutes_total, :availability_score,
      :responsiveness_score, :collaboration_score, :engagement_score,
      :overall_productivity_score, :online_time_change_percent,
      :activity_change_percent, :engagement_change_percent, :work_life_balance_score,
      :break_frequency_score, :consistent_schedule_score, :presence_entries_count,
      :typing_entries_count, :notification_entries_count, :data_completeness_percent,
      :calculation_errors, :last_calculated_at, :calculation_duration_ms
    ])
    |> validate_required([:user_id, :summary_date, :summary_type, :period_start, :period_end])
    |> validate_inclusion(:summary_type, ["daily", "weekly", "monthly"])
    |> validate_inclusion(:primary_device, ["desktop", "mobile", "web", nil])
    |> validate_number(:peak_activity_hour, greater_than_or_equal_to: 0, less_than_or_equal_to: 23)
    |> validate_number(:availability_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:responsiveness_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:collaboration_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:engagement_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:overall_productivity_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:work_life_balance_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:data_completeness_percent, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> unique_constraint([:user_id, :summary_date, :summary_type])
  end

  def create_daily_summary(user_id, date, opts \\ []) do
    period_start = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    period_end = DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
    
    attrs = %{
      user_id: user_id,
      summary_date: date,
      summary_type: "daily",
      period_start: period_start,
      period_end: period_end,
      last_calculated_at: DateTime.utc_now()
    }
    |> Map.merge(Enum.into(opts, %{}))
    
    %__MODULE__{}
    |> changeset(attrs)
  end

  def create_weekly_summary(user_id, week_start_date, opts \\ []) do
    week_end_date = Date.add(week_start_date, 6)
    period_start = DateTime.new!(week_start_date, ~T[00:00:00], "Etc/UTC")
    period_end = DateTime.new!(week_end_date, ~T[23:59:59], "Etc/UTC")
    
    attrs = %{
      user_id: user_id,
      summary_date: week_start_date,
      summary_type: "weekly",
      period_start: period_start,
      period_end: period_end,
      last_calculated_at: DateTime.utc_now()
    }
    |> Map.merge(Enum.into(opts, %{}))
    
    %__MODULE__{}
    |> changeset(attrs)
  end

  def create_monthly_summary(user_id, month_date, opts \\ []) do
    month_start = Date.beginning_of_month(month_date)
    month_end = Date.end_of_month(month_date)
    period_start = DateTime.new!(month_start, ~T[00:00:00], "Etc/UTC")
    period_end = DateTime.new!(month_end, ~T[23:59:59], "Etc/UTC")
    
    attrs = %{
      user_id: user_id,
      summary_date: month_start,
      summary_type: "monthly",
      period_start: period_start,
      period_end: period_end,
      last_calculated_at: DateTime.utc_now()
    }
    |> Map.merge(Enum.into(opts, %{}))
    
    %__MODULE__{}
    |> changeset(attrs)
  end

  # Query functions
  def for_user_query(user_id) do
    from s in __MODULE__,
      where: s.user_id == ^user_id,
      order_by: [desc: s.summary_date]
  end

  def daily_summaries_query(user_id, days_back \\ 30) do
    cutoff = Date.utc_today() |> Date.add(-days_back)
    
    from s in __MODULE__,
      where: s.user_id == ^user_id,
      where: s.summary_type == "daily",
      where: s.summary_date >= ^cutoff,
      order_by: [desc: s.summary_date]
  end

  def weekly_summaries_query(user_id, weeks_back \\ 12) do
    cutoff = Date.utc_today() |> Date.add(-weeks_back * 7)
    
    from s in __MODULE__,
      where: s.user_id == ^user_id,
      where: s.summary_type == "weekly",
      where: s.summary_date >= ^cutoff,
      order_by: [desc: s.summary_date]
  end

  def monthly_summaries_query(user_id, months_back \\ 12) do
    cutoff = Date.utc_today() |> Date.add(-months_back * 30)
    
    from s in __MODULE__,
      where: s.user_id == ^user_id,
      where: s.summary_type == "monthly",
      where: s.summary_date >= ^cutoff,
      order_by: [desc: s.summary_date]
  end

  def team_productivity_overview_query(summary_type \\ "daily", days_back \\ 30) do
    cutoff = Date.utc_today() |> Date.add(-days_back)
    
    from s in __MODULE__,
      where: s.summary_type == ^summary_type,
      where: s.summary_date >= ^cutoff,
      group_by: s.summary_date,
      select: %{
        date: s.summary_date,
        active_users: count(s.id),
        avg_online_time: avg(s.total_online_seconds),
        avg_messages: avg(s.messages_sent),
        avg_productivity_score: avg(s.overall_productivity_score),
        total_collaboration_events: sum(s.reactions_given) + sum(s.reactions_received)
      },
      order_by: s.summary_date
  end

  def productivity_leaderboard_query(summary_type \\ "weekly", limit \\ 10) do
    latest_date = from(s in __MODULE__, 
      where: s.summary_type == ^summary_type,
      select: max(s.summary_date)
    )
    
    from s in __MODULE__,
      where: s.summary_type == ^summary_type,
      where: s.summary_date == subquery(latest_date),
      where: s.overall_productivity_score > 0,
      order_by: [desc: s.overall_productivity_score],
      limit: ^limit,
      select: %{
        user_id: s.user_id,
        productivity_score: s.overall_productivity_score,
        online_time: s.total_online_seconds,
        messages_sent: s.messages_sent,
        collaboration_score: s.collaboration_score
      }
  end

  def activity_trends_query(user_id, summary_type \\ "daily", periods_back \\ 30) do
    cutoff = case summary_type do
      "daily" -> Date.utc_today() |> Date.add(-periods_back)
      "weekly" -> Date.utc_today() |> Date.add(-periods_back * 7)
      "monthly" -> Date.utc_today() |> Date.add(-periods_back * 30)
    end
    
    from s in __MODULE__,
      where: s.user_id == ^user_id,
      where: s.summary_type == ^summary_type,
      where: s.summary_date >= ^cutoff,
      select: %{
        date: s.summary_date,
        online_time: s.total_online_seconds,
        messages_sent: s.messages_sent,
        productivity_score: s.overall_productivity_score,
        engagement_score: s.engagement_score,
        collaboration_score: s.collaboration_score
      },
      order_by: s.summary_date
  end

  def wellness_indicators_query(user_id, days_back \\ 30) do
    cutoff = Date.utc_today() |> Date.add(-days_back)
    
    from s in __MODULE__,
      where: s.user_id == ^user_id,
      where: s.summary_type == "daily",
      where: s.summary_date >= ^cutoff,
      select: %{
        date: s.summary_date,
        work_life_balance: s.work_life_balance_score,
        break_frequency: s.break_frequency_score,
        consistent_schedule: s.consistent_schedule_score,
        after_hours_time: s.after_hours_seconds,
        dnd_time: s.dnd_minutes_total,
        longest_session: s.longest_session_seconds
      },
      order_by: s.summary_date
  end

  # Helper functions for calculations
  def calculate_productivity_scores(summary_data) do
    availability = calculate_availability_score(summary_data)
    responsiveness = calculate_responsiveness_score(summary_data)
    collaboration = calculate_collaboration_score(summary_data)
    engagement = calculate_engagement_score(summary_data)
    
    overall = (availability * 0.3 + responsiveness * 0.25 + collaboration * 0.25 + engagement * 0.2)
    
    %{
      availability_score: Float.round(availability, 1),
      responsiveness_score: Float.round(responsiveness, 1),
      collaboration_score: Float.round(collaboration, 1),
      engagement_score: Float.round(engagement, 1),
      overall_productivity_score: Float.round(overall, 1)
    }
  end

  defp calculate_availability_score(data) do
    # Score based on online time during working hours vs expected working time
    working_hours_expected = 8 * 3600 # 8 hours in seconds
    availability_ratio = min(data.working_hours_seconds / working_hours_expected, 1.0)
    
    # Bonus points for consistency and regular breaks
    consistency_bonus = if data.consistent_schedule_score > 70, do: 10, else: 0
    break_bonus = if data.break_frequency_score > 50, do: 5, else: 0
    
    base_score = availability_ratio * 85 # Max 85 from availability
    min(base_score + consistency_bonus + break_bonus, 100)
  end

  defp calculate_responsiveness_score(data) do
    # Score based on average response time
    cond do
      data.response_time_minutes_avg <= 5 -> 100
      data.response_time_minutes_avg <= 15 -> 85
      data.response_time_minutes_avg <= 30 -> 70
      data.response_time_minutes_avg <= 60 -> 50
      true -> 25
    end
  end

  defp calculate_collaboration_score(data) do
    # Score based on reactions, mentions, file sharing, thread participation
    base_interactions = data.reactions_given + data.reactions_received + 
                       data.mentions_given + data.mentions_received +
                       data.threads_participated + data.files_shared
    
    # Normalize based on messages sent (more messages = more opportunities for collaboration)
    if data.messages_sent > 0 do
      collaboration_ratio = base_interactions / data.messages_sent
      min(collaboration_ratio * 50 + 25, 100) # Scale and add base score
    else
      0
    end
  end

  defp calculate_engagement_score(data) do
    # Score based on message activity, channel participation, and session consistency
    message_score = min(data.messages_sent / 20 * 30, 30) # Up to 30 points for messaging
    channel_score = min(data.channels_visited / 5 * 20, 20) # Up to 20 points for channel activity
    session_score = min(data.active_sessions / 3 * 25, 25) # Up to 25 points for session consistency
    typing_score = min(data.typing_sessions / 10 * 25, 25) # Up to 25 points for typing activity
    
    message_score + channel_score + session_score + typing_score
  end

  def get_summary_insights(summary) do
    insights = []
    
    # Productivity insights
    insights = if summary.overall_productivity_score >= 80 do
      ["High productivity day! 🚀" | insights]
    else
      insights
    end
    
    # Work-life balance insights
    insights = if summary.after_hours_seconds > 2 * 3600 do
      ["Consider reducing after-hours work for better work-life balance" | insights]
    else
      insights
    end
    
    # Collaboration insights
    insights = if summary.collaboration_score < 30 do
      ["Try engaging more with your team through reactions and comments" | insights]
    else
      insights
    end
    
    # Break frequency insights
    insights = if summary.longest_session_seconds > 4 * 3600 do
      ["Consider taking more frequent breaks during long work sessions" | insights]
    else
      insights
    end
    
    # Responsiveness insights
    insights = if summary.response_time_minutes_avg > 60 do
      ["Response time could be improved for better team collaboration" | insights]
    else
      insights
    end
    
    Enum.reverse(insights)
  end
end