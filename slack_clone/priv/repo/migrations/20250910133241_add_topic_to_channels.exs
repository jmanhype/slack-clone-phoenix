defmodule SlackClone.Repo.Migrations.AddTopicToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add :topic, :text
    end
  end
end