defmodule SlackClone.Workspaces.Workspace do
  @moduledoc """
  Schema for workspaces in the Slack clone application.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias SlackClone.Accounts.User
  alias SlackClone.Channels.Channel
  alias SlackClone.Workspaces.WorkspaceMembership

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workspaces" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :logo_url, :string
    field :is_public, :boolean, default: false

    belongs_to :owner, User
    has_many :channels, Channel
    has_many :memberships, WorkspaceMembership
    many_to_many :members, User, join_through: WorkspaceMembership

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :slug, :description, :logo_url, :is_public, :owner_id])
    |> validate_required([:name, :slug, :owner_id])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:slug, min: 1, max: 50)
    |> validate_format(:slug, ~r/^[a-zA-Z0-9_-]+$/, message: "can only contain letters, numbers, hyphens, and underscores")
    |> unique_constraint(:slug)
    |> maybe_generate_slug()
  end

  defp maybe_generate_slug(%{valid?: true, changes: %{name: name}} = changeset) do
    case get_field(changeset, :slug) do
      nil ->
        slug = 
          name
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9\s_-]/, "")
          |> String.replace(~r/\s+/, "-")
        put_change(changeset, :slug, slug)
      _ -> changeset
    end
  end

  defp maybe_generate_slug(changeset), do: changeset
end