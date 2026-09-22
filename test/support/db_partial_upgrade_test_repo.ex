defmodule TowerWeb.DB.PartialUpgradeTestRepo do
  use Ecto.Repo,
    otp_app: :tower_web,
    adapter: Ecto.Adapters.Postgres
end
