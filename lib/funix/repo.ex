defmodule Funix.Repo do
  use Ecto.Repo,
    otp_app: :funix,
    adapter: Ecto.Adapters.Postgres
end
