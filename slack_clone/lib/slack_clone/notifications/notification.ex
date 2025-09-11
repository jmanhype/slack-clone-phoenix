defmodule SlackClone.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @notification_types ~w(message mention thread_reply channel_invite dm)
  @priorities ~w(low normal high urgent)
  @delivery_methods ~w(push email sms)

  schema "notifications" do
    belongs_to :user, SlackClone.Accounts.User
    belongs_to :workspace, SlackClone.Workspaces.Workspace
    field :type, :string
    field :title, :string
    field :body, :string
    field :data, :map, default: %{}
    field :read_at, :utc_datetime
    field :clicked_at, :utc_datetime
    field :is_read, :boolean, default: false
    field :priority, :string, default: "normal"
    field :delivery_method, {:array, :string}, default: []
    field :delivered_at, :utc_datetime
    field :failed_delivery_count, :integer, default: 0
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :title, :body, :data, :read_at, :clicked_at, :is_read, 
                   :priority, :delivery_method, :delivered_at, :failed_delivery_count, :expires_at])
    |> validate_required([:type, :title])
    |> validate_inclusion(:type, @notification_types)
    |> validate_inclusion(:priority, @priorities)
    |> validate_length(:title, max: 255)
    |> validate_length(:body, max: 1000)
  end
end