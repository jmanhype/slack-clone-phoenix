defmodule SlackClone.Messages do
  @moduledoc """
  The Messages context for handling message operations.
  """

  alias SlackClone.Repo
  alias SlackClone.Messages.Message
  import Ecto.Query, warn: false

  @doc """
  Insert multiple messages in a batch operation.
  Used by MessageBufferServer for efficient bulk inserts.

  Returns a tuple with the number of inserted messages and the list of inserted records.
  """
  @spec insert_messages_batch([map()]) :: {integer(), [Message.t()] | nil}
  def insert_messages_batch(messages) when is_list(messages) do
    # Convert message structs to database format
    message_entries =
      messages
      |> Enum.map(fn message ->
        %{
          channel_id: message.channel_id,
          user_id: message.user_id,
          content: message.content,
          content_type: message.content_type || "text",
          is_edited: message.is_edited || false,
          is_deleted: message.is_deleted || false,
          attachments: message.attachments || [],
          reactions: message.reactions || [],
          inserted_at: message.inserted_at || DateTime.utc_now(),
          updated_at: message.updated_at || DateTime.utc_now()
        }
      end)

    # Use Ecto's insert_all for efficient batch insert
    Repo.insert_all(Message, message_entries, returning: [:id])
  rescue
    error in [Ecto.InvalidChangesetError, Ecto.ConstraintError] ->
      require Logger
      Logger.error("Failed to insert messages batch: #{inspect(error)}")
      {0, nil}
  end

  @doc """
  Get recent messages for a channel.
  Used by ChannelServer to load message history.
  """
  @spec get_recent_messages(binary(), non_neg_integer()) :: [Message.t()]
  def get_recent_messages(channel_id, limit \\ 100) do
    Message
    |> where([m], m.channel_id == ^channel_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()  # Return in chronological order
  rescue
    error ->
      require Logger
      Logger.error("Failed to get recent messages for channel #{channel_id}: #{inspect(error)}")
      []
  end

  @doc """
  Get a single message by ID.
  """
  @spec get_message!(binary()) :: Message.t()
  def get_message!(id), do: Repo.get!(Message, id)

  @doc """
  Create a message.
  """
  @spec create_message(map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update a message.
  """
  @spec update_message(Message.t(), map()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def update_message(%Message{} = message, attrs) do
    message
    |> Message.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a message.
  """
  @spec delete_message(Message.t()) :: {:ok, Message.t()} | {:error, Ecto.Changeset.t()}
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Lists all messages for a channel.
  Used by workspace_live to display channel messages.
  """
  @spec list_channel_messages(binary(), non_neg_integer()) :: [Message.t()]
  def list_channel_messages(channel_id, limit \\ 50) do
    from(m in Message,
      where: m.channel_id == ^channel_id and m.is_deleted == false,
      order_by: [desc: m.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.reverse()  # Return in chronological order
  rescue
    error ->
      require Logger
      Logger.error("Failed to list channel messages for channel #{channel_id}: #{inspect(error)}")
      []
  end
end