defmodule SlackClone.Channels do
  @moduledoc """
  The Channels context for handling channel operations.
  """

  import Ecto.Query, warn: false
  alias SlackClone.Repo
  alias SlackClone.Channels.Channel
  alias SlackClone.Channels.ChannelMembership

  @doc """
  Gets a single channel.
  """
  @spec get_channel(binary()) :: Channel.t() | nil
  def get_channel(id) do
    Repo.get(Channel, id)
  end

  @doc """
  Gets a single channel. Raises if not found.
  """
  @spec get_channel!(binary()) :: Channel.t()
  def get_channel!(id) do
    Repo.get!(Channel, id)
  end

  @doc """
  Lists all channels in a workspace.
  """
  @spec list_workspace_channels(binary()) :: [Channel.t()]
  def list_workspace_channels(workspace_id) do
    from(c in Channel,
      where: c.workspace_id == ^workspace_id and c.is_archived == false,
      order_by: [asc: c.name]
    )
    |> Repo.all()
  end

  @doc """
  Creates a channel.
  """
  @spec create_channel(map()) :: {:ok, Channel.t()} | {:error, Ecto.Changeset.t()}
  def create_channel(attrs \\ %{}) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a channel.
  """
  @spec update_channel(Channel.t(), map()) :: {:ok, Channel.t()} | {:error, Ecto.Changeset.t()}
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a channel.
  """
  @spec delete_channel(Channel.t()) :: {:ok, Channel.t()} | {:error, Ecto.Changeset.t()}
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  @doc """
  Checks if a user can access a channel.

  For public channels, checks if user is a member of the workspace.
  For private channels, checks if user is a channel member.
  """
  @spec can_access?(binary(), binary()) :: boolean()
  def can_access?(channel_id, user_id) do
    case get_channel(channel_id) do
      nil ->
        false

      channel ->
        if channel.is_private do
          # For private channels, check channel membership
          from(m in ChannelMembership,
            where: m.channel_id == ^channel_id and m.user_id == ^user_id
          )
          |> Repo.exists?()
        else
          # For public channels, check workspace membership
          alias SlackClone.Workspaces
          Workspaces.is_member?(channel.workspace_id, user_id)
        end
    end
  rescue
    Ecto.NoResultsError -> false
  end
end