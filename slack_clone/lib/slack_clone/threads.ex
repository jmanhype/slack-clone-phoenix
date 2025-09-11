defmodule SlackClone.Threads do
  @moduledoc """
  The Threads context for managing threaded conversations.
  """

  import Ecto.Query, warn: false
  alias SlackClone.Repo
  alias SlackClone.{Messages, Accounts}
  alias SlackClone.Threads.{ThreadSubscription, ThreadParticipant}
  alias SlackClone.Messages.Message
  alias SlackClone.Accounts.User

  ## Thread Management

  @doc """
  Creates a thread reply to an existing message.
  """
  def create_thread_reply(thread_parent, attrs, user) do
    attrs = 
      attrs
      |> Map.put(:thread_id, thread_parent.id)
      |> Map.put(:is_thread_reply, true)
      |> Map.put(:channel_id, thread_parent.channel_id)

    case Messages.create_message(attrs, user) do
      {:ok, message} ->
        # Update thread reply count
        update_thread_reply_count(thread_parent.id)
        
        # Add user as thread participant if not already
        add_thread_participant(thread_parent.id, user.id)
        
        # Subscribe user to thread if not already
        subscribe_to_thread(thread_parent.id, user.id)
        
        # Notify thread subscribers
        notify_thread_subscribers(thread_parent.id, message)
        
        {:ok, message}
      
      error -> error
    end
  end

  @doc """
  Gets a thread with all its replies.
  """
  def get_thread_with_replies(thread_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    thread_parent = 
      Message
      |> where([m], m.id == ^thread_id)
      |> preload([:user, :file_attachments, :reactions])
      |> Repo.one()

    if thread_parent do
      replies = 
        Message
        |> where([m], m.thread_id == ^thread_id)
        |> order_by([m], asc: m.inserted_at)
        |> limit(^limit)
        |> offset(^offset)
        |> preload([:user, :file_attachments, :reactions])
        |> Repo.all()

      %{
        parent: thread_parent,
        replies: replies,
        total_replies: thread_parent.thread_reply_count || 0,
        has_more: length(replies) == limit
      }
    else
      nil
    end
  end

  @doc """
  Gets all threads in a channel.
  """
  def list_channel_threads(channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)
    user_id = Keyword.get(opts, :user_id)

    base_query = 
      Message
      |> where([m], m.channel_id == ^channel_id)
      |> where([m], m.thread_reply_count > 0)
      |> order_by([m], desc: m.updated_at)
      |> limit(^limit)
      |> offset(^offset)
      |> preload([:user, :file_attachments])

    threads = Repo.all(base_query)

    if user_id do
      # Add subscription status for user
      Enum.map(threads, fn thread ->
        subscription = get_thread_subscription(thread.id, user_id)
        Map.put(thread, :user_subscription, subscription)
      end)
    else
      threads
    end
  end

  @doc """
  Gets threads a user is subscribed to.
  """
  def list_user_subscribed_threads(user_id, workspace_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    unread_only = Keyword.get(opts, :unread_only, false)

    base_query = 
      from(ts in ThreadSubscription,
        join: m in Message, on: m.id == ts.thread_id,
        join: c in assoc(m, :channel),
        where: ts.user_id == ^user_id,
        where: c.workspace_id == ^workspace_id,
        order_by: [desc: ts.updated_at],
        limit: ^limit,
        preload: [thread: [:user, :channel]]
      )

    query = 
      if unread_only do
        where(base_query, [ts, m], is_nil(ts.last_read_at) or ts.last_read_at < m.updated_at)
      else
        base_query
      end

    Repo.all(query)
  end

  ## Thread Subscriptions

  @doc """
  Subscribes a user to a thread.
  """
  def subscribe_to_thread(thread_id, user_id, opts \\ []) do
    notification_level = Keyword.get(opts, :notification_level, "all")

    %ThreadSubscription{
      thread_id: thread_id,
      user_id: user_id,
      notification_level: notification_level
    }
    |> ThreadSubscription.changeset(%{})
    |> Repo.insert(
      on_conflict: [set: [notification_level: notification_level, updated_at: DateTime.utc_now()]],
      conflict_target: [:user_id, :thread_id]
    )
  end

  @doc """
  Unsubscribes a user from a thread.
  """
  def unsubscribe_from_thread(thread_id, user_id) do
    ThreadSubscription
    |> where([ts], ts.thread_id == ^thread_id and ts.user_id == ^user_id)
    |> Repo.delete_all()
  end

  @doc """
  Updates thread subscription settings.
  """
  def update_thread_subscription(thread_id, user_id, attrs) do
    case get_thread_subscription(thread_id, user_id) do
      nil ->
        {:error, :not_found}
      
      subscription ->
        subscription
        |> ThreadSubscription.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Marks a thread as read for a user.
  """
  def mark_thread_as_read(thread_id, user_id) do
    now = DateTime.utc_now()
    
    ThreadSubscription
    |> where([ts], ts.thread_id == ^thread_id and ts.user_id == ^user_id)
    |> Repo.update_all(set: [last_read_at: now, updated_at: now])
  end

  @doc """
  Gets a user's subscription to a thread.
  """
  def get_thread_subscription(thread_id, user_id) do
    ThreadSubscription
    |> where([ts], ts.thread_id == ^thread_id and ts.user_id == ^user_id)
    |> Repo.one()
  end

  ## Thread Participants

  @doc """
  Adds a user as a participant in a thread.
  """
  def add_thread_participant(thread_id, user_id) do
    %ThreadParticipant{
      thread_id: thread_id,
      user_id: user_id,
      last_activity_at: DateTime.utc_now()
    }
    |> ThreadParticipant.changeset(%{})
    |> Repo.insert(
      on_conflict: [set: [last_activity_at: DateTime.utc_now(), updated_at: DateTime.utc_now()]],
      conflict_target: [:user_id, :thread_id]
    )
  end

  @doc """
  Gets all participants in a thread.
  """
  def list_thread_participants(thread_id) do
    ThreadParticipant
    |> where([tp], tp.thread_id == ^thread_id)
    |> join(:inner, [tp], u in User, on: u.id == tp.user_id)
    |> order_by([tp], desc: tp.last_activity_at)
    |> preload([:user])
    |> Repo.all()
  end

  ## Private Functions

  defp update_thread_reply_count(thread_id) do
    reply_count = 
      Message
      |> where([m], m.thread_id == ^thread_id)
      |> Repo.aggregate(:count)

    Message
    |> where([m], m.id == ^thread_id)
    |> Repo.update_all(set: [thread_reply_count: reply_count, updated_at: DateTime.utc_now()])
  end

  defp notify_thread_subscribers(thread_id, message) do
    # Get all thread subscribers except the message author
    subscribers = 
      ThreadSubscription
      |> where([ts], ts.thread_id == ^thread_id)
      |> where([ts], ts.user_id != ^message.user_id)
      |> where([ts], ts.notification_level != "none")
      |> preload([:user])
      |> Repo.all()

    # Send notifications asynchronously
    Task.start(fn ->
      Enum.each(subscribers, fn subscription ->
        SlackClone.Notifications.create_thread_reply_notification(
          subscription.user,
          message,
          subscription.notification_level
        )
      end)
    end)
  end

  @doc """
  Gets thread statistics for analytics.
  """
  def get_thread_stats(channel_id, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    start_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    total_threads = 
      Message
      |> where([m], m.channel_id == ^channel_id)
      |> where([m], m.thread_reply_count > 0)
      |> Repo.aggregate(:count)

    active_threads = 
      Message
      |> where([m], m.channel_id == ^channel_id)
      |> where([m], m.thread_reply_count > 0)
      |> where([m], m.updated_at > ^start_date)
      |> Repo.aggregate(:count)

    avg_replies = 
      Message
      |> where([m], m.channel_id == ^channel_id)
      |> where([m], m.thread_reply_count > 0)
      |> Repo.aggregate(:avg, :thread_reply_count)

    %{
      total_threads: total_threads,
      active_threads: active_threads,
      average_replies_per_thread: Float.round(avg_replies || 0.0, 2)
    }
  end
end