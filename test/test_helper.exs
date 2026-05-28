{:ok, _} = TowerWeb.TestRepo.start_link()

TowerWeb.TestHelpers.run_migration(:up)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(TowerWeb.TestRepo, :manual)
