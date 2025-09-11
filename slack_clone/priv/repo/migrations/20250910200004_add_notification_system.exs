defmodule SlackClone.Repo.Migrations.AddNotificationSystem do
  use Ecto.Migration

  def change do
    # Create notifications table
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false # message, mention, thread_reply, channel_invite, dm
      add :title, :string, null: false
      add :body, :text
      add :data, :map, default: %{} # Additional data like message_id, channel_id, etc.
      add :read_at, :utc_datetime
      add :clicked_at, :utc_datetime
      add :is_read, :boolean, default: false
      add :priority, :string, default: "normal" # low, normal, high, urgent
      add :delivery_method, {:array, :string}, default: [] # push, email, sms
      add :delivered_at, :utc_datetime
      add :failed_delivery_count, :integer, default: 0
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:workspace_id])
    create index(:notifications, [:type])
    create index(:notifications, [:is_read])
    create index(:notifications, [:priority])
    create index(:notifications, [:delivered_at])
    create index(:notifications, [:expires_at])
    create index(:notifications, [:user_id, :is_read])
    create index(:notifications, [:user_id, :workspace_id, :is_read])

    # Create notification_preferences table
    create table(:notification_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      
      # Global notification settings
      add :all_messages, :boolean, default: false
      add :direct_messages, :boolean, default: true
      add :mentions, :boolean, default: true
      add :keywords, {:array, :string}, default: []
      
      # Channel-specific settings
      add :channel_preferences, :map, default: %{} # channel_id -> settings
      
      # Delivery method preferences
      add :push_notifications, :boolean, default: true
      add :email_notifications, :boolean, default: true
      add :email_digest, :boolean, default: true
      add :digest_frequency, :string, default: "daily" # never, daily, weekly
      
      # Schedule settings
      add :quiet_hours_enabled, :boolean, default: false
      add :quiet_hours_start, :time
      add :quiet_hours_end, :time
      add :timezone, :string
      
      # Mobile-specific
      add :mobile_push_enabled, :boolean, default: true
      add :mobile_push_sound, :boolean, default: true
      add :mobile_push_vibration, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:notification_preferences, [:user_id, :workspace_id])

    # Create push_subscriptions table for web push
    create table(:push_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :endpoint, :text, null: false
      add :p256dh_key, :text
      add :auth_key, :text
      add :user_agent, :text
      add :device_type, :string # web, mobile, desktop
      add :is_active, :boolean, default: true
      add :last_used_at, :utc_datetime, default: fragment("now()")

      timestamps(type: :utc_datetime)
    end

    create index(:push_subscriptions, [:user_id])
    create index(:push_subscriptions, [:is_active])
    create unique_index(:push_subscriptions, [:user_id, :endpoint])

    # Create email_digests table
    create table(:email_digests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :digest_type, :string, null: false # daily, weekly
      add :period_start, :utc_datetime, null: false
      add :period_end, :utc_datetime, null: false
      add :messages_count, :integer, default: 0
      add :mentions_count, :integer, default: 0
      add :channels_count, :integer, default: 0
      add :threads_count, :integer, default: 0
      add :sent_at, :utc_datetime
      add :opened_at, :utc_datetime
      add :clicked_at, :utc_datetime
      add :email_subject, :string
      add :email_html, :text
      add :email_text, :text

      timestamps(type: :utc_datetime)
    end

    create index(:email_digests, [:user_id])
    create index(:email_digests, [:workspace_id])
    create index(:email_digests, [:digest_type])
    create index(:email_digests, [:period_start, :period_end])
    create index(:email_digests, [:sent_at])

    # Create mention_detections table
    create table(:mention_detections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :mentioned_user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :mention_type, :string, null: false # @user, @channel, @here, @everyone, keyword
      add :mention_text, :string # The actual mention text
      add :position, :integer # Position in message
      add :is_processed, :boolean, default: false
      add :notification_sent, :boolean, default: false
      add :processed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:mention_detections, [:message_id])
    create index(:mention_detections, [:mentioned_user_id])
    create index(:mention_detections, [:mention_type])
    create index(:mention_detections, [:is_processed])
    create unique_index(:mention_detections, [:message_id, :mentioned_user_id, :mention_type])

    # Create notification_delivery_log table
    create table(:notification_delivery_log, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :notification_id, references(:notifications, type: :binary_id, on_delete: :delete_all), null: false
      add :delivery_method, :string, null: false # push, email, sms
      add :status, :string, null: false # pending, sent, delivered, failed, bounced
      add :external_id, :string # ID from external service (FCM, email service, etc.)
      add :response, :text # Response from external service
      add :attempted_at, :utc_datetime, default: fragment("now()")
      add :delivered_at, :utc_datetime
      add :failed_at, :utc_datetime
      add :failure_reason, :text
      add :retry_count, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:notification_delivery_log, [:notification_id])
    create index(:notification_delivery_log, [:delivery_method])
    create index(:notification_delivery_log, [:status])
    create index(:notification_delivery_log, [:attempted_at])
  end

  def down do
    drop table(:notification_delivery_log)
    drop table(:mention_detections)
    drop table(:email_digests)
    drop table(:push_subscriptions)
    drop table(:notification_preferences)
    drop table(:notifications)
  end
end