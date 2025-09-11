defmodule SlackClone.Channels.ChannelMembership do
  @moduledoc """
  Schema for channel memberships in the Slack clone application.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias SlackClone.Accounts.User
  alias SlackClone.Channels.Channel

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(admin member guest)

  schema "channel_memberships" do
    field :role, :string, default: "member"
    field :is_active, :boolean, default: true
    field :joined_at, :utc_datetime
    field :left_at, :utc_datetime
    field :last_read_at, :utc_datetime
    field :notifications_enabled, :boolean, default: true

    belongs_to :channel, Channel
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :is_active, :joined_at, :left_at, :last_read_at, :notifications_enabled, :channel_id, :user_id])
    |> validate_required([:role, :channel_id, :user_id])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:channel_id, :user_id])
    |> maybe_set_joined_at()
  end

  def roles, do: @roles

  def update_last_read_changeset(membership) do
    change(membership, last_read_at: DateTime.utc_now())
  end

  defp maybe_set_joined_at(%{changes: %{joined_at: _}} = changeset), do: changeset
  defp maybe_set_joined_at(changeset) do
    case get_field(changeset, :joined_at) do
      nil -> put_change(changeset, :joined_at, DateTime.utc_now())
      _ -> changeset
    end
  end
end