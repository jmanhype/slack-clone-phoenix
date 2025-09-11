defmodule SlackClone.Notifications.EmailDigest do
  @moduledoc """
  Schema for email digest notifications.
  Tracks digest generation, delivery, and user engagement.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "email_digests" do
    belongs_to :user, SlackClone.Accounts.User

    # Digest metadata
    field :digest_type, :string # daily, weekly
    field :period_start, :utc_datetime
    field :period_end, :utc_datetime
    field :generated_at, :utc_datetime
    
    # Content summary
    field :total_notifications, :integer, default: 0
    field :unread_messages, :integer, default: 0
    field :mentions_count, :integer, default: 0
    field :direct_messages_count, :integer, default: 0
    field :channel_activity_count, :integer, default: 0
    field :thread_replies_count, :integer, default: 0
    field :file_shares_count, :integer, default: 0
    
    # Channel activity summary
    field :active_channels, {:array, :string}, default: []
    field :top_channels, :map, default: %{}
    field :new_channels, {:array, :string}, default: []
    
    # User activity summary  
    field :active_users, {:array, :string}, default: []
    field :top_contributors, :map, default: %{}
    field :new_team_members, {:array, :string}, default: []
    
    # Email delivery
    field :email_sent, :boolean, default: false
    field :sent_at, :utc_datetime
    field :email_subject, :string
    field :email_template, :string
    field :email_size_kb, :integer
    
    # Engagement tracking
    field :opened, :boolean, default: false
    field :opened_at, :utc_datetime
    field :clicked, :boolean, default: false
    field :clicked_at, :utc_datetime
    field :unsubscribed, :boolean, default: false
    field :unsubscribed_at, :utc_datetime
    
    # Delivery status
    field :delivery_status, :string, default: "pending" # pending, sent, delivered, failed, bounced
    field :delivery_attempts, :integer, default: 0
    field :last_delivery_attempt, :utc_datetime
    field :delivery_error, :string
    field :bounce_reason, :string
    
    # Digest content (JSON for flexibility)
    field :content_summary, :map, default: %{}
    field :notification_items, {:array, :map}, default: []

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(email_digest, attrs) do
    email_digest
    |> cast(attrs, [
      :user_id, :digest_type, :period_start, :period_end, :generated_at,
      :total_notifications, :unread_messages, :mentions_count, :direct_messages_count,
      :channel_activity_count, :thread_replies_count, :file_shares_count,
      :active_channels, :top_channels, :new_channels, :active_users, :top_contributors,
      :new_team_members, :email_sent, :sent_at, :email_subject, :email_template,
      :email_size_kb, :opened, :opened_at, :clicked, :clicked_at, :unsubscribed,
      :unsubscribed_at, :delivery_status, :delivery_attempts, :last_delivery_attempt,
      :delivery_error, :bounce_reason, :content_summary, :notification_items
    ])
    |> validate_required([:user_id, :digest_type, :period_start, :period_end])
    |> validate_inclusion(:digest_type, ["daily", "weekly"])
    |> validate_inclusion(:delivery_status, ["pending", "sent", "delivered", "failed", "bounced"])
    |> validate_period_dates()
  end

  defp validate_period_dates(changeset) do
    period_start = get_field(changeset, :period_start)
    period_end = get_field(changeset, :period_end)

    if period_start && period_end && DateTime.compare(period_start, period_end) != :lt do
      add_error(changeset, :period_end, "must be after period start")
    else
      changeset
    end
  end

  def create_changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_change(:generated_at, DateTime.utc_now())
  end

  def mark_sent(digest, email_subject, template) do
    digest
    |> change(
      email_sent: true,
      sent_at: DateTime.utc_now(),
      email_subject: email_subject,
      email_template: template,
      delivery_status: "sent",
      delivery_attempts: digest.delivery_attempts + 1,
      last_delivery_attempt: DateTime.utc_now()
    )
  end

  def mark_delivered(digest) do
    digest
    |> change(delivery_status: "delivered")
  end

  def mark_opened(digest) do
    digest
    |> change(
      opened: true,
      opened_at: DateTime.utc_now()
    )
  end

  def mark_clicked(digest) do
    digest
    |> change(
      clicked: true,
      clicked_at: DateTime.utc_now()
    )
  end

  def mark_failed(digest, error_reason) do
    digest
    |> change(
      delivery_status: "failed",
      delivery_attempts: digest.delivery_attempts + 1,
      last_delivery_attempt: DateTime.utc_now(),
      delivery_error: error_reason
    )
  end

  def mark_bounced(digest, bounce_reason) do
    digest
    |> change(
      delivery_status: "bounced",
      bounce_reason: bounce_reason
    )
  end

  def mark_unsubscribed(digest) do
    digest
    |> change(
      unsubscribed: true,
      unsubscribed_at: DateTime.utc_now()
    )
  end

  def pending_digests_query do
    from d in __MODULE__,
      where: d.delivery_status == "pending",
      where: d.email_sent == false
  end

  def for_user_query(user_id) do
    from d in __MODULE__,
      where: d.user_id == ^user_id
  end

  def for_period_query(digest_type, period_start, period_end) do
    from d in __MODULE__,
      where: d.digest_type == ^digest_type,
      where: d.period_start >= ^period_start,
      where: d.period_end <= ^period_end
  end

  def recent_digests_query(user_id, days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from d in __MODULE__,
      where: d.user_id == ^user_id,
      where: d.generated_at >= ^cutoff,
      order_by: [desc: d.generated_at]
  end

  def engagement_stats_query(days_back \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    from d in __MODULE__,
      where: d.email_sent == true,
      where: d.sent_at >= ^cutoff,
      select: %{
        total_sent: count(d.id),
        total_opened: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", d.opened)),
        total_clicked: sum(fragment("CASE WHEN ? THEN 1 ELSE 0 END", d.clicked)),
        avg_notifications: avg(d.total_notifications)
      }
  end

  def calculate_engagement_rate(digest) do
    cond do
      digest.clicked -> 1.0
      digest.opened -> 0.5
      digest.email_sent -> 0.0
      true -> nil
    end
  end

  def should_send_digest?(user, digest_type) do
    # Check if user has digest preferences enabled
    case SlackClone.Notifications.get_user_preferences(user.id) do
      {:ok, preferences} ->
        preferences.email_digest_enabled and
        preferences.email_digest_frequency == digest_type
      
      {:error, _} -> false
    end
  end

  def generate_email_subject(digest) do
    case digest.digest_type do
      "daily" ->
        if digest.total_notifications > 0 do
          "Your daily update: #{digest.total_notifications} new notifications"
        else
          "Your daily update from SlackClone"
        end
      
      "weekly" ->
        if digest.total_notifications > 0 do
          "Your weekly summary: #{digest.total_notifications} notifications from #{length(digest.active_channels)} channels"
        else
          "Your weekly summary from SlackClone"
        end
    end
  end

  def has_meaningful_content?(digest) do
    digest.total_notifications > 0 or
    length(digest.active_channels) > 0 or
    length(digest.new_team_members) > 0 or
    length(digest.new_channels) > 0
  end
end