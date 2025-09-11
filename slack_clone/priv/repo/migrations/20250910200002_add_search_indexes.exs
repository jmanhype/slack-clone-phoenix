defmodule SlackClone.Repo.Migrations.AddSearchIndexes do
  use Ecto.Migration

  def change do
    # Add full-text search columns and indexes
    alter table(:messages) do
      add :search_vector, :tsvector
      add :indexed_at, :utc_datetime
    end

    # Create GIN index for full-text search
    execute "CREATE INDEX messages_search_vector_gin ON messages USING GIN (search_vector);", 
            "DROP INDEX messages_search_vector_gin;"

    # Create trigger to automatically update search vector
    execute """
    CREATE OR REPLACE FUNCTION update_message_search_vector()
    RETURNS trigger AS $$
    BEGIN
      NEW.search_vector := to_tsvector('english', 
        COALESCE(NEW.content, '') || ' ' || 
        COALESCE((SELECT email FROM users WHERE id = NEW.user_id), '') || ' ' ||
        COALESCE((SELECT name FROM channels WHERE id = NEW.channel_id), '')
      );
      NEW.indexed_at := NOW();
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """, "DROP FUNCTION update_message_search_vector();"

    execute """
    CREATE TRIGGER update_message_search_trigger
    BEFORE INSERT OR UPDATE ON messages
    FOR EACH ROW EXECUTE FUNCTION update_message_search_vector();
    """, "DROP TRIGGER update_message_search_trigger ON messages;"

    # Create search_queries table for analytics
    create table(:search_queries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :workspace_id, references(:workspaces, type: :binary_id, on_delete: :delete_all), null: false
      add :query, :string, null: false
      add :results_count, :integer, default: 0
      add :clicked_result_id, :binary_id
      add :search_type, :string, default: "messages" # messages, files, people, channels
      add :filters, :map, default: %{}
      add :executed_at, :utc_datetime, default: fragment("now()")

      timestamps(type: :utc_datetime)
    end

    create index(:search_queries, [:user_id])
    create index(:search_queries, [:workspace_id])
    create index(:search_queries, [:search_type])
    create index(:search_queries, [:executed_at])

    # Add search indexes to other tables
    alter table(:channels) do
      add :search_vector, :tsvector
    end

    execute "CREATE INDEX channels_search_vector_gin ON channels USING GIN (search_vector);",
            "DROP INDEX channels_search_vector_gin;"

    execute """
    CREATE OR REPLACE FUNCTION update_channel_search_vector()
    RETURNS trigger AS $$
    BEGIN
      NEW.search_vector := to_tsvector('english', 
        COALESCE(NEW.name, '') || ' ' || 
        COALESCE(NEW.description, '') || ' ' ||
        COALESCE(NEW.topic, '')
      );
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """, "DROP FUNCTION update_channel_search_vector();"

    execute """
    CREATE TRIGGER update_channel_search_trigger
    BEFORE INSERT OR UPDATE ON channels
    FOR EACH ROW EXECUTE FUNCTION update_channel_search_vector();
    """, "DROP TRIGGER update_channel_search_trigger ON channels;"

    # Update existing records
    execute """
    UPDATE messages SET search_vector = to_tsvector('english', 
      COALESCE(content, '') || ' ' || 
      COALESCE((SELECT email FROM users WHERE id = messages.user_id), '') || ' ' ||
      COALESCE((SELECT name FROM channels WHERE id = messages.channel_id), '')
    ), indexed_at = NOW();
    """, ""

    execute """
    UPDATE channels SET search_vector = to_tsvector('english', 
      COALESCE(name, '') || ' ' || 
      COALESCE(description, '') || ' ' ||
      COALESCE(topic, '')
    );
    """, ""
  end

  def down do
    execute "DROP TRIGGER update_channel_search_trigger ON channels;"
    execute "DROP TRIGGER update_message_search_trigger ON messages;"
    execute "DROP FUNCTION update_channel_search_vector();"
    execute "DROP FUNCTION update_message_search_vector();"
    
    drop table(:search_queries)
    
    alter table(:channels) do
      remove :search_vector
    end
    
    alter table(:messages) do
      remove :search_vector
      remove :indexed_at
    end
  end
end