defmodule SlackClone.Threads.ThreadSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @notification_levels ~w(all mentions none)

  schema "thread_subscriptions" do
    belongs_to :user, SlackClone.Accounts.User
    belongs_to :thread, SlackClone.Messages.Message, foreign_key: :thread_id
    field :last_read_at, :utc_datetime
    field :notification_level, :string, default: "all"

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:user_id, :thread_id, :last_read_at, :notification_level])
    |> validate_required([:user_id, :thread_id])
    |> validate_inclusion(:notification_level, @notification_levels)
    |> unique_constraint([:user_id, :thread_id])
  end
end