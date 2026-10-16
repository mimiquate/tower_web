defmodule TowerWeb.DB.TestRepo.Migrations.CreateTowerWebDB do
  use Ecto.Migration

  def up, do: TowerWeb.DB.Migration.up(from: 0, to: 2)
  def down, do: TowerWeb.DB.Migration.down(from: 2, to: 0)
end
