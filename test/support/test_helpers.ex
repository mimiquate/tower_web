defmodule TowerWeb.TestHelpers do
  @moduledoc false

  def run_migration(direction) do
    Ecto.Migrator.run(
      TowerWeb.TestRepo,
      [{0, TowerWeb.TestRepo.Migrations.CreateEvents}],
      direction,
      all: true
    )
  end

  def run_db_migration(direction) do
    Ecto.Migrator.run(
      TowerWeb.DB.TestRepo,
      [{0, TowerWeb.DB.TestRepo.Migrations.CreateTowerWebDB}],
      direction,
      all: true
    )
  end

  def run_db_partial_upgrade_migration(direction) do
    Ecto.Migrator.run(
      TowerWeb.DB.PartialUpgradeTestRepo,
      [
        {1, TowerWeb.DB.PartialUpgradeTestRepo.Migrations.AddTowerWebDB},
        {2, TowerWeb.DB.PartialUpgradeTestRepo.Migrations.UpgradeTowerWebDB}
      ],
      direction,
      all: true
    )
  end
end
