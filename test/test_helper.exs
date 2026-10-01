{:ok, _} = TowerWeb.DB.TestRepo.start_link()

TowerWeb.TestHelpers.run_migration(:up)
TowerWeb.TestHelpers.run_db_migration(:up)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(TowerWeb.DB.TestRepo, :manual)
