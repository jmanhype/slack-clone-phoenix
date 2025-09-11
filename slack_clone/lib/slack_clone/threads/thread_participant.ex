defmodule SlackClone.Threads.ThreadParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_participants" do
    belongs_to :user, SlackClone.Accounts.User
    belongs_to :thread, SlackClone.Messages.Message, foreign_key: :thread_id
    field :joined_at, :utc_datetime
    field :last_activity_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:user_id, :thread_id, :joined_at, :last_activity_at])
    |> validate_required([:user_id, :thread_id])
    |> unique_constraint([:user_id, :thread_id])
  end
end