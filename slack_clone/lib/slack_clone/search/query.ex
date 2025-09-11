defmodule SlackClone.Search.Query do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @search_types ~w(messages files people channels all)

  schema "search_queries" do
    belongs_to :user, SlackClone.Accounts.User
    belongs_to :workspace, SlackClone.Workspaces.Workspace
    field :query, :string
    field :results_count, :integer, default: 0
    field :clicked_result_id, :binary_id
    field :search_type, :string, default: "messages"
    field :filters, :map, default: %{}
    field :executed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  def changeset(query, attrs) do
    query
    |> cast(attrs, [:user_id, :workspace_id, :query, :results_count, :clicked_result_id, :search_type, :filters, :executed_at])
    |> validate_required([:user_id, :workspace_id, :query, :search_type])
    |> validate_inclusion(:search_type, @search_types)
    |> validate_length(:query, min: 1, max: 1000)
  end
end