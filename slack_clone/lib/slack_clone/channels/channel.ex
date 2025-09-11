defmodule SlackClone.Channels.Channel do
  @moduledoc """
  Schema for channels in the Slack clone application.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias SlackClone.Accounts.User
  alias SlackClone.Workspaces.Workspace
  alias SlackClone.Messages.Message
  alias SlackClone.Channels.ChannelMembership

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "channels" do
    field :name, :string
    field :description, :string
    field :topic, :string
    field :is_private, :boolean, default: false
    field :is_archived, :boolean, default: false

    belongs_to :workspace, Workspace
    belongs_to :created_by, User
    has_many :messages, Message
    has_many :memberships, ChannelMembership
    many_to_many :members, User, join_through: ChannelMembership

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :description, :topic, :is_private, :is_archived, :workspace_id, :created_by_id])
    |> validate_required([:name, :workspace_id, :created_by_id])
    |> validate_length(:name, min: 1, max: 80)
    |> validate_format(:name, ~r/^[a-z0-9_-]+$/, message: "can only contain lowercase letters, numbers, hyphens, and underscores")
    |> unique_constraint([:workspace_id, :name])
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:created_by_id)
  end

  def archive_changeset(channel) do
    change(channel, is_archived: true)
  end

  def unarchive_changeset(channel) do
    change(channel, is_archived: false)
  end
end