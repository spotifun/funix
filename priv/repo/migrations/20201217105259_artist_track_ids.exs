defmodule Funix.Repo.Migrations.ArtistTrackIds do
  use Ecto.Migration

  def change do
    alter table(:matcher_matches) do
      add :track_ids, {:array, :string}
      add :artist_ids, {:array, :string}
    end
  end
end
