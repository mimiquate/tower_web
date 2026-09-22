{:ok, _} = TowerWeb.TestRepo.start_link()
{:ok, _} = TowerWeb.DB.TestRepo.start_link()
{:ok, _} = TowerWeb.DB.PartialUpgradeTestRepo.start_link()

TowerWeb.TestHelpers.run_migration(:up)
TowerWeb.TestHelpers.run_db_migration(:up)
TowerWeb.TestHelpers.run_db_partial_upgrade_migration(:up)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(TowerWeb.TestRepo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(TowerWeb.DB.TestRepo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(TowerWeb.DB.PartialUpgradeTestRepo, :manual)
