defmodule SlackClone.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def change do
    create table(:workspaces, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :logo_url, :string
      add :is_public, :boolean, default: false, null: false
      add :owner_id, references(:users, type: :binary_id), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:workspaces, [:slug])
    create index(:workspaces, [:owner_id])
  end
end
