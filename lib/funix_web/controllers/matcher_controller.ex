defmodule FunixWeb.MatcherController do
    use FunixWeb, :controller
    alias Funix.{Repo, Matcher}

    def get_unique_random_id(random_number, matching_objects) when matching_objects == nil do
        random_number
    end

    def get_unique_random_id(random_number, _) do
        new_random_number = Enum.random(100_000..999_999)
        get_unique_random_id(new_random_number, Repo.get_by(Matcher, matching_id: new_random_number))
    end

    def generate(conn, %{"user_id" => user_id, "search_matching_id" => search_matching_id}) do
        random_number = Enum.random(100_000..999_999)
        matching_id = get_unique_random_id(random_number, Repo.get_by(Matcher, matching_id: random_number))
        
        {is_ok, _} = Matcher.changeset(%Matcher{}, %{user_id: user_id, matching_id: matching_id}) |> Repo.insert()
        json(conn, %{user_id: user_id, matching_id: matching_id, success: is_ok})
    end
end