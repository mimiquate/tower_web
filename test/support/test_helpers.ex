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
end
