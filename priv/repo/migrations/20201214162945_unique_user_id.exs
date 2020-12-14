defmodule Funix.Repo.Migrations.UniqueUserId do
  use Ecto.Migration

  def change do
    create unique_index(:matchers, [:user_id])
  end
end
