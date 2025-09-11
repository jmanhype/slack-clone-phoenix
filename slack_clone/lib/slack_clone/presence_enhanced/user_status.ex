defmodule SlackClone.PresenceEnhanced.UserStatus do
  @moduledoc """
  Schema for enhanced user status and presence information.
  Supports custom status messages, emoji, and automatic status detection.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_statuses" do
    belongs_to :user, SlackClone.Accounts.User

    # Basic presence status
    field :status, :string, default: "offline" # online, away, busy, do_not_disturb, offline
    field :is_online, :boolean, default: false
    field :last_seen_at, :utc_datetime
    field :last_activity_at, :utc_datetime
    
    # Custom status
    field :custom_status_text, :string
    field :custom_status_emoji, :string
    field :custom_status_expires_at, :utc_datetime
    
    # Automatic status detection
    field :auto_status_enabled, :boolean, default: true
    field :idle_threshold_minutes, :integer, default: 15
    field :away_message, :string
    
    # Activity indicators
    field :is_typing, :boolean, default: false
    field :typing_in_channel, :binary_id
    field :typing_expires_at, :utc_datetime
    
    # Meeting/calendar integration
    field :in_meeting, :boolean, default: false
    field :meeting_title, :string
    field :meeting_ends_at, :utc_datetime
    field :calendar_integration_enabled, :boolean, default: false
    
    # Device and connection info
    field :active_connections, :integer, default: 0
    field :primary_device, :string # desktop, mobile, web
    field :device_info, :map, default: %{}
    field :connection_quality, :string # good, fair, poor
    
    # Working hours and timezone
    field :timezone, :string
    field :working_hours_start, :time
    field :working_hours_end, :time
    field :working_days, {:array, :integer}, default: [1, 2, 3, 4, 5] # Monday-Friday
    field :is_in_working_hours, :boolean, default: true
    
    # Do Not Disturb settings
    field :dnd_enabled, :boolean, default: false
    field :dnd_ends_at, :utc_datetime
    field :dnd_allow_urgent, :boolean, default: true
    field :snooze_notifications_until, :utc_datetime
    
    # Status history and analytics
    field :status_change_count, :integer, default: 0
    field :total_online_time_seconds, :integer, default: 0
    field :last_status_change, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_status, attrs) do
    user_status
    |> cast(attrs, [
      :user_id, :status, :is_online, :last_seen_at, :last_activity_at,
      :custom_status_text, :custom_status_emoji, :custom_status_expires_at,
      :auto_status_enabled, :idle_threshold_minutes, :away_message,
      :is_typing, :typing_in_channel, :typing_expires_at, :in_meeting,
      :meeting_title, :meeting_ends_at, :calendar_integration_enabled,
      :active_connections, :primary_device, :device_info, :connection_quality,
      :timezone, :working_hours_start, :working_hours_end, :working_days,
      :is_in_working_hours, :dnd_enabled, :dnd_ends_at, :dnd_allow_urgent,
      :snooze_notifications_until, :status_change_count, :total_online_time_seconds,
      :last_status_change
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:status, ["online", "away", "busy", "do_not_disturb", "offline"])
    |> validate_inclusion(:primary_device, ["desktop", "mobile", "web"])
    |> validate_inclusion(:connection_quality, ["good", "fair", "poor"])
    |> validate_number(:idle_threshold_minutes, greater_than: 0, less_than_or_equal_to: 480)
    |> validate_number(:active_connections, greater_than_or_equal_to: 0)
    |> validate_working_days()
    |> unique_constraint(:user_id)
  end

  defp validate_working_days(changeset) do
    case get_field(changeset, :working_days) do
      nil -> changeset
      days when is_list(days) ->
        if Enum.all?(days, &(&1 in 1..7)) do
          changeset
        else
          add_error(changeset, :working_days, "must contain valid weekday numbers (1-7)")
        end
      _ -> add_error(changeset, :working_days, "must be a list of weekday numbers")
    end
  end

  def update_online_status(user_status, is_online) do
    now = DateTime.utc_now()
    
    changes = %{
      is_online: is_online,
      last_seen_at: now,
      last_activity_at: now
    }
    
    changes = if is_online do
      Map.merge(changes, %{
        status: if(user_status.status == "offline", do: "online", else: user_status.status),
        last_status_change: now,
        status_change_count: user_status.status_change_count + 1
      })
    else
      Map.merge(changes, %{
        status: "offline",
        is_typing: false,
        typing_in_channel: nil,
        typing_expires_at: nil,
        active_connections: 0
      })
    end
    
    user_status
    |> change(changes)
  end

  def set_custom_status(user_status, text, emoji \\ nil, expires_at \\ nil) do
    user_status
    |> change(%{
      custom_status_text: text,
      custom_status_emoji: emoji,
      custom_status_expires_at: expires_at
    })
  end

  def clear_custom_status(user_status) do
    user_status
    |> change(%{
      custom_status_text: nil,
      custom_status_emoji: nil,
      custom_status_expires_at: nil
    })
  end

  def set_typing_status(user_status, channel_id, is_typing \\ true) do
    expires_at = if is_typing do
      DateTime.utc_now() |> DateTime.add(30, :second)
    else
      nil
    end
    
    user_status
    |> change(%{
      is_typing: is_typing,
      typing_in_channel: if(is_typing, do: channel_id, else: nil),
      typing_expires_at: expires_at,
      last_activity_at: DateTime.utc_now()
    })
  end

  def set_meeting_status(user_status, in_meeting, title \\ nil, ends_at \\ nil) do
    changes = %{
      in_meeting: in_meeting,
      meeting_title: if(in_meeting, do: title, else: nil),
      meeting_ends_at: if(in_meeting, do: ends_at, else: nil)
    }
    
    changes = if in_meeting do
      Map.put(changes, :status, "busy")
    else
      changes
    end
    
    user_status
    |> change(changes)
  end

  def set_dnd_status(user_status, enabled, ends_at \\ nil, allow_urgent \\ true) do
    changes = %{
      dnd_enabled: enabled,
      dnd_ends_at: if(enabled, do: ends_at, else: nil),
      dnd_allow_urgent: allow_urgent
    }
    
    changes = if enabled do
      Map.put(changes, :status, "do_not_disturb")
    else
      changes
    end
    
    user_status
    |> change(changes)
  end

  def update_connection_info(user_status, device, connection_count, quality \\ "good") do
    user_status
    |> change(%{
      primary_device: device,
      active_connections: connection_count,
      connection_quality: quality,
      last_activity_at: DateTime.utc_now()
    })
  end

  def is_available?(user_status) do
    user_status.is_online and 
    user_status.status in ["online", "away"] and
    not user_status.dnd_enabled and
    not user_status.in_meeting
  end

  def is_disturb_allowed?(user_status, priority \\ "normal") do
    cond do
      not user_status.is_online -> false
      not user_status.dnd_enabled -> true
      user_status.dnd_allow_urgent and priority in ["high", "urgent", "critical"] -> true
      true -> false
    end
  end

  def has_expired_custom_status?(user_status) do
    user_status.custom_status_expires_at != nil and
    DateTime.compare(DateTime.utc_now(), user_status.custom_status_expires_at) == :gt
  end

  def is_typing_expired?(user_status) do
    user_status.typing_expires_at != nil and
    DateTime.compare(DateTime.utc_now(), user_status.typing_expires_at) == :gt
  end

  def is_in_working_hours?(user_status) do
    if user_status.timezone and user_status.working_hours_start and user_status.working_hours_end do
      now = DateTime.now!(user_status.timezone)
      current_time = DateTime.to_time(now)
      current_weekday = Date.day_of_week(DateTime.to_date(now))
      
      weekday_match = current_weekday in user_status.working_days
      time_match = Time.compare(current_time, user_status.working_hours_start) != :lt and
                   Time.compare(current_time, user_status.working_hours_end) != :gt
      
      weekday_match and time_match
    else
      user_status.is_in_working_hours
    end
  end

  def should_auto_away?(user_status) do
    if user_status.auto_status_enabled and user_status.last_activity_at do
      idle_threshold = DateTime.add(DateTime.utc_now(), -user_status.idle_threshold_minutes, :minute)
      DateTime.compare(user_status.last_activity_at, idle_threshold) == :lt
    else
      false
    end
  end

  # Query functions
  def online_users_query do
    from u in __MODULE__,
      where: u.is_online == true,
      where: u.status != "offline"
  end

  def typing_users_query(channel_id) do
    from u in __MODULE__,
      where: u.is_typing == true,
      where: u.typing_in_channel == ^channel_id,
      where: u.typing_expires_at > ^DateTime.utc_now()
  end

  def available_users_query do
    from u in __MODULE__,
      where: u.is_online == true,
      where: u.status in ["online", "away"],
      where: u.dnd_enabled == false,
      where: u.in_meeting == false
  end

  def users_with_custom_status_query do
    from u in __MODULE__,
      where: not is_nil(u.custom_status_text),
      where: is_nil(u.custom_status_expires_at) or u.custom_status_expires_at > ^DateTime.utc_now()
  end

  def expired_typing_query do
    from u in __MODULE__,
      where: u.is_typing == true,
      where: u.typing_expires_at <= ^DateTime.utc_now()
  end

  def expired_custom_status_query do
    from u in __MODULE__,
      where: not is_nil(u.custom_status_text),
      where: not is_nil(u.custom_status_expires_at),
      where: u.custom_status_expires_at <= ^DateTime.utc_now()
  end

  def users_in_timezone_query(timezone) do
    from u in __MODULE__,
      where: u.timezone == ^timezone
  end

  def calculate_online_time(user_status, since \\ nil) do
    # This would typically be calculated from presence_history
    # For now, return the stored total
    user_status.total_online_time_seconds
  end

  def get_display_status(user_status) do
    cond do
      user_status.custom_status_text and not has_expired_custom_status?(user_status) ->
        %{
          status: user_status.status,
          display: user_status.custom_status_text,
          emoji: user_status.custom_status_emoji,
          type: "custom"
        }
      
      user_status.in_meeting ->
        %{
          status: "busy",
          display: user_status.meeting_title || "In a meeting",
          emoji: "📞",
          type: "meeting"
        }
      
      user_status.dnd_enabled ->
        %{
          status: "do_not_disturb",
          display: "Do not disturb",
          emoji: "🔕",
          type: "dnd"
        }
      
      not is_in_working_hours?(user_status) ->
        %{
          status: user_status.status,
          display: "Outside working hours",
          emoji: "🌙",
          type: "non_working_hours"
        }
      
      true ->
        %{
          status: user_status.status,
          display: status_display_text(user_status.status),
          emoji: status_emoji(user_status.status),
          type: "default"
        }
    end
  end

  defp status_display_text(status) do
    case status do
      "online" -> "Available"
      "away" -> "Away"
      "busy" -> "Busy"
      "do_not_disturb" -> "Do not disturb"
      "offline" -> "Offline"
      _ -> "Unknown"
    end
  end

  defp status_emoji(status) do
    case status do
      "online" -> "🟢"
      "away" -> "🟡"
      "busy" -> "🔴"
      "do_not_disturb" -> "⛔"
      "offline" -> "⚫"
      _ -> "❓"
    end
  end
end