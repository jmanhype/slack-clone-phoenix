defmodule SlackClone.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def up do
    # Message performance indexes
    create index(:messages, [:channel_id, :inserted_at], 
           name: :messages_channel_timeline_idx,
           comment: "Optimizes message timeline queries by channel")
    
    create index(:messages, [:user_id, :inserted_at], 
           name: :messages_user_timeline_idx,
           comment: "Optimizes user message history queries")
    
    create index(:messages, [:thread_id, :inserted_at], where: "thread_id IS NOT NULL",
           name: :messages_thread_timeline_idx,
           comment: "Optimizes thread message loading")
    
    create index(:messages, [:channel_id, :is_deleted, :inserted_at], 
           where: "is_deleted = false",
           name: :messages_active_channel_timeline_idx,
           comment: "Partial index for active messages by channel timeline")
    
    # Full-text search index for message content
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin"
    
    create index(:messages, [:content], 
           using: "gin", 
           name: :messages_content_search_idx,
           comment: "GIN index for full-text search on message content")
    
    # Channel performance indexes
    create index(:channels, [:workspace_id, :is_archived, :is_private], 
           where: "is_archived = false",
           name: :channels_active_workspace_idx,
           comment: "Partial index for active channels in workspace")
    
    create index(:channels, [:workspace_id, :updated_at], 
           name: :channels_workspace_activity_idx,
           comment: "Optimizes recent channel activity queries")
    
    # User and membership indexes
    create index(:workspace_memberships, [:workspace_id, :user_id, :is_active], 
           where: "is_active = true",
           name: :workspace_active_members_idx,
           comment: "Partial index for active workspace members")
    
    create index(:channel_memberships, [:channel_id, :user_id, :is_active], 
           where: "is_active = true",
           name: :channel_active_members_idx,
           comment: "Partial index for active channel members")
    
    create index(:channel_memberships, [:user_id, :channel_id], 
           name: :channel_memberships_user_channels_idx,
           comment: "Optimizes user channel list queries")
    
    # Composite indexes for common queries
    create index(:messages, [:channel_id, :user_id, :inserted_at], 
           name: :messages_channel_user_timeline_idx,
           comment: "Composite index for user messages in channel timeline")
    
    # Statistics collection for query optimizer
    execute "ANALYZE messages"
    execute "ANALYZE channels"
    execute "ANALYZE workspace_memberships"
    execute "ANALYZE channel_memberships"
  end

  def down do
    drop_if_exists index(:messages, [:channel_id, :inserted_at], name: :messages_channel_timeline_idx)
    drop_if_exists index(:messages, [:user_id, :inserted_at], name: :messages_user_timeline_idx)
    drop_if_exists index(:messages, [:thread_id, :inserted_at], name: :messages_thread_timeline_idx)
    drop_if_exists index(:messages, [:channel_id, :is_deleted, :inserted_at], name: :messages_active_channel_timeline_idx)
    drop_if_exists index(:messages, [:content], name: :messages_content_search_idx)
    drop_if_exists index(:channels, [:workspace_id, :is_archived, :is_private], name: :channels_active_workspace_idx)
    drop_if_exists index(:channels, [:workspace_id, :updated_at], name: :channels_workspace_activity_idx)
    drop_if_exists index(:workspace_memberships, [:workspace_id, :user_id, :is_active], name: :workspace_active_members_idx)
    drop_if_exists index(:channel_memberships, [:channel_id, :user_id, :is_active], name: :channel_active_members_idx)
    drop_if_exists index(:channel_memberships, [:user_id, :channel_id], name: :channel_memberships_user_channels_idx)
    drop_if_exists index(:messages, [:channel_id, :user_id, :inserted_at], name: :messages_channel_user_timeline_idx)
  end
end