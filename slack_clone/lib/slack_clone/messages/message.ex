defmodule SlackClone.Messages.Message do
  @moduledoc """
  Message schema for Slack clone.
  """
  
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :content, :string
    field :content_type, :string, default: "text"
    field :is_edited, :boolean, default: false
    field :edited_at, :utc_datetime
    field :is_deleted, :boolean, default: false
    field :deleted_at, :utc_datetime
    field :attachments, {:array, :map}, default: []
    field :reactions, {:array, :map}, default: []
    
    belongs_to :channel, SlackClone.Channels.Channel
    belongs_to :user, SlackClone.Accounts.User
    belongs_to :thread, __MODULE__

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:content, :content_type, :is_edited, :edited_at, :is_deleted, :deleted_at, :attachments, :reactions, :channel_id, :user_id, :thread_id])
    |> validate_required([:content, :channel_id, :user_id])
    |> validate_length(:content, min: 1, max: 4000)
    |> validate_inclusion(:content_type, ["text", "markdown", "rich_text"])
  end
end