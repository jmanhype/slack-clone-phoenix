defmodule SlackClone.Notifications.NotificationPreferences do
  @moduledoc """
  Schema for user notification preferences.
  Manages how and when users receive notifications.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notification_preferences" do
    belongs_to :user, SlackClone.Accounts.User

    # Delivery methods
    field :email_enabled, :boolean, default: true
    field :push_enabled, :boolean, default: true
    field :in_app_enabled, :boolean, default: true
    field :sms_enabled, :boolean, default: false

    # Notification types
    field :mentions_enabled, :boolean, default: true
    field :direct_messages_enabled, :boolean, default: true
    field :channel_messages_enabled, :boolean, default: true
    field :thread_replies_enabled, :boolean, default: true
    field :file_shares_enabled, :boolean, default: true
    field :system_notifications_enabled, :boolean, default: true

    # Quiet hours
    field :quiet_hours_enabled, :boolean, default: false
    field :quiet_hours_start, :time
    field :quiet_hours_end, :time
    field :quiet_hours_timezone, :string

    # Email digest settings
    field :email_digest_enabled, :boolean, default: true
    field :email_digest_frequency, :string, default: "daily" # daily, weekly, never
    field :email_digest_time, :time
    field :email_digest_timezone, :string

    # Advanced settings
    field :priority_threshold, :string, default: "normal" # low, normal, high, critical
    field :batch_notifications, :boolean, default: true
    field :notification_sounds, :boolean, default: true
    field :desktop_notifications, :boolean, default: true
    field :mobile_push_badges, :boolean, default: true

    # Channel-specific overrides (JSON field for flexibility)
    field :channel_overrides, :map, default: %{}
    
    # Keywords that trigger notifications
    field :notification_keywords, {:array, :string}, default: []

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification_preferences, attrs) do
    notification_preferences
    |> cast(attrs, [
      :user_id, :email_enabled, :push_enabled, :in_app_enabled, :sms_enabled,
      :mentions_enabled, :direct_messages_enabled, :channel_messages_enabled,
      :thread_replies_enabled, :file_shares_enabled, :system_notifications_enabled,
      :quiet_hours_enabled, :quiet_hours_start, :quiet_hours_end, :quiet_hours_timezone,
      :email_digest_enabled, :email_digest_frequency, :email_digest_time, :email_digest_timezone,
      :priority_threshold, :batch_notifications, :notification_sounds, :desktop_notifications,
      :mobile_push_badges, :channel_overrides, :notification_keywords
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:email_digest_frequency, ["daily", "weekly", "never"])
    |> validate_inclusion(:priority_threshold, ["low", "normal", "high", "critical"])
    |> validate_quiet_hours()
    |> unique_constraint(:user_id)
  end

  defp validate_quiet_hours(changeset) do
    if get_field(changeset, :quiet_hours_enabled) do
      changeset
      |> validate_required([:quiet_hours_start, :quiet_hours_end, :quiet_hours_timezone])
    else
      changeset
    end
  end

  def get_channel_preference(preferences, channel_id, preference_type) do
    case Map.get(preferences.channel_overrides, channel_id) do
      nil -> Map.get(preferences, preference_type)
      overrides -> Map.get(overrides, Atom.to_string(preference_type), Map.get(preferences, preference_type))
    end
  end

  def is_in_quiet_hours?(preferences) do
    if preferences.quiet_hours_enabled and preferences.quiet_hours_timezone do
      now = DateTime.now!(preferences.quiet_hours_timezone)
      current_time = DateTime.to_time(now)
      
      Time.compare(current_time, preferences.quiet_hours_start) != :lt and
      Time.compare(current_time, preferences.quiet_hours_end) != :gt
    else
      false
    end
  end

  def should_send_notification?(preferences, notification_type, channel_id \\ nil, priority \\ "normal") do
    # Check if in quiet hours (except for high/critical priority)
    if is_in_quiet_hours?(preferences) and priority not in ["high", "critical"] do
      false
    else
      # Check type-specific preferences
      type_enabled = case notification_type do
        :mention -> preferences.mentions_enabled
        :direct_message -> preferences.direct_messages_enabled
        :channel_message -> get_channel_preference(preferences, channel_id, :channel_messages_enabled)
        :thread_reply -> preferences.thread_replies_enabled
        :file_share -> preferences.file_shares_enabled
        :system -> preferences.system_notifications_enabled
        _ -> true
      end

      # Check priority threshold
      priority_met = case {priority, preferences.priority_threshold} do
        {_, "low"} -> true
        {"low", "normal"} -> false
        {"low", "high"} -> false
        {"low", "critical"} -> false
        {_, "normal"} when priority in ["normal", "high", "critical"] -> true
        {"normal", "high"} -> false
        {"normal", "critical"} -> false
        {_, "high"} when priority in ["high", "critical"] -> true
        {"high", "critical"} -> false
        {_, "critical"} when priority == "critical" -> true
        _ -> true
      end

      type_enabled and priority_met
    end
  end
end