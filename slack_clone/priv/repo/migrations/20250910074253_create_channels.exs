defmodule SlackClone.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :is_private, :boolean, default: false, null: false
      add :is_archived, :boolean, default: false, null: false
      add :workspace_id, references(:workspaces, type: :binary_id), null: false
      add :created_by_id, references(:users, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:channels, [:workspace_id])
    create index(:channels, [:created_by_id])
    create unique_index(:channels, [:workspace_id, :name])
  end
end
