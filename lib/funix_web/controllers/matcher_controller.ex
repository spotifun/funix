defmodule FunixWeb.MatcherDestroyer do
  use GenServer

  def start_link(_name \\ nil) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init([destroy_function]) do
    # 2 minutes
    Process.send_after(self(), :terminate_self, 2 * 60 * 1000)
    {:ok, [destroy_function]}
  end

  def handle_info(:terminate_self, [destroy_function]) do
    destroy_function.()
    {:stop, :normal, []}
  end
end

defmodule FunixWeb.MatcherController do
  use FunixWeb, :controller
  alias Funix.{Repo, Matcher, Util, MatcherMatch}
  alias FunixWeb.MatcherDestroyer
  import Ecto.Query

  defp is_user_exist(user_id) do
    match = Repo.get_by(MatcherMatch, user_id: user_id)

    case match do
      nil -> false
      _ -> true
    end
  end

  defp generate_user_exist_error(user_id) do
    %{user_id: user_id, status: :error, errors: [%{user_id: "has already been taken"}]}
  end

  defp get_unique_random_id(random_number, matching_objects) when matching_objects == nil do
    random_number
  end

  defp get_unique_random_id(_random_number, _matching_objects) do
    new_random_number = Enum.random(100_000..999_999)
    get_unique_random_id(new_random_number, Repo.get_by(Matcher, matching_id: new_random_number))
  end

  defp generate_matching_id(user_id) do
    random_number = Enum.random(100_000..999_999)

    matching_id =
      get_unique_random_id(random_number, Repo.get_by(Matcher, matching_id: random_number))

    {status, changeset} =
      Matcher.changeset(%Matcher{}, %{user_id: user_id, matching_id: matching_id})
      |> Repo.insert()

    case status do
      :ok ->
        Ecto.build_assoc(changeset, :matcher_matches, %{user_id: user_id}) |> Repo.insert()

        destroy_function = fn ->
          Repo.delete(changeset, stale_error_field: :stale_error)
        end

        {:ok, _pid} = GenServer.start_link(MatcherDestroyer, [destroy_function])
        %{user_id: user_id, matching_id: matching_id, status: status}

      :error ->
        errors = Util.translate_error(changeset.errors)
        %{user_id: user_id, status: status, errors: errors}
    end
  end

  def generate(conn, %{"user_id" => user_id}) do
    case is_user_exist(user_id) do
      false -> json(conn, generate_matching_id(user_id))
      true -> json(conn, generate_user_exist_error(user_id))
    end
  end

  defp insert_match(matching_id, user_id) do
    matcher = Repo.get_by(Matcher, matching_id: matching_id)

    {status, changeset} =
      Ecto.build_assoc(matcher, :matcher_matches, %{user_id: user_id})
      |> MatcherMatch.changeset(%{})
      |> Repo.insert()

    case status do
      :ok ->
        %{user_id: user_id, status: status, matcher_user_id: matcher.user_id}

      :error ->
        errors = Util.translate_error(changeset.errors)
        %{user_id: user_id, status: status, errors: errors}
    end
  end

  defp get_matcher_status(matching_id) do
    matcher =
      Repo.get_by(Matcher, matching_id: matching_id)
      |> Repo.preload(:matcher_matches)

    matcher_size =
      case matcher do
        nil -> 0
        _ -> length(matcher.matcher_matches)
      end

    cond do
      matcher_size == 0 -> :no_match
      matcher_size < 2 -> :too_few
      matcher_size == 2 -> :ok
      matcher_size > 2 -> :too_much
    end
  end

  defp match_user(user_id, _matching_id, is_user_id_exist) when is_user_id_exist do
    generate_user_exist_error(user_id)
  end

  defp match_user(user_id, matching_id, _is_user_id_exist) do
    matcher_status = get_matcher_status(matching_id)

    case matcher_status do
      :too_few -> insert_match(matching_id, user_id)
      :ok -> %{user_id: user_id, status: :full}
      _ -> %{user_id: user_id, status: matcher_status}
    end
  end

  def match(conn, %{"user_id" => user_id, "matching_id" => matching_id}) do
    case Integer.parse(matching_id) do
      {_num, ""} ->
        json(conn, match_user(user_id, matching_id, is_user_exist(user_id)))

      {_, _} ->
        json(conn, %{
          user_id: user_id,
          status: :error,
          errors: [%{matching_id: "matching_id must be an integer"}]
        })
    end
  end

  def get_status(conn, %{"matching_id" => matching_id}) do
    case Util.is_integer(matching_id) do
      true ->
        status = get_matcher_status(matching_id)
        json(conn, %{matching_id: matching_id, status: status})

      false ->
        json(conn, %{status: :error, errors: [%{matching_id: "matching_id must be an integer"}]})
    end
  end

  def get_matching_id(conn, %{"user_id" => user_id}) do
    query =
      from m in Matcher,
        join: mm in MatcherMatch,
        on: mm.user_id == ^user_id,
        select: {m.matching_id}

    match = Repo.all(query)

    case match do
      [] -> json(conn, %{status: :error, errors: [%{user_id: "user_id not found"}]})
      [{matching_id} | _tail] -> json(conn, %{status: :ok, matching_id: matching_id})
    end
  end
end
