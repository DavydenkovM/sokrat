defmodule Sokrat.Repo.Migrations.AddStatusToRevisions do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :status, :integer
    end
  end
end
