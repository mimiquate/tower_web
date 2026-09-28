defmodule TowerWeb.TestHelpers do
  @moduledoc false

  def run_db_migration(direction) do
    Ecto.Migrator.run(
      TowerWeb.DB.TestRepo,
      [{0, TowerWeb.DB.TestRepo.Migrations.CreateTowerWebDB}],
      direction,
      all: true
    )
  end
end
