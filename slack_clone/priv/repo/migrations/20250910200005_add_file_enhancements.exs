defmodule SlackClone.Repo.Migrations.AddFileEnhancements do
  use Ecto.Migration

  def change do
    # Create file_previews table
    create table(:file_previews, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_attachment_id, references(:file_attachments, type: :binary_id, on_delete: :delete_all), null: false
      add :preview_type, :string, null: false # thumbnail, small, medium, large, pdf_page
      add :width, :integer
      add :height, :integer
      add :file_path, :string, null: false
      add :file_size, :integer
      add :mime_type, :string
      add :processing_status, :string, default: "pending" # pending, processing, completed, failed
      add :processing_error, :text
      add :generated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:file_previews, [:file_attachment_id])
    create index(:file_previews, [:preview_type])
    create index(:file_previews, [:processing_status])
    create unique_index(:file_previews, [:file_attachment_id, :preview_type])

    # Create virus_scans table
    create table(:virus_scans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_attachment_id, references(:file_attachments, type: :binary_id, on_delete: :delete_all), null: false
      add :scan_engine, :string, null: false # clamav, virustotal, custom
      add :scan_status, :string, default: "pending" # pending, scanning, clean, infected, error
      add :scan_result, :map, default: %{} # Detailed scan results
      add :threats_found, {:array, :string}, default: []
      add :scan_started_at, :utc_datetime
      add :scan_completed_at, :utc_datetime
      add :quarantined_at, :utc_datetime
      add :false_positive, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:virus_scans, [:file_attachment_id])
    create index(:virus_scans, [:scan_status])
    create index(:virus_scans, [:scan_engine])
    create index(:virus_scans, [:scan_completed_at])

    # Create shareable_links table
    create table(:shareable_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_attachment_id, references(:file_attachments, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :string, null: false # URL-safe token
      add :password_hash, :string # Optional password protection
      add :expires_at, :utc_datetime
      add :max_downloads, :integer
      add :download_count, :integer, default: 0
      add :is_active, :boolean, default: true
      add :allow_preview, :boolean, default: true
      add :require_login, :boolean, default: false
      add :allowed_users, {:array, :binary_id}, default: []
      add :access_log, :map, default: %{} # Track access attempts

      timestamps(type: :utc_datetime)
    end

    create unique_index(:shareable_links, [:token])
    create index(:shareable_links, [:file_attachment_id])
    create index(:shareable_links, [:created_by_user_id])
    create index(:shareable_links, [:expires_at])
    create index(:shareable_links, [:is_active])

    # Create collaborative_editing_sessions table
    create table(:collaborative_editing_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_attachment_id, references(:file_attachments, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :session_token, :string, null: false
      add :document_version, :integer, default: 1
      add :content, :text
      add :content_type, :string # markdown, text, code, etc.
      add :is_active, :boolean, default: true
      add :last_modified_by, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :last_modified_at, :utc_datetime
      add :participants, {:array, :binary_id}, default: []
      add :operations_log, :text # JSON log of operations
      add :auto_save_interval, :integer, default: 30 # seconds

      timestamps(type: :utc_datetime)
    end

    create unique_index(:collaborative_editing_sessions, [:session_token])
    create index(:collaborative_editing_sessions, [:file_attachment_id])
    create index(:collaborative_editing_sessions, [:workspace_id])
    create index(:collaborative_editing_sessions, [:is_active])

    # Create file_operations table for tracking edits
    create table(:file_operations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:collaborative_editing_sessions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :operation_type, :string, null: false # insert, delete, replace, format
      add :position, :integer # Character position
      add :length, :integer # Length of operation
      add :content, :text # Content being inserted/replaced
      add :metadata, :map, default: %{} # Additional operation metadata
      add :applied_at, :utc_datetime, default: fragment("now()")
      add :reverted_at, :utc_datetime
      add :conflict_resolved, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:file_operations, [:session_id])
    create index(:file_operations, [:user_id])
    create index(:file_operations, [:applied_at])
    create index(:file_operations, [:operation_type])

    # Create file_access_log table
    create table(:file_access_log, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_attachment_id, references(:file_attachments, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: true
      add :action, :string, null: false # view, download, preview, share, edit
      add :ip_address, :inet
      add :user_agent, :text
      add :referrer, :string
      add :shareable_link_id, references(:shareable_links, type: :binary_id, on_delete: :nilify_all), null: true
      add :success, :boolean, default: true
      add :error_message, :text
      add :bytes_transferred, :bigint
      add :duration_ms, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:file_access_log, [:file_attachment_id])
    create index(:file_access_log, [:user_id])
    create index(:file_access_log, [:action])
    create index(:file_access_log, [:inserted_at])
    create index(:file_access_log, [:shareable_link_id])

    # Add new columns to existing file_attachments table
    alter table(:file_attachments) do
      add :processing_status, :string, default: "completed" # pending, processing, completed, failed
      add :processing_error, :text
      add :virus_scan_status, :string, default: "clean" # pending, clean, infected, error
      add :is_public, :boolean, default: false
      add :external_url, :string # For files stored externally
      add :tags, {:array, :string}, default: []
      add :version, :integer, default: 1
      add :parent_file_id, references(:file_attachments, type: :binary_id, on_delete: :nilify_all) # For file versions
      add :download_count, :integer, default: 0
      add :last_accessed_at, :utc_datetime
    end

    create index(:file_attachments, [:processing_status])
    create index(:file_attachments, [:virus_scan_status])
    create index(:file_attachments, [:is_public])
    create index(:file_attachments, [:parent_file_id])
    create index(:file_attachments, [:tags])
    create index(:file_attachments, [:version])
  end

  def down do
    alter table(:file_attachments) do
      remove :processing_status
      remove :processing_error
      remove :virus_scan_status
      remove :is_public
      remove :external_url
      remove :tags
      remove :version
      remove :parent_file_id
      remove :download_count
      remove :last_accessed_at
    end

    drop table(:file_access_log)
    drop table(:file_operations)
    drop table(:collaborative_editing_sessions)
    drop table(:shareable_links)
    drop table(:virus_scans)
    drop table(:file_previews)
  end
end