defmodule Funix.Util do
  def translate_error(errors) do
    for error <- errors, do: %{elem(error, 0) => elem(elem(error, 1), 0)}
  end

  def is_integer(n) do
    case Integer.parse(n) do
      {_num, ""} -> true
      _ -> false
    end
  end
end

require Protocol
Protocol.derive(Jason.Encoder, Funix.Matcher, only: [:matching_id, :user_id])
Protocol.derive(Jason.Encoder, Funix.MatcherMatch, only: [:user_id])
