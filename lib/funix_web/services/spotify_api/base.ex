defmodule SpotifyApi.Base do
  use HTTPoison.Base

  def process_request_url(url) do
    "https://api.spotify.com/v1/" <> url
  end
end
