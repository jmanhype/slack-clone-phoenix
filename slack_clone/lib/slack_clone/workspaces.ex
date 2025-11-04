defmodule SlackClone.Workspaces do
  @moduledoc """
  The Workspaces context for handling workspace operations.
  """

  import Ecto.Query, warn: false
  alias SlackClone.Repo
  alias SlackClone.Workspaces.{Workspace, WorkspaceMembership}

  @doc """
  Gets a single workspace.
  """
  @spec get_workspace(binary()) :: Workspace.t() | nil
  def get_workspace(id) do
    Repo.get(Workspace, id)
  end

  @doc """
  Gets a single workspace. Raises if not found.

  Accepts either a UUID or a workspace slug.
  """
  @spec get_workspace!(binary()) :: Workspace.t()
  def get_workspace!(id) when is_binary(id) do
    # Try to parse as UUID first, fallback to slug lookup
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        Repo.get!(Workspace, uuid)
      :error ->
        # Try looking up by slug
        case Repo.get_by(Workspace, slug: id) do
          nil -> raise Ecto.NoResultsError, queryable: Workspace
          workspace -> workspace
        end
    end
  end

  def get_workspace!(id), do: Repo.get!(Workspace, id)

  @doc """
  Updates a workspace.
  """
  @spec update_workspace(Workspace.t(), map()) :: {:ok, Workspace.t()} | {:error, Ecto.Changeset.t()}
  def update_workspace(%Workspace{} = workspace, attrs) do
    workspace
    |> Workspace.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a workspace.
  """
  @spec create_workspace(map()) :: {:ok, Workspace.t()} | {:error, Ecto.Changeset.t()}
  def create_workspace(attrs \\ %{}) do
    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a workspace membership.
  """
  @spec create_workspace_membership(map()) :: {:ok, WorkspaceMembership.t()} | {:error, Ecto.Changeset.t()}
  def create_workspace_membership(attrs \\ %{}) do
    %WorkspaceMembership{}
    |> WorkspaceMembership.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists all channels in a workspace.
  """
  @spec list_workspace_channels(binary()) :: [SlackClone.Channels.Channel.t()]
  def list_workspace_channels(workspace_id) do
    alias SlackClone.Channels.Channel

    from(c in Channel,
      where: c.workspace_id == ^workspace_id,
      order_by: [asc: c.name]
    )
    |> Repo.all()
  rescue
    error ->
      require Logger
      Logger.error("Failed to list workspace channels for workspace #{workspace_id}: #{inspect(error)}")
      []
  end

  @doc """
  Checks if a user is a member of a workspace.
  """
  @spec is_member?(binary(), binary()) :: boolean()
  def is_member?(workspace_id, user_id) do
    alias SlackClone.Workspaces.WorkspaceMembership

    query = from(m in WorkspaceMembership,
      where: m.workspace_id == ^workspace_id and m.user_id == ^user_id
    )

    Repo.exists?(query)
  rescue
    error ->
      require Logger
      Logger.error("Failed to check workspace membership: #{inspect(error)}")
      false
  end

  @doc """
  Lists all workspaces for a user.
  """
  @spec list_user_workspaces(binary()) :: [Workspace.t()]
  def list_user_workspaces(user_id) do
    from(w in Workspace,
      join: m in assoc(w, :memberships),
      where: m.user_id == ^user_id,
      order_by: [asc: w.name],
      preload: [:owner]
    )
    |> Repo.all()
  rescue
    error ->
      require Logger
      Logger.error("Failed to list user workspaces for user #{user_id}: #{inspect(error)}")
      []
  end

  @doc """
  Gets the first workspace for a user (for initial login redirect).
  """
  @spec get_user_first_workspace(binary()) :: Workspace.t() | nil
  def get_user_first_workspace(user_id) do
    from(w in Workspace,
      join: m in assoc(w, :memberships),
      where: m.user_id == ^user_id,
      order_by: [asc: w.name],
      limit: 1
    )
    |> Repo.one()
  rescue
    error ->
      require Logger
      Logger.error("Failed to get first workspace for user #{user_id}: #{inspect(error)}")
      nil
  end
end