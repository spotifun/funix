defmodule Funix.Repo.Migrations.CreateMatchers do
  use Ecto.Migration

  def change do
    create table(:matchers) do
      add :user_id, :string
      add :matching_id, :integer
      timestamps()
    end

    create unique_index(:matchers, [:matching_id])
  end
end
