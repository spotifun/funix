defmodule Funix.Matcher do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matchers" do
    field :matching_id, :integer
    field :user_id, :string
    has_many :matcher_matches, Funix.MatcherMatch

    timestamps()
  end

  @doc false
  def changeset(matcher, attrs) do
    matcher
    |> cast(attrs, [:user_id, :matching_id])
    |> validate_required([:user_id, :matching_id])
    |> unique_constraint(:matching_id, name: :matchers_matching_id_index)
    |> unique_constraint(:user_id, name: :matchers_user_id_index)
  end
end
