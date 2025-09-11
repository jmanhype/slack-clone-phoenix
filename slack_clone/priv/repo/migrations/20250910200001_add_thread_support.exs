defmodule SlackClone.Repo.Migrations.AddThreadSupport do
  use Ecto.Migration

  def change do
    # Add additional thread support to messages table (thread_id already exists)
    alter table(:messages) do
      add :is_thread_reply, :boolean, default: false
      add :thread_reply_count, :integer, default: 0
    end

    # Create indexes for thread performance (thread_id index already exists)
    create index(:messages, [:channel_id, :thread_id])
    create index(:messages, [:is_thread_reply])

    # Create thread_subscriptions table for notifications
    create table(:thread_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :thread_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :subscribed_at, :utc_datetime, default: fragment("now()")
      add :last_read_at, :utc_datetime
      add :notification_level, :string, default: "all" # all, mentions, none

      timestamps(type: :utc_datetime)
    end

    create unique_index(:thread_subscriptions, [:user_id, :thread_id])
    create index(:thread_subscriptions, [:thread_id])

    # Create thread_participants table
    create table(:thread_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :thread_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: false
      add :joined_at, :utc_datetime, default: fragment("now()")
      add :last_activity_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:thread_participants, [:user_id, :thread_id])
    create index(:thread_participants, [:thread_id])

    # Update existing messages to set thread_reply_count
    execute """
    UPDATE messages 
    SET thread_reply_count = (
      SELECT COUNT(*) 
      FROM messages replies 
      WHERE replies.thread_id = messages.id
    )
    WHERE id IN (
      SELECT DISTINCT thread_id 
      FROM messages 
      WHERE thread_id IS NOT NULL
    );
    """, ""
  end

  def down do
    drop table(:thread_participants)
    drop table(:thread_subscriptions)
    
    alter table(:messages) do
      remove :thread_id
      remove :is_thread_reply
      remove :thread_reply_count
    end
  end
end