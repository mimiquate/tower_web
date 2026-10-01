defmodule TowerWeb.TestHelpers do
  @moduledoc false

  def run_migration(direction) do
    Ecto.Migrator.run(
      TowerWeb.DB.TestRepo,
      [{0, TowerWeb.DB.TestRepo.Migrations.CreateEvents}],
      direction,
      all: true
    )
  end

  def run_db_migration(direction) do
    Ecto.Migrator.run(
      TowerWeb.DB.TestRepo,
      [{1, TowerWeb.DB.TestRepo.Migrations.CreateTowerWebDB}],
      direction,
      all: true
    )
  end
end
