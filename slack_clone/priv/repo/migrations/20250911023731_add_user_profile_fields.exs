defmodule SlackClone.Repo.Migrations.AddUserProfileFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string
      add :username, :string
      add :avatar_url, :string
      add :role, :string, default: "member"
      add :status, :string, default: "active"
      add :timezone, :string
    end

    create unique_index(:users, [:username])
  end
end
