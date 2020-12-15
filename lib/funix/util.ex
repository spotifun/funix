defmodule Funix.Util do

  def translate_error(errors) do
    for error <- errors, do: %{elem(error, 0) => elem(elem(error, 1), 0)}
  end

end

require Protocol
Protocol.derive(Jason.Encoder, Funix.Matcher, only: [:matching_id, :user_id])
Protocol.derive(Jason.Encoder, Funix.MatcherMatches, only: [:user_id])