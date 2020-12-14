defmodule FunixWeb.MatcherController do
    use FunixWeb, :controller
    alias Funix.{Repo, Matcher}

    def generate(conn, %{"user_id" => user_id}) do
        get_unique_random_id = fn () -> Enum.random(100_000..999_999) end
        matching_id = get_unique_random_id.()
        
        {is_ok, _} = Matcher.changeset(%Matcher{}, %{user_id: user_id, matching_id: matching_id}) |> Repo.insert()
        json(conn, %{user_id: user_id, matching_id: matching_id, success: is_ok})
    end
end