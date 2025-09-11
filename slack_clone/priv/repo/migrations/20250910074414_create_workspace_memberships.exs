defmodule SlackClone.Repo.Migrations.CreateWorkspaceMemberships do
  use Ecto.Migration

  def change do
    create table(:workspace_memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, default: "member", null: false
      add :is_active, :boolean, default: true, null: false
      add :joined_at, :utc_datetime, null: false
      add :left_at, :utc_datetime
      add :workspace_id, references(:workspaces, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspace_memberships, [:workspace_id, :user_id])
    create index(:workspace_memberships, [:user_id])
    create index(:workspace_memberships, [:is_active])
  end
end
