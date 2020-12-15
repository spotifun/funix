defmodule Funix.Repo.Migrations.MatcherMatchesDeleteAll do
  use Ecto.Migration

  def change do
    alter table(:matcher_matches) do
      modify :user_id, :string, from: :integer
      modify :matcher_id, references(:matchers, on_delete: :delete_all), from: references(:matchers, on_delete: :nothing)
    end
  end
end
