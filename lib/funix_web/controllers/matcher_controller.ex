defmodule FunixWeb.MatcherDestroyer do
  use GenServer
  alias Funix.Constant

  def start_link(_name \\ nil) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init([destroy_function]) do
    Process.send_after(self(), :terminate_self, Constant.expire_duration())
    {:ok, [destroy_function]}
  end

  def handle_info(:terminate_self, [destroy_function]) do
    destroy_function.()
    {:stop, :normal, []}
  end
end

defmodule FunixWeb.MatcherController do
  use FunixWeb, :controller
  alias Funix.{Repo, Matcher, Util, MatcherMatch, Constant}
  alias FunixWeb.{MatcherDestroyer, ServiceApi}
  import Ecto.Query
  import DateTime

  defp seed_user_data(access_token, type) do
    case ServiceApi.get_top_list(access_token, type) do
      {:ok, spotify_data} ->
        top_list_ids = spotify_data["items"] |> Enum.map(fn data -> data["id"] end)
        {:ok, top_list_ids}

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp get_spotify_user_id(access_token) do
    case ServiceApi.get_user_info(access_token) do
      {:ok, user_info} ->
        user_id = user_info["id"]
        {:ok, user_id}

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp user_exist_error() do
    %{user_id: "has already been taken"}
  end

  defp is_user_in_table(user_id, table) do
    case Repo.get_by(table, user_id: user_id) do
      nil ->
        {:ok, false}

      struct ->
        cond do
          diff(now!("Etc/UTC"), from_naive!(struct.inserted_at, "Etc/UTC"), :millisecond) >
              Constant.expire_duration() ->
            case Repo.delete(struct, stale_error_field: :stale_error) do
              {:ok, _struct} ->
                {:ok, false}

              {:error, changeset} ->
                {:error, Util.translate_error(changeset.errors)}
            end

          true ->
            {:ok, true}
        end
    end
  end

  defp get_user_data(access_token) do
    case seed_user_data(access_token, "artists") do
      {:ok, artist_ids} ->
        case seed_user_data(access_token, "tracks") do
          {:ok, track_ids} -> {:ok, {artist_ids, track_ids}}
          {:error, errors} -> {:error, errors}
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp user_validation(user_id, access_token) do
    is_user_in_matcher = is_user_in_table(user_id, Matcher)
    is_user_in_match = is_user_in_table(user_id, MatcherMatch)

    case is_user_in_matcher do
      {:ok, false} ->
        case is_user_in_match do
          {:ok, false} ->
            case get_spotify_user_id(access_token) do
              {:ok, spotify_user_id} ->
                cond do
                  spotify_user_id == user_id -> {:ok, true}
                  true -> {:error, [%{user_id: "is not valid"}]}
                end

              {:error, errors} ->
                {:error, errors}
            end

          {:ok, true} ->
            {:error, [user_exist_error()]}

          {:error, errors} ->
            {:error, errors}
        end

      {:ok, true} ->
        {:error, [user_exist_error()]}

      {:error, errors} ->
        {:error, errors}
    end
  end

  defp get_unique_random_id(random_number, matching_objects) when matching_objects == nil do
    random_number
  end

  defp get_unique_random_id(_random_number, _matching_objects) do
    new_random_number = Enum.random(100_000..999_999)
    get_unique_random_id(new_random_number, Repo.get_by(Matcher, matching_id: new_random_number))
  end

  defp create_matcher(user_id, artist_ids, track_ids) do
    random_number = Enum.random(100_000..999_999)

    matching_id =
      get_unique_random_id(random_number, Repo.get_by(Matcher, matching_id: random_number))

    {status, changeset} =
      Matcher.changeset(%Matcher{}, %{user_id: user_id, matching_id: matching_id})
      |> Repo.insert()

    case status do
      :ok ->
        Ecto.build_assoc(changeset, :matcher_matches, %{
          user_id: user_id,
          artist_ids: artist_ids,
          track_ids: track_ids
        })
        |> Repo.insert()

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

  def generate(conn, %{"user_id" => user_id, "access_token" => access_token}) do
    case user_validation(user_id, access_token) do
      {:ok, _} ->
        case get_user_data(access_token) do
          {:ok, {artist_ids, track_ids}} ->
            json(conn, create_matcher(user_id, artist_ids, track_ids))

          {:error, errors} ->
            json(conn, %{user_id: user_id, status: :error, errors: errors})
        end

      {:error, errors} ->
        json(conn, %{user_id: user_id, status: :error, errors: errors})
    end
  end

  defp insert_match(matching_id, user_id, artist_ids, track_ids) do
    matcher = Repo.get_by(Matcher, matching_id: matching_id)

    case Ecto.build_assoc(matcher, :matcher_matches, %{
           user_id: user_id,
           artist_ids: artist_ids,
           track_ids: track_ids
         })
         |> MatcherMatch.changeset(%{})
         |> Repo.insert() do
      {:ok, _struct} ->
        %{user_id: user_id, status: :ok}

      {:error, changeset} ->
        errors = Util.translate_error(changeset.errors)
        %{user_id: user_id, status: :error, errors: errors}
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

  defp match_user(user_id, matching_id, artist_ids, track_ids) do
    matcher_status = get_matcher_status(matching_id)

    case matcher_status do
      :too_few -> insert_match(matching_id, user_id, artist_ids, track_ids)
      :ok -> %{user_id: user_id, status: :full}
      _ -> %{user_id: user_id, status: matcher_status}
    end
  end

  def match(conn, %{
        "user_id" => user_id,
        "access_token" => access_token,
        "matching_id" => matching_id
      }) do
    case Integer.parse(matching_id) do
      {_num, ""} ->
        case user_validation(user_id, access_token) do
          {:ok, _} ->
            case get_user_data(access_token) do
              {:ok, {artist_ids, track_ids}} ->
                json(conn, match_user(user_id, matching_id, artist_ids, track_ids))

              {:error, errors} ->
                json(conn, %{user_id: user_id, status: :error, errors: errors})
            end

          {:error, errors} ->
            json(conn, %{user_id: user_id, status: :error, errors: errors})
        end

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

  def get_recommendation(conn, %{"user_id" => user_id}) do
    query =
      from u in MatcherMatch,
        join: v in MatcherMatch,
        on: u.user_id == ^user_id,
        on: v.matcher_id == u.matcher_id,
        select: {v.artist_ids, v.track_ids}

    struct = Repo.all(query)

    accumulator_function = fn
      {[f_ar | _t_ar], [f_tr | _t_tr]}, {acc_a, acc_t} -> {[f_ar | acc_a], [f_tr | acc_t]}
      {_, _}, {acc_a, acc_t} -> {acc_a, acc_t}
    end

    {mixed_recommended_artist, mixed_recommended_tracks} =
      List.foldr(struct, {[], []}, accumulator_function)

    json(conn, %{
      status: :ok,
      seeds: %{
        seed_artists: mixed_recommended_artist,
        seed_tracks: mixed_recommended_tracks
      }
    })
  end
end
