defmodule SlackClone.Repo.Migrations.CreateChannelMemberships do
  use Ecto.Migration

  def change do
    create table(:channel_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, default: "member", null: false
      add :is_active, :boolean, default: true, null: false
      add :joined_at, :utc_datetime, null: false
      add :left_at, :utc_datetime
      add :last_read_at, :utc_datetime
      add :notifications_enabled, :boolean, default: true, null: false
      add :channel_id, references(:channels, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:channel_memberships, [:channel_id, :user_id])
    create index(:channel_memberships, [:user_id])
    create index(:channel_memberships, [:is_active])
  end
end
