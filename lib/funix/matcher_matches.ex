defmodule Funix.MatcherMatches do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matcher_matches" do
    field :user_id, :integer
    field :matcher_id, :id

    timestamps()
  end

  @doc false
  def changeset(matcher_matches, attrs) do
    matcher_matches
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id, [name: :matcher_matches_user_id_index])
  end
end
