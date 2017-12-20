defmodule Sokrat.Repo.Migrations.AddSlackUserNameToRevisions do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :slack_username_id, :string
    end
  end
end
