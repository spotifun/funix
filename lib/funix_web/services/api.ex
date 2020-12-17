defmodule FunixWeb.ServiceApi do
  alias SpotifyApi.Base

  defp request_get(url, headers) do
    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        decoded_body = Poison.decode!(body)
        {:ok, decoded_body}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, [%{status_code: status_code}]}

      {:error, %HTTPoison.Error{id: _id, reason: reason}} ->
        {:error, [%{status_code: 500, status: reason}]}
    end
  end

  def get_user_info(access_token) do
    url = Base.process_request_url("me")
    headers = [Authorization: "Bearer " <> access_token]

    request_get(url, headers)
  end

  def get_top_list(access_token, type) do
    url = Base.process_request_url("me/top/" <> type)
    headers = [Authorization: "Bearer " <> access_token]

    request_get(url, headers)
  end
end
