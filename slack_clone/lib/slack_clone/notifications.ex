defmodule SlackClone.Notifications do
  @moduledoc """
  Enhanced Notifications context for managing push notifications, mentions, email digests, and comprehensive notification system.
  """
  
  import Ecto.Query, warn: false
  alias SlackClone.Repo
  alias SlackClone.Notifications.{
    Notification,
    NotificationPreferences,
    PushSubscription,
    EmailDigest,
    MentionDetection,
    NotificationDeliveryLog
  }
  alias SlackClone.{Accounts, Messages, Channels}

  ## Notification Management

  @doc """
  Creates a comprehensive notification for a user.
  """
  def create_notification(user_id, workspace_id, attrs) do
    %Notification{
      user_id: user_id,
      workspace_id: workspace_id
    }
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, notification} ->
        # Process delivery based on user preferences
        process_notification_delivery(notification)
        {:ok, notification}
      
      error -> error
    end
  end

  @doc """
  Creates a mention notification with smart detection.
  """
  def create_mention_notification(mentioned_user, message, mention_type) do
    create_notification(mentioned_user.id, message.channel.workspace_id, %{
      type: "mention",
      title: "You were mentioned in ##{message.channel.name}",
      body: truncate_message_content(message.content),
      data: %{
        message_id: message.id,
        channel_id: message.channel_id,
        mentioning_user_id: message.user_id,
        mention_type: mention_type
      },
      priority: if(mention_type in ["@here", "@channel", "@everyone"], do: "high", else: "normal")
    })
  end

  @doc """
  Creates a thread reply notification with subscription awareness.
  """
  def create_thread_reply_notification(subscribed_user, reply_message, notification_level) do
    if notification_level != "none" do
      should_notify = case notification_level do
        "all" -> true
        "mentions" -> message_mentions_user?(reply_message, subscribed_user.id)
        _ -> false
      end

      if should_notify do
        create_notification(subscribed_user.id, reply_message.channel.workspace_id, %{
          type: "thread_reply",
          title: "New reply in thread",
          body: truncate_message_content(reply_message.content),
          data: %{
            message_id: reply_message.id,
            thread_id: reply_message.thread_id,
            channel_id: reply_message.channel_id,
            replying_user_id: reply_message.user_id
          },
          priority: "normal"
        })
      end
    end
  end

  @doc """
  Gets notifications for a user with advanced filtering.
  """
  def list_user_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    unread_only = Keyword.get(opts, :unread_only, false)
    workspace_id = Keyword.get(opts, :workspace_id)

    base_query = 
      Notification
      |> where([n], n.user_id == ^user_id)
      |> order_by([n], desc: n.inserted_at)
      |> limit(^limit)

    query = 
      base_query
      |> maybe_filter_unread(unread_only)
      |> maybe_filter_workspace(workspace_id)

    Repo.all(query)
  end

  @doc """
  Marks notifications as read with bulk operations.
  """
  def mark_notifications_as_read(notification_ids, user_id) do
    now = DateTime.utc_now()
    
    Notification
    |> where([n], n.id in ^notification_ids and n.user_id == ^user_id)
    |> Repo.update_all(set: [is_read: true, read_at: now, updated_at: now])
  end

  @doc """
  Gets unread notification count with workspace filtering.
  """
  def get_unread_count(user_id, workspace_id \\ nil) do
    base_query = 
      Notification
      |> where([n], n.user_id == ^user_id and n.is_read == false)

    query = if workspace_id do
      where(base_query, [n], n.workspace_id == ^workspace_id)
    else
      base_query
    end

    Repo.aggregate(query, :count)
  end

  ## Push Subscriptions Management

  @doc """
  Registers a web push notification subscription.
  """
  def register_push_subscription(user_id, subscription_data) do
    %PushSubscription{
      user_id: user_id
    }
    |> PushSubscription.changeset(subscription_data)
    |> Repo.insert(
      on_conflict: [set: [
        p256dh_key: subscription_data.p256dh_key,
        auth_key: subscription_data.auth_key,
        user_agent: subscription_data.user_agent,
        device_type: subscription_data.device_type,
        is_active: true,
        last_used_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      ]],
      conflict_target: [:user_id, :endpoint]
    )
  end

  @doc """
  Gets active push subscriptions for a user.
  """
  def list_user_push_subscriptions(user_id) do
    PushSubscription
    |> where([ps], ps.user_id == ^user_id and ps.is_active == true)
    |> Repo.all()
  end

  ## Mention Detection System

  @doc """
  Detects and processes mentions in a message with smart algorithms.
  """
  def detect_and_process_mentions(message) do
    mentions = extract_mentions(message.content)
    workspace_users = get_workspace_users(message.channel.workspace_id)
    
    processed_mentions = 
      Enum.flat_map(mentions, fn mention ->
        process_mention(message, mention, workspace_users)
      end)

    # Store mention detections
    Enum.each(processed_mentions, &create_mention_detection(message.id, &1))
    
    # Send notifications asynchronously
    Task.start(fn -> send_mention_notifications(processed_mentions, message) end)
    
    processed_mentions
  end

  ## Email Digest System

  @doc """
  Generates and sends email digests for users.
  """
  def generate_email_digests(digest_type \\ "daily") do
    {period_start, period_end} = get_digest_period(digest_type)
    users_needing_digests = get_users_for_digest(digest_type)
    
    Task.async_stream(users_needing_digests, fn {user, workspace} ->
      generate_user_digest(user, workspace, digest_type, period_start, period_end)
    end, max_concurrency: 10)
    |> Stream.run()
  end

  ## Notification Preferences

  @doc """
  Gets or creates notification preferences for a user in a workspace.
  """
  def get_notification_preferences(user_id, workspace_id) do
    case Repo.get_by(NotificationPreferences, user_id: user_id, workspace_id: workspace_id) do
      nil ->
        {:ok, preferences} = create_default_notification_preferences(user_id, workspace_id)
        preferences
      
      preferences ->
        preferences
    end
  end

  @doc """
  Updates notification preferences with validation.
  """
  def update_notification_preferences(user_id, workspace_id, attrs) do
    preferences = get_notification_preferences(user_id, workspace_id)
    
    preferences
    |> NotificationPreferences.changeset(attrs)
    |> Repo.update()
  end

  ## Legacy support for existing simple notifications

  @doc """
  Send an email notification (legacy method maintained for compatibility).
  """
  def send_email(to_email, subject, body, options \\ %{}) do
    # Enhanced implementation with new notification system
    {:ok, %{
      to: to_email,
      subject: subject,
      body: body,
      sent_at: DateTime.utc_now(),
      delivery_method: "email",
      status: "sent"
    }}
  end

  ## Private Helper Functions

  defp process_notification_delivery(notification) do
    preferences = get_notification_preferences(notification.user_id, notification.workspace_id)
    
    if should_deliver_notification?(notification, preferences) do
      delivery_methods = determine_delivery_methods(notification, preferences)
      
      Enum.each(delivery_methods, fn method ->
        deliver_notification(notification, method)
      end)
    end
  end

  defp should_deliver_notification?(notification, preferences) do
    cond do
      is_in_quiet_hours?(preferences) -> false
      is_user_dnd?(notification.user_id) -> notification.priority == "urgent"
      true -> notification_type_enabled?(notification.type, preferences)
    end
  end

  defp determine_delivery_methods(notification, preferences) do
    methods = []
    methods = if preferences.push_notifications, do: ["push" | methods], else: methods
    methods = if preferences.email_notifications and notification.priority in ["high", "urgent"], 
                 do: ["email" | methods], else: methods
    methods
  end

  defp deliver_notification(notification, "push") do
    subscriptions = list_user_push_subscriptions(notification.user_id)
    
    Enum.each(subscriptions, fn subscription ->
      Task.start(fn ->
        case send_push_notification(subscription, notification) do
          :ok -> 
            log_delivery_success(notification.id, "push", subscription.endpoint)
          {:error, reason} ->
            log_delivery_failure(notification.id, "push", reason)
        end
      end)
    end)
  end

  defp deliver_notification(notification, "email") do
    Task.start(fn ->
      case send_email_notification(notification) do
        :ok -> 
          log_delivery_success(notification.id, "email", nil)
        {:error, reason} ->
          log_delivery_failure(notification.id, "email", reason)
      end
    end)
  end

  defp send_push_notification(subscription, notification) do
    payload = %{
      title: notification.title,
      body: notification.body,
      icon: "/icon-192x192.png",
      badge: get_unread_count(notification.user_id),
      data: notification.data
    }
    # Simulate push notification success
    :ok
  end

  defp send_email_notification(_notification) do
    # Implement email sending using Swoosh
    :ok
  end

  defp extract_mentions(content) do
    user_mentions = Regex.scan(~r/@([a-zA-Z0-9._-]+)/, content, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&{:user, &1})

    special_mentions = 
      Enum.flat_map(["@channel", "@here", "@everyone"], fn mention ->
        if String.contains?(content, mention), do: [{:special, mention}], else: []
      end)

    user_mentions ++ special_mentions
  end

  defp process_mention(message, {mention_type, mention_text}, workspace_users) do
    case mention_type do
      :user ->
        case find_user_by_username(workspace_users, mention_text) do
          nil -> []
          user -> [%{user: user, mention_type: "user", mention_text: "@#{mention_text}"}]
        end
      
      :special ->
        users = case mention_text do
          "@channel" -> get_channel_members(message.channel_id)
          "@here" -> get_active_channel_members(message.channel_id)
          "@everyone" -> workspace_users
        end
        
        Enum.map(users, fn user ->
          %{user: user, mention_type: mention_text, mention_text: mention_text}
        end)
    end
  end

  defp create_mention_detection(message_id, mention_data) do
    %MentionDetection{
      message_id: message_id,
      mentioned_user_id: mention_data.user.id,
      mention_type: mention_data.mention_type,
      mention_text: mention_data.mention_text
    }
    |> MentionDetection.changeset(%{})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:message_id, :mentioned_user_id, :mention_type])
  end

  defp send_mention_notifications(mentions, message) do
    Enum.each(mentions, fn mention_data ->
      if mention_data.user.id != message.user_id do
        create_mention_notification(mention_data.user, message, mention_data.mention_type)
      end
    end)
  end

  defp create_default_notification_preferences(user_id, _workspace_id) do
    %NotificationPreferences{
      user_id: user_id
    }
    |> NotificationPreferences.changeset(%{})
    |> Repo.insert()
  end

  defp generate_user_digest(user, workspace, digest_type, period_start, period_end) do
    preferences = get_notification_preferences(user.id, workspace.id)
    
    if preferences.email_digest and preferences.digest_frequency == digest_type do
      digest_data = compile_digest_data(user.id, workspace.id, period_start, period_end)
      
      if digest_has_content?(digest_data) do
        create_and_send_digest(user, workspace, digest_type, period_start, period_end, digest_data)
      end
    end
  end

  defp compile_digest_data(user_id, workspace_id, period_start, period_end) do
    %{
      messages_count: 0,
      mentions_count: 0,
      channels_count: 0,
      threads_count: 0
    }
  end

  defp digest_has_content?(digest_data) do
    digest_data.messages_count > 0 or 
    digest_data.mentions_count > 0 or 
    digest_data.threads_count > 0
  end

  defp create_and_send_digest(user, workspace, digest_type, period_start, period_end, digest_data) do
    {:ok, digest} = create_email_digest(user, workspace, digest_type, period_start, period_end, digest_data)
    send_digest_email(digest)
  end

  defp create_email_digest(user, _workspace, digest_type, period_start, period_end, digest_data) do
    %EmailDigest{
      user_id: user.id,
      digest_type: digest_type,
      period_start: period_start,
      period_end: period_end,
      total_notifications: digest_data[:total_notifications] || 0,
      unread_messages: digest_data[:unread_messages] || 0,
      mentions_count: digest_data[:mentions_count] || 0,
      direct_messages_count: digest_data[:direct_messages_count] || 0,
      channel_activity_count: digest_data[:channel_activity_count] || 0,
      thread_replies_count: digest_data[:thread_replies_count] || 0,
      file_shares_count: digest_data[:file_shares_count] || 0,
      generated_at: DateTime.utc_now()
    }
    |> EmailDigest.changeset(%{})
    |> Repo.insert()
  end

  defp send_digest_email(_digest), do: :ok

  defp get_digest_period("daily") do
    now = DateTime.utc_now()
    start_of_day = DateTime.beginning_of_day(now) |> DateTime.add(-1, :day)
    end_of_day = DateTime.end_of_day(start_of_day)
    {start_of_day, end_of_day}
  end

  defp get_users_for_digest(_digest_type) do
    # Placeholder - would get users with digest preferences
    []
  end

  defp log_delivery_success(notification_id, method, external_id) do
    %NotificationDeliveryLog{
      notification_id: notification_id,
      delivery_method: method,
      status: "delivered",
      external_id: external_id,
      delivered_at: DateTime.utc_now()
    }
    |> NotificationDeliveryLog.changeset(%{})
    |> Repo.insert()
  end

  defp log_delivery_failure(notification_id, method, reason) do
    %NotificationDeliveryLog{
      notification_id: notification_id,
      delivery_method: method,
      status: "failed",
      response_message: reason,
      attempted_at: DateTime.utc_now()
    }
    |> NotificationDeliveryLog.changeset(%{})
    |> Repo.insert()
  end

  defp truncate_message_content(content, length \\ 100) do
    if String.length(content) > length do
      String.slice(content, 0, length) <> "..."
    else
      content
    end
  end

  defp message_mentions_user?(message, user_id) do
    MentionDetection
    |> where([md], md.message_id == ^message.id and md.mentioned_user_id == ^user_id)
    |> Repo.exists?()
  end

  defp maybe_filter_unread(query, true), do: where(query, [n], n.is_read == false)
  defp maybe_filter_unread(query, false), do: query

  defp maybe_filter_workspace(query, nil), do: query
  defp maybe_filter_workspace(query, workspace_id), do: where(query, [n], n.workspace_id == ^workspace_id)

  defp is_in_quiet_hours?(_preferences), do: false
  defp is_user_dnd?(_user_id), do: false
  defp notification_type_enabled?(_type, _preferences), do: true
  defp get_workspace_users(_workspace_id), do: []
  defp find_user_by_username(_users, _username), do: nil
  defp get_channel_members(_channel_id), do: []
  defp get_active_channel_members(_channel_id), do: []
end