defmodule Funix.Repo.Migrations.CreateMatcherMatches do
  use Ecto.Migration

  def change do
    create table(:matcher_matches) do
      add :user_id, :integer
      add :matcher_id, references(:matchers, on_delete: :nothing)

      timestamps()
    end

    create index(:matcher_matches, [:matcher_id])
    create unique_index(:matcher_matches, [:user_id])
  end
end
