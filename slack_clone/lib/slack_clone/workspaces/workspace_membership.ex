defmodule SlackClone.Workspaces.WorkspaceMembership do
  @moduledoc """
  Schema for workspace memberships in the Slack clone application.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias SlackClone.Accounts.User
  alias SlackClone.Workspaces.Workspace

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(owner admin member guest)

  schema "workspace_memberships" do
    field :role, :string, default: "member"
    field :is_active, :boolean, default: true
    field :joined_at, :utc_datetime
    field :left_at, :utc_datetime

    belongs_to :workspace, Workspace
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :is_active, :joined_at, :left_at, :workspace_id, :user_id])
    |> validate_required([:role, :workspace_id, :user_id])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:workspace_id, :user_id])
    |> maybe_set_joined_at()
    |> validate_required([:joined_at])
  end

  def roles, do: @roles

  defp maybe_set_joined_at(%{changes: %{joined_at: _}} = changeset), do: changeset
  defp maybe_set_joined_at(changeset) do
    case get_field(changeset, :joined_at) do
      nil -> put_change(changeset, :joined_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end