defmodule Funix.Matcher do
  use Ecto.Schema
  import Ecto.Changeset

  schema "matchers" do
    field :matching_id, :integer
    field :user_id, :string

    timestamps()
  end

  @doc false
  def changeset(matcher, attrs) do
    matcher
    |> cast(attrs, [:user_id, :matching_id])
    |> validate_required([:user_id, :matching_id])
    |> unique_constraint(:matching_id, [name: :matchers_matching_id_index])
    |> unique_constraint(:user_id, [name: :matchers_user_id_index])
  end

  def translate_error(errors) do
    for error <- errors, do: %{elem(error, 0) => elem(elem(error, 1), 0)}
  end
end

require Protocol
Protocol.derive(Jason.Encoder, Funix.Matcher, only: [:matching_id, :user_id])
