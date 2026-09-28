import Config

config :tower_web,
  ecto_repos: [TowerWeb.TestRepo, TowerWeb.DB.TestRepo],
  repo: TowerWeb.DB.TestRepo

config :tower_web, TowerWeb.TestRepo,
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/test_repo",
  url: System.get_env("POSTGRES_URL") || "postgres://localhost:5432/tower_web_test",
  log: false

config :tower_web, TowerWeb.DB.TestRepo,
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/db_test_repo",
  url:
    System.get_env("TOWER_WEB_DB_POSTGRES_URL") ||
      "postgres://localhost:5432/tower_web_db_test",
  log: false

config :tower_db,
  repo: TowerWeb.TestRepo

config :logger, level: :warning
