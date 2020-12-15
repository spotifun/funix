defmodule Funix.MatcherMatch do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matcher_matches" do
    field :user_id, :string
    belongs_to :matcher, Funix.Matcher

    timestamps()
  end

  @doc false
  def changeset(matcher_match, attrs) do
    matcher_match
    |> cast(attrs, [:user_id, :matcher_id])
    |> assoc_constraint(:matcher)
    |> validate_required([:user_id])
    |> unique_constraint(:user_id, [name: :matcher_matches_user_id_index])
  end
end
