defmodule SlackClone.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :content, :text, null: false
      add :content_type, :string, default: "text", null: false
      add :is_edited, :boolean, default: false, null: false
      add :edited_at, :utc_datetime
      add :is_deleted, :boolean, default: false, null: false
      add :deleted_at, :utc_datetime
      add :thread_id, references(:messages, type: :binary_id)
      add :channel_id, references(:channels, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id), null: false
      add :attachments, {:array, :map}, default: []
      add :reactions, {:array, :map}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:channel_id])
    create index(:messages, [:user_id])
    create index(:messages, [:thread_id])
    create index(:messages, [:inserted_at])
    create index(:messages, [:is_deleted])
  end
end
