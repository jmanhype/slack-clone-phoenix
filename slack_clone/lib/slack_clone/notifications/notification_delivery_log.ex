defmodule SlackClone.Notifications.NotificationDeliveryLog do
  @moduledoc """
  Schema for tracking notification delivery attempts and outcomes.
  Provides detailed logging for notification delivery debugging and analytics.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notification_delivery_logs" do
    belongs_to :notification, SlackClone.Notifications.Notification
    belongs_to :user, SlackClone.Accounts.User

    # Delivery attempt details
    field :delivery_method, :string # email, push, in_app, sms
    field :attempt_number, :integer, default: 1
    field :attempted_at, :utc_datetime
    
    # Delivery outcome
    field :status, :string # pending, sent, delivered, failed, bounced, rejected
    field :delivered_at, :utc_datetime
    field :response_code, :string
    field :response_message, :string
    field :external_id, :string # ID from external service (email service, push service, etc.)
    
    # Service provider details
    field :provider, :string # sendgrid, firebase, vapid, twilio, etc.
    field :provider_endpoint, :string
    field :provider_response, :map
    
    # Delivery metadata
    field :recipient_address, :string # email address, push endpoint, phone number
    field :message_size_bytes, :integer
    field :delivery_latency_ms, :integer
    field :retry_after, :utc_datetime
    
    # Error details
    field :error_code, :string
    field :error_message, :string
    field :error_category, :string # network, authentication, quota, invalid_recipient, etc.
    field :is_permanent_failure, :boolean, default: false
    
    # User engagement (for trackable methods)
    field :opened, :boolean, default: false
    field :opened_at, :utc_datetime
    field :clicked, :boolean, default: false
    field :clicked_at, :utc_datetime
    field :unsubscribed, :boolean, default: false
    field :unsubscribed_at, :utc_datetime
    
    # Delivery context
    field :user_agent, :string
    field :ip_address, :string
    field :device_info, :map
    field :location_info, :map

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification_delivery_log, attrs) do
    notification_delivery_log
    |> cast(attrs, [
      :notification_id, :user_id, :delivery_method, :attempt_number, :attempted_at,
      :status, :delivered_at, :response_code, :response_message, :external_id,
      :provider, :provider_endpoint, :provider_response, :recipient_address,
      :message_size_bytes, :delivery_latency_ms, :retry_after, :error_code,
      :error_message, :error_category, :is_permanent_failure, :opened,
      :opened_at, :clicked, :clicked_at, :unsubscribed, :unsubscribed_at,
      :user_agent, :ip_address, :device_info, :location_info
    ])
    |> validate_required([:notification_id, :user_id, :delivery_method, :attempted_at])
    |> validate_inclusion(:delivery_method, ["email", "push", "in_app", "sms"])
    |> validate_inclusion(:status, ["pending", "sent", "delivered", "failed", "bounced", "rejected"])
    |> validate_inclusion(:error_category, [
      "network", "authentication", "quota", "invalid_recipient", 
      "content_policy", "rate_limit", "service_unavailable", "unknown"
    ])
    |> validate_number(:attempt_number, greater_than: 0)
    |> validate_number(:delivery_latency_ms, greater_than_or_equal_to: 0)
    |> validate_number(:message_size_bytes, greater_than_or_equal_to: 0)
  end

  def create_attempt_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:attempted_at, DateTime.utc_now())
    |> put_change(:status, "pending")
  end

  def mark_sent(log, response_info \\ %{}) do
    log
    |> change(
      status: "sent",
      delivered_at: DateTime.utc_now(),
      response_code: Map.get(response_info, :response_code),
      response_message: Map.get(response_info, :response_message),
      external_id: Map.get(response_info, :external_id),
      provider_response: Map.get(response_info, :provider_response),
      delivery_latency_ms: calculate_latency(log.attempted_at)
    )
  end

  def mark_delivered(log) do
    log
    |> change(
      status: "delivered",
      delivered_at: DateTime.utc_now()
    )
  end

  def mark_failed(log, error_info) do
    log
    |> change(
      status: "failed",
      error_code: Map.get(error_info, :error_code),
      error_message: Map.get(error_info, :error_message),
      error_category: Map.get(error_info, :error_category, "unknown"),
      is_permanent_failure: Map.get(error_info, :is_permanent_failure, false),
      response_code: Map.get(error_info, :response_code),
      provider_response: Map.get(error_info, :provider_response),
      delivery_latency_ms: calculate_latency(log.attempted_at)
    )
  end

  def mark_bounced(log, bounce_info) do
    log
    |> change(
      status: "bounced",
      error_code: Map.get(bounce_info, :bounce_code),
      error_message: Map.get(bounce_info, :bounce_reason),
      error_category: "invalid_recipient",
      is_permanent_failure: true,
      provider_response: Map.get(bounce_info, :provider_response)
    )
  end

  def mark_opened(log, engagement_info \\ %{}) do
    log
    |> change(
      opened: true,
      opened_at: DateTime.utc_now(),
      user_agent: Map.get(engagement_info, :user_agent),
      ip_address: Map.get(engagement_info, :ip_address),
      device_info: Map.get(engagement_info, :device_info),
      location_info: Map.get(engagement_info, :location_info)
    )
  end

  def mark_clicked(log, engagement_info \\ %{}) do
    log
    |> change(
      clicked: true,
      clicked_at: DateTime.utc_now(),
      user_agent: Map.get(engagement_info, :user_agent),
      ip_address: Map.get(engagement_info, :ip_address),
      device_info: Map.get(engagement_info, :device_info)
    )
  end

  def mark_unsubscribed(log) do
    log
    |> change(
      unsubscribed: true,
      unsubscribed_at: DateTime.utc_now()
    )
  end

  defp calculate_latency(attempted_at) when is_struct(attempted_at, DateTime) do
    DateTime.diff(DateTime.utc_now(), attempted_at, :millisecond)
  end
  
  defp calculate_latency(_), do: nil

  # Query functions
  def for_notification_query(notification_id) do
    from l in __MODULE__,
      where: l.notification_id == ^notification_id,
      order_by: [asc: l.attempt_number]
  end

  def for_user_query(user_id) do
    from l in __MODULE__,
      where: l.user_id == ^user_id
  end

  def by_delivery_method_query(delivery_method) do
    from l in __MODULE__,
      where: l.delivery_method == ^delivery_method
  end

  def failed_deliveries_query(hours_back \\ 24) do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours_back, :hour)
    
    from l in __MODULE__,
      where: l.status == "failed",
      where: l.attempted_at >= ^cutoff,
      where: l.is_permanent_failure == false
  end

  def permanent_failures_query(days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from l in __MODULE__,
      where: l.is_permanent_failure == true,
      where: l.attempted_at >= ^cutoff
  end

  def delivery_stats_query(delivery_method, days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from l in __MODULE__,
      where: l.delivery_method == ^delivery_method,
      where: l.attempted_at >= ^cutoff,
      select: %{
        total_attempts: count(l.id),
        successful_deliveries: sum(fragment("CASE WHEN ? IN ('sent', 'delivered') THEN 1 ELSE 0 END", l.status)),
        failed_deliveries: sum(fragment("CASE WHEN ? = 'failed' THEN 1 ELSE 0 END", l.status)),
        bounced_deliveries: sum(fragment("CASE WHEN ? = 'bounced' THEN 1 ELSE 0 END", l.status)),
        avg_latency_ms: avg(l.delivery_latency_ms),
        engagement_rate: fragment("CAST(SUM(CASE WHEN ? THEN 1 ELSE 0 END) AS FLOAT) / NULLIF(COUNT(?), 0)", l.opened, l.id)
      }
  end

  def engagement_stats_query(user_id, days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from l in __MODULE__,
      where: l.user_id == ^user_id,
      where: l.attempted_at >= ^cutoff,
      where: l.status in ["sent", "delivered"],
      select: %{
        total_delivered: count(l.id),
        total_opened: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", l.opened)),
        total_clicked: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", l.clicked)),
        unsubscribed: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", l.unsubscribed)),
        avg_open_time: avg(fragment("EXTRACT(EPOCH FROM (? - ?))", l.opened_at, l.delivered_at))
      }
  end

  def provider_performance_query(provider, days_back \\ 7) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from l in __MODULE__,
      where: l.provider == ^provider,
      where: l.attempted_at >= ^cutoff,
      select: %{
        total_attempts: count(l.id),
        success_rate: fragment("CAST(SUM(CASE WHEN ? IN ('sent', 'delivered') THEN 1 ELSE 0 END) AS FLOAT) / NULLIF(COUNT(?), 0)", l.status, l.id),
        avg_latency_ms: avg(l.delivery_latency_ms),
        error_categories: fragment("array_agg(DISTINCT ? ORDER BY ?)", l.error_category, l.error_category)
      }
  end

  def retry_eligible_query(max_attempts \\ 3) do
    cutoff = DateTime.utc_now()
    
    from l in __MODULE__,
      where: l.status == "failed",
      where: l.is_permanent_failure == false,
      where: l.attempt_number < ^max_attempts,
      where: is_nil(l.retry_after) or l.retry_after <= ^cutoff,
      order_by: [asc: l.attempted_at]
  end

  def calculate_engagement_rate(logs) when is_list(logs) do
    delivered_count = Enum.count(logs, &(&1.status in ["sent", "delivered"]))
    
    if delivered_count > 0 do
      opened_count = Enum.count(logs, & &1.opened)
      opened_count / delivered_count
    else
      0.0
    end
  end

  def calculate_success_rate(logs) when is_list(logs) do
    total_count = length(logs)
    
    if total_count > 0 do
      success_count = Enum.count(logs, &(&1.status in ["sent", "delivered"]))
      success_count / total_count
    else
      0.0
    end
  end
end