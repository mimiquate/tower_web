defmodule TowerWeb.DB.Migration.V09 do
  @moduledoc false

  use Ecto.Migration

  def up do
    rename(table(:tower_db_events), to: table(:tower_web_events))
  end

  def down do
    rename(table(:tower_web_events), to: table(:tower_db_events))
  end
end
