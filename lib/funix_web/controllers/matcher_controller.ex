defmodule FunixWeb.MatcherDestroyer do
    use GenServer

    def start_link(_name \\ nil) do
        GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    end

    def init([destroy_function]) do
        Process.send_after(self(), :terminate_self, 2 * 60 * 1000) # 2 minutes
        {:ok, [destroy_function]}
    end

    def handle_info(:terminate_self, [destroy_function]) do
        destroy_function.()
        {:stop, :normal, []}
    end
end

defmodule FunixWeb.MatcherController do
    use FunixWeb, :controller
    alias Funix.{Repo, Matcher, Util}
    alias FunixWeb.MatcherDestroyer

    defp get_unique_random_id(random_number, matching_objects) when matching_objects == nil do
        random_number
    end

    defp get_unique_random_id(_random_number, _matching_objects) do
        new_random_number = Enum.random(100_000..999_999)
        get_unique_random_id(new_random_number, Repo.get_by(Matcher, matching_id: new_random_number))
    end

    def generate(conn, %{"user_id" => user_id}) do
        random_number = Enum.random(100_000..999_999)
        matching_id = get_unique_random_id(random_number, Repo.get_by(Matcher, matching_id: random_number))
        
        {status, changeset} = Matcher.changeset(%Matcher{}, %{user_id: user_id, matching_id: matching_id}) |> Repo.insert()
        
        case status do
            :ok ->
                destroy_function = fn () ->
                    Repo.delete(changeset, [stale_error_field: :stale_error])
                end

                {:ok, _pid} = GenServer.start_link(MatcherDestroyer, [destroy_function])
                json(conn, %{user_id: user_id, matching_id: matching_id, success: status})
            :error ->
                errors = Util.translate_error(changeset.errors)
                json(conn, %{user_id: user_id, matching_id: matching_id, status: status, errors: errors})
        end
    end

    def match(conn, %{"user_id" => user_id, "matching_id" => matching_id}) do
        case Integer.parse(matching_id) do
            {_num, ""} ->
                matching = Repo.get_by(Matcher, matching_id: matching_id)            
                case matching do
                    nil -> 
                        json(conn, %{user_id: user_id, status: :no_match})
                    _ ->
                        json(conn, %{user_id: user_id, status: :matched, match_user_id: matching.user_id})
                end
            
            {_, _} -> json(conn, %{user_id: user_id, status: :error, errors: [%{matching_id: "matching_id must be an integer"}]})
        end
    end
end