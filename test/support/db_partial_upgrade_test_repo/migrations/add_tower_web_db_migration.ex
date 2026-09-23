defmodule TowerWeb.DB.PartialUpgradeTestRepo.Migrations.AddTowerWebDB do
  use Ecto.Migration

  def up, do: TowerWeb.DB.Migration.up(from: 0, to: 8)
  def down, do: TowerWeb.DB.Migration.down(from: 8, to: 0)
end
