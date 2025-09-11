defmodule SlackClone.Repo.Migrations.CreateFileAttachments do
  use Ecto.Migration

  def change do
    create table(:file_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :file_path, :string, null: false
      add :upload_status, :string, default: "pending" # pending, processing, completed, failed
      add :uploaded_by_user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all), null: true
      add :message_id, references(:messages, type: :binary_id, on_delete: :delete_all), null: true
      add :checksum, :string # File integrity verification
      add :metadata, :map, default: %{} # Additional file metadata
      
      timestamps(type: :utc_datetime)
    end

    create index(:file_attachments, [:uploaded_by_user_id])
    create index(:file_attachments, [:workspace_id])
    create index(:file_attachments, [:channel_id])
    create index(:file_attachments, [:message_id])
    create index(:file_attachments, [:content_type])
    create index(:file_attachments, [:upload_status])
    create index(:file_attachments, [:inserted_at])
    create unique_index(:file_attachments, [:checksum])
  end

  def down do
    drop table(:file_attachments)
  end
end