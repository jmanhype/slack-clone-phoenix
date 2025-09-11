defmodule SlackClone.Repo.Migrations.AddPresenceEnhancements do
  use Ecto.Migration

  def change do
    # Create user_status table for custom statuses
    create table(:user_statuses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "active" # active, away, busy, offline
      add :custom_status, :string
      add :status_emoji, :string
      add :expires_at, :utc_datetime
      add :clear_at, :string # end_of_day, custom_time, never
      add :timezone, :string
      add :is_dnd, :boolean, default: false
      add :dnd_until, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_statuses, [:user_id])
    create index(:user_statuses, [:status])
    create index(:user_statuses, [:expires_at])

    # Create presence_history table for analytics
    create table(:presence_history, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :session_id, :string
      add :device_type, :string # web, mobile, desktop
      add :user_agent, :text
      add :ip_address, :inet
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :duration_seconds, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:presence_history, [:user_id])
    create index(:presence_history, [:workspace_id])
    create index(:presence_history, [:started_at])
    create index(:presence_history, [:status])
    create index(:presence_history, [:session_id])

    # Create typing_indicators table
    create table(:typing_indicators, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all), null: false
      add :thread_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: true
      add :started_at, :utc_datetime, default: fragment("now()")
      add :last_activity_at, :utc_datetime, default: fragment("now()")
      add :expires_at, :utc_datetime
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:typing_indicators, [:user_id, :channel_id, :thread_id])
    create index(:typing_indicators, [:channel_id])
    create index(:typing_indicators, [:thread_id])
    create index(:typing_indicators, [:expires_at])
    create index(:typing_indicators, [:is_active])

    # Create workspace_activity table for workspace-level analytics
    create table(:workspace_activity, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :active_users_count, :integer, default: 0
      add :messages_count_1h, :integer, default: 0
      add :messages_count_24h, :integer, default: 0
      add :peak_concurrent_users, :integer, default: 0
      add :snapshot_at, :utc_datetime, default: fragment("now()")

      timestamps(type: :utc_datetime)
    end

    create index(:workspace_activity, [:workspace_id])
    create index(:workspace_activity, [:snapshot_at])

    # Create user_activity_summary table
    create table(:user_activity_summary, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :total_online_minutes, :integer, default: 0
      add :messages_sent, :integer, default: 0
      add :channels_visited, :integer, default: 0
      add :threads_participated, :integer, default: 0
      add :reactions_given, :integer, default: 0
      add :files_uploaded, :integer, default: 0
      add :first_activity_at, :utc_datetime
      add :last_activity_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_activity_summary, [:user_id, :workspace_id, :date])
    create index(:user_activity_summary, [:workspace_id, :date])
    create index(:user_activity_summary, [:date])
  end

  def down do
    drop table(:user_activity_summary)
    drop table(:workspace_activity)
    drop table(:typing_indicators)
    drop table(:presence_history)
    drop table(:user_statuses)
  end
end