defmodule SlackClone.Notifications.PushSubscription do
  @moduledoc """
  Schema for Web Push notification subscriptions.
  Stores push notification endpoints and keys for browser notifications.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "push_subscriptions" do
    belongs_to :user, SlackClone.Accounts.User

    # Push subscription data
    field :endpoint, :string
    field :p256dh_key, :string
    field :auth_key, :string
    
    # Subscription metadata
    field :user_agent, :string
    field :ip_address, :string
    field :device_type, :string # desktop, mobile, tablet
    field :browser, :string
    field :os, :string
    
    # Status and activity
    field :active, :boolean, default: true
    field :last_used_at, :utc_datetime
    field :failure_count, :integer, default: 0
    field :last_failure_at, :utc_datetime
    field :last_failure_reason, :string
    
    # Subscription settings
    field :vapid_key, :string
    field :subscription_expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(push_subscription, attrs) do
    push_subscription
    |> cast(attrs, [
      :user_id, :endpoint, :p256dh_key, :auth_key, :user_agent, :ip_address,
      :device_type, :browser, :os, :active, :last_used_at, :failure_count,
      :last_failure_at, :last_failure_reason, :vapid_key, :subscription_expires_at
    ])
    |> validate_required([:user_id, :endpoint, :p256dh_key, :auth_key])
    |> validate_inclusion(:device_type, ["desktop", "mobile", "tablet"])
    |> validate_length(:endpoint, max: 500)
    |> validate_length(:p256dh_key, max: 88)
    |> validate_length(:auth_key, max: 24)
    |> unique_constraint([:user_id, :endpoint])
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:last_used_at, DateTime.utc_now())
  end

  def update_last_used(subscription) do
    subscription
    |> change(last_used_at: DateTime.utc_now())
  end

  def record_failure(subscription, reason) do
    subscription
    |> change(
      failure_count: subscription.failure_count + 1,
      last_failure_at: DateTime.utc_now(),
      last_failure_reason: reason
    )
    |> maybe_deactivate()
  end

  def record_success(subscription) do
    subscription
    |> change(
      failure_count: 0,
      last_failure_at: nil,
      last_failure_reason: nil,
      last_used_at: DateTime.utc_now(),
      active: true
    )
  end

  defp maybe_deactivate(changeset) do
    failure_count = get_field(changeset, :failure_count)
    
    if failure_count >= 5 do
      put_change(changeset, :active, false)
    else
      changeset
    end
  end

  def active_subscriptions_query do
    from s in __MODULE__,
      where: s.active == true,
      where: is_nil(s.subscription_expires_at) or s.subscription_expires_at > ^DateTime.utc_now()
  end

  def for_user_query(user_id) do
    from s in __MODULE__,
      where: s.user_id == ^user_id
  end

  def expired_subscriptions_query do
    from s in __MODULE__,
      where: not is_nil(s.subscription_expires_at) and s.subscription_expires_at <= ^DateTime.utc_now()
  end

  def failed_subscriptions_query(failure_threshold \\ 3) do
    from s in __MODULE__,
      where: s.failure_count >= ^failure_threshold
  end

  def to_web_push_subscription(subscription) do
    %{
      endpoint: subscription.endpoint,
      keys: %{
        p256dh: subscription.p256dh_key,
        auth: subscription.auth_key
      }
    }
  end

  def parse_user_agent(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(user_agent, "Chrome") ->
        %{browser: "Chrome", device_type: detect_device_type(user_agent)}
      
      String.contains?(user_agent, "Firefox") ->
        %{browser: "Firefox", device_type: detect_device_type(user_agent)}
      
      String.contains?(user_agent, "Safari") and not String.contains?(user_agent, "Chrome") ->
        %{browser: "Safari", device_type: detect_device_type(user_agent)}
      
      String.contains?(user_agent, "Edge") ->
        %{browser: "Edge", device_type: detect_device_type(user_agent)}
      
      true ->
        %{browser: "Unknown", device_type: detect_device_type(user_agent)}
    end
  end
  
  def parse_user_agent(_), do: %{browser: "Unknown", device_type: "desktop"}

  defp detect_device_type(user_agent) do
    cond do
      String.contains?(user_agent, "Mobile") or String.contains?(user_agent, "Android") ->
        "mobile"
      
      String.contains?(user_agent, "Tablet") or String.contains?(user_agent, "iPad") ->
        "tablet"
      
      true ->
        "desktop"
    end
  end

  def detect_os(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(user_agent, "Windows") -> "Windows"
      String.contains?(user_agent, "Mac OS") -> "macOS"
      String.contains?(user_agent, "Linux") -> "Linux"
      String.contains?(user_agent, "Android") -> "Android"
      String.contains?(user_agent, "iOS") -> "iOS"
      true -> "Unknown"
    end
  end
  
  def detect_os(_), do: "Unknown"
end