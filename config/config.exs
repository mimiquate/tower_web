import Config

config :tower_web,
  ecto_repos: [TowerWeb.DB.TestRepo],
  repo: TowerWeb.DB.TestRepo,
  pruner: false

config :tower_web, TowerWeb.DB.TestRepo,
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/db_test_repo",
  url: System.get_env("POSTGRES_URL") || "postgres://localhost:5432/tower_web_test",
  log: false

config :logger, level: :warning
