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
  def get_channel(id) do
    Repo.get(Channel, id)
  end

  @doc """
  Gets a single channel. Raises if not found.
  """
  def get_channel!(id) do
    Repo.get!(Channel, id)
  end

  @doc """
  Lists all channels in a workspace.
  """
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
  def create_channel(attrs \\ %{}) do
    %Channel{}
    |> Channel.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a channel.
  """
  def update_channel(%Channel{} = channel, attrs) do
    channel
    |> Channel.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a channel.
  """
  def delete_channel(%Channel{} = channel) do
    Repo.delete(channel)
  end

  @doc """
  Checks if a user can access a channel.
  """
  def can_access?(channel_id, user_id) do
    # For public channels, anyone in the workspace can access
    # For private channels, check membership
    channel = get_channel!(channel_id)
    
    if channel.is_private do
      from(m in ChannelMembership,
        where: m.channel_id == ^channel_id and m.user_id == ^user_id
      )
      |> Repo.exists?()
    else
      # For public channels, check if user is in workspace
      # For now, return true (would check workspace membership in full implementation)
      true
    end
  end
end