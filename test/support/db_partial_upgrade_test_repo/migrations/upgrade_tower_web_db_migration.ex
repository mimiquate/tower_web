defmodule TowerWeb.DB.PartialUpgradeTestRepo.Migrations.UpgradeTowerWebDB do
  use Ecto.Migration

  def up, do: TowerWeb.DB.Migration.up(from: 8, to: 9)
  def down, do: TowerWeb.DB.Migration.down(from: 9, to: 8)
end
