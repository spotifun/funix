defmodule FunixWeb.ServicesApi do
  alias SpotifyApi.Base

  def get_top_artists(access_token) do
    url = Base.process_request_url("me/top/artists")
    headers = [Authorization: "Bearer " <> access_token]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        top_artists = Poison.decode!(body)
        {:ok, top_artists}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, [%{status_code: status_code}]}

      {:error, %HTTPoison.Error{id: _id, reason: reason}} ->
        {:error, [%{status_code: 500, status: reason}]}
    end
  end
end
