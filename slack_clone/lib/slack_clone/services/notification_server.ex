defmodule SlackClone.Services.NotificationServer do
  @moduledoc """
  GenServer for queuing and dispatching notifications.
  Handles push notifications, email notifications, and in-app alerts.
  """

  use GenServer
  require Logger

  alias SlackClone.Notifications
  alias SlackClone.Accounts
  alias Phoenix.PubSub

  @batch_size 50
  @batch_timeout 2_000
  @retry_attempts 3
  @retry_backoff 1_000
  @cleanup_interval 300_000  # 5 minutes

  defstruct [
    :notification_queue,
    :processing_queue,
    :timer_ref,
    :stats,
    :failed_notifications
  ]

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Queue a notification for delivery
  """
  def queue_notification(type, recipient_id, payload, options \\ []) do
    notification = %{
      id: generate_notification_id(),
      type: type,
      recipient_id: recipient_id,
      payload: payload,
      priority: Keyword.get(options, :priority, :normal),
      retry_count: 0,
      created_at: DateTime.utc_now(),
      scheduled_for: Keyword.get(options, :scheduled_for, DateTime.utc_now())
    }
    
    GenServer.cast(__MODULE__, {:queue_notification, notification})
  end

  @doc """
  Queue multiple notifications
  """
  def queue_notifications(notifications) when is_list(notifications) do
    GenServer.cast(__MODULE__, {:queue_notifications, notifications})
  end

  @doc """
  Get notification queue status
  """
  def get_queue_status do
    GenServer.call(__MODULE__, :get_queue_status)
  end

  @doc """
  Force process all queued notifications
  """
  def process_queue do
    GenServer.cast(__MODULE__, :process_queue)
  end

  @doc """
  Get notification statistics
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Retry failed notifications
  """
  def retry_failed_notifications do
    GenServer.cast(__MODULE__, :retry_failed)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting NotificationServer")
    
    # Schedule periodic cleanup
    :timer.send_interval(@cleanup_interval, :cleanup_old_notifications)
    
    state = %__MODULE__{
      notification_queue: :queue.new(),
      processing_queue: :queue.new(),
      timer_ref: nil,
      failed_notifications: [],
      stats: %{
        queued: 0,
        processing: 0,
        sent: 0,
        failed: 0,
        retries: 0,
        last_processed: nil,
        uptime: DateTime.utc_now()
      }
    }
    
    {:ok, state}
  end

  @impl true
  def handle_cast({:queue_notification, notification}, state) do
    Logger.debug("Queuing notification: #{notification.type} for user #{notification.recipient_id}")
    
    # Add to queue based on priority
    new_queue = case notification.priority do
      :high -> :queue.in_r(notification, state.notification_queue)  # Front of queue
      _ -> :queue.in(notification, state.notification_queue)         # Back of queue
    end
    
    queue_size = :queue.len(new_queue)
    
    # Start processing if queue reaches batch size or set timer
    new_timer_ref = if queue_size >= @batch_size do
      cancel_timer(state.timer_ref)
      send(self(), :process_batch)
      nil
    else
      if state.timer_ref == nil do
        Process.send_after(self(), :process_batch, @batch_timeout)
      else
        state.timer_ref
      end
    end
    
    new_stats = %{state.stats | queued: queue_size}
    
    {:noreply, %{state | 
      notification_queue: new_queue, 
      timer_ref: new_timer_ref,
      stats: new_stats
    }}
  end

  def handle_cast({:queue_notifications, notifications}, state) do
    Logger.info("Queuing #{length(notifications)} notifications")
    
    # Add all notifications to queue
    new_queue = 
      notifications
      |> Enum.reduce(state.notification_queue, fn notification, queue ->
        case notification.priority do
          :high -> :queue.in_r(notification, queue)
          _ -> :queue.in(notification, queue)
        end
      end)
    
    queue_size = :queue.len(new_queue)
    
    # Trigger immediate processing if significant batch
    new_timer_ref = if queue_size >= @batch_size do
      cancel_timer(state.timer_ref)
      send(self(), :process_batch)
      nil
    else
      state.timer_ref
    end
    
    new_stats = %{state.stats | queued: queue_size}
    
    {:noreply, %{state | 
      notification_queue: new_queue, 
      timer_ref: new_timer_ref,
      stats: new_stats
    }}
  end

  def handle_cast(:process_queue, state) do
    cancel_timer(state.timer_ref)
    send(self(), :process_batch)
    {:noreply, %{state | timer_ref: nil}}
  end

  def handle_cast(:retry_failed, state) do
    if length(state.failed_notifications) > 0 do
      Logger.info("Retrying #{length(state.failed_notifications)} failed notifications")
      
      # Move failed notifications back to queue
      new_queue = 
        state.failed_notifications
        |> Enum.reduce(state.notification_queue, fn notification, queue ->
          updated_notification = %{notification | retry_count: notification.retry_count + 1}
          :queue.in(updated_notification, queue)
        end)
      
      new_stats = %{
        state.stats | 
        queued: :queue.len(new_queue),
        retries: state.stats.retries + length(state.failed_notifications)
      }
      
      {:noreply, %{state | 
        notification_queue: new_queue,
        failed_notifications: [],
        stats: new_stats
      }}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call(:get_queue_status, _from, state) do
    status = %{
      queued: :queue.len(state.notification_queue),
      processing: :queue.len(state.processing_queue),
      failed: length(state.failed_notifications)
    }
    
    {:reply, status, state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info(:process_batch, state) do
    new_state = process_notification_batch(state)
    {:noreply, %{new_state | timer_ref: nil}}
  end

  def handle_info({:notification_result, notification_id, result}, state) do
    new_state = handle_notification_result(state, notification_id, result)
    {:noreply, new_state}
  end

  def handle_info(:cleanup_old_notifications, state) do
    Logger.debug("Cleaning up old failed notifications")
    
    cutoff_time = DateTime.add(DateTime.utc_now(), -86400, :second)  # 24 hours ago
    
    new_failed_notifications = 
      state.failed_notifications
      |> Enum.reject(fn notification ->
        DateTime.compare(notification.created_at, cutoff_time) == :lt
      end)
    
    cleaned_count = length(state.failed_notifications) - length(new_failed_notifications)
    
    if cleaned_count > 0 do
      Logger.info("Cleaned up #{cleaned_count} old failed notifications")
    end
    
    {:noreply, %{state | failed_notifications: new_failed_notifications}}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("NotificationServer terminating: #{inspect(reason)}")
    
    # Cancel timer
    cancel_timer(state.timer_ref)
    
    # Log remaining notifications
    queued_count = :queue.len(state.notification_queue)
    processing_count = :queue.len(state.processing_queue)
    failed_count = length(state.failed_notifications)
    
    if queued_count + processing_count + failed_count > 0 do
      Logger.warn("Shutting down with #{queued_count} queued, #{processing_count} processing, #{failed_count} failed notifications")
    end
    
    :ok
  end

  ## Private Functions

  defp process_notification_batch(state) do
    if :queue.is_empty(state.notification_queue) do
      state
    else
      Logger.info("Processing notification batch")
      
      # Extract batch from queue
      {batch, remaining_queue} = extract_batch(state.notification_queue, @batch_size, [])
      
      # Move batch to processing queue
      new_processing_queue = 
        batch
        |> Enum.reduce(state.processing_queue, fn notification, queue ->
          :queue.in(notification, queue)
        end)
      
      # Process notifications asynchronously
      Enum.each(batch, &process_notification/1)
      
      new_stats = %{
        state.stats |
        queued: :queue.len(remaining_queue),
        processing: :queue.len(new_processing_queue),
        last_processed: DateTime.utc_now()
      }
      
      %{state |
        notification_queue: remaining_queue,
        processing_queue: new_processing_queue,
        stats: new_stats
      }
    end
  end

  defp extract_batch(queue, 0, acc), do: {Enum.reverse(acc), queue}
  defp extract_batch(queue, count, acc) do
    case :queue.out(queue) do
      {:empty, queue} -> {Enum.reverse(acc), queue}
      {{:value, item}, remaining_queue} ->
        extract_batch(remaining_queue, count - 1, [item | acc])
    end
  end

  defp process_notification(notification) do
    Logger.debug("Processing notification #{notification.id}")
    
    # Check if notification is scheduled for future
    result = if DateTime.compare(notification.scheduled_for, DateTime.utc_now()) == :gt do
      # Reschedule for later
      delay = DateTime.diff(notification.scheduled_for, DateTime.utc_now(), :millisecond)
      Process.send_after(self(), {:queue_notification, notification}, delay)
      send(self(), {:notification_result, notification.id, {:ok, :rescheduled}})
      {:ok, :rescheduled}
    else
      # Process based on notification type
      case notification.type do
        :push_notification -> send_push_notification(notification)
        :email -> send_email_notification(notification)
        :in_app -> send_in_app_notification(notification)
        :webhook -> send_webhook_notification(notification)
        _ -> {:error, :unknown_type}
      end
    end
    
    # Send result back to server
    send(self(), {:notification_result, notification.id, result})
  end

  defp send_push_notification(notification) do
    try do
      # Get user's device tokens
      case Accounts.get_user_device_tokens(notification.recipient_id) do
        [] ->
          {:error, :no_devices}
          
        device_tokens ->
          # Send push notification to all devices
          results = 
            device_tokens
            |> Enum.map(fn token ->
              # This would integrate with FCM, APNS, etc.
              send_to_device(token, notification.payload)
            end)
          
          # Check if any succeeded
          if Enum.any?(results, &match?({:ok, _}, &1)) do
            {:ok, :sent}
          else
            {:error, :all_devices_failed}
          end
      end
    rescue
      error -> {:error, error}
    end
  end

  defp send_email_notification(notification) do
    try do
      case Accounts.get_user_email(notification.recipient_id) do
        nil ->
          {:error, :no_email}
          
        email ->
          # This would integrate with your email service
          Notifications.send_email(
            email,
            notification.payload.subject,
            notification.payload.body,
            notification.payload
          )
      end
    rescue
      error -> {:error, error}
    end
  end

  defp send_in_app_notification(notification) do
    try do
      # Store notification in database
      {:ok, stored_notification} = Notifications.create_notification(%{
        user_id: notification.recipient_id,
        type: notification.type,
        title: notification.payload.title,
        message: notification.payload.message,
        metadata: notification.payload.metadata || %{},
        read: false
      })
      
      # Broadcast to user's live sessions
      PubSub.broadcast(
        SlackClone.PubSub,
        "user:#{notification.recipient_id}:notifications",
        {:new_notification, stored_notification}
      )
      
      {:ok, :sent}
    rescue
      error -> {:error, error}
    end
  end

  defp send_webhook_notification(notification) do
    try do
      case Accounts.get_user_webhook_url(notification.recipient_id) do
        nil ->
          {:error, :no_webhook}
          
        webhook_url ->
          # Send HTTP POST to webhook
          headers = [{"content-type", "application/json"}]
          body = Jason.encode!(notification.payload)
          
          case HTTPoison.post(webhook_url, body, headers, timeout: 5000) do
            {:ok, %{status_code: code}} when code in 200..299 ->
              {:ok, :sent}
            {:ok, %{status_code: code}} ->
              {:error, {:http_error, code}}
            {:error, error} ->
              {:error, error}
          end
      end
    rescue
      error -> {:error, error}
    end
  end

  defp send_to_device(_token, _payload) do
    # Placeholder for actual push notification implementation
    {:ok, :sent}
  end

  defp handle_notification_result(state, notification_id, result) do
    # Find and remove notification from processing queue
    {notification, new_processing_queue} = 
      remove_from_queue(state.processing_queue, notification_id)
    
    case {result, notification} do
      {{:ok, _}, notification} when not is_nil(notification) ->
        Logger.debug("Successfully sent notification #{notification_id}")
        
        new_stats = %{state.stats | 
          processing: :queue.len(new_processing_queue),
          sent: state.stats.sent + 1
        }
        
        %{state | processing_queue: new_processing_queue, stats: new_stats}
        
      {{:error, reason}, notification} when not is_nil(notification) ->
        Logger.warn("Failed to send notification #{notification_id}: #{inspect(reason)}")
        
        if notification.retry_count < @retry_attempts do
          # Retry with backoff
          retry_notification = %{notification | retry_count: notification.retry_count + 1}
          
          delay = @retry_backoff * :math.pow(2, notification.retry_count)
          Process.send_after(self(), {:queue_notification, retry_notification}, trunc(delay))
          
          new_stats = %{state.stats | 
            processing: :queue.len(new_processing_queue),
            retries: state.stats.retries + 1
          }
          
          %{state | processing_queue: new_processing_queue, stats: new_stats}
        else
          # Give up and move to failed
          new_failed_notifications = [notification | state.failed_notifications]
          
          new_stats = %{state.stats | 
            processing: :queue.len(new_processing_queue),
            failed: state.stats.failed + 1
          }
          
          %{state | 
            processing_queue: new_processing_queue,
            failed_notifications: new_failed_notifications,
            stats: new_stats
          }
        end
        
      _ ->
        # Notification not found in processing queue (shouldn't happen)
        Logger.warn("Received result for unknown notification #{notification_id}")
        state
    end
  end

  defp remove_from_queue(queue, notification_id) do
    remove_from_queue_helper(queue, notification_id, :queue.new())
  end

  defp remove_from_queue_helper(queue, notification_id, acc) do
    case :queue.out(queue) do
      {:empty, _} ->
        {nil, queue_reverse(acc)}
        
      {{:value, notification}, remaining} ->
        if notification.id == notification_id do
          {notification, queue_concat(queue_reverse(acc), remaining)}
        else
          remove_from_queue_helper(remaining, notification_id, 
            :queue.in(notification, acc))
        end
    end
  end

  defp queue_reverse(queue) do
    :queue.from_list(Enum.reverse(:queue.to_list(queue)))
  end

  defp queue_concat(queue1, queue2) do
    :queue.join(queue1, queue2)
  end

  defp cancel_timer(nil), do: nil
  defp cancel_timer(timer_ref) do
    Process.cancel_timer(timer_ref)
    nil
  end

  defp generate_notification_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end