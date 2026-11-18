defmodule TowerWeb.DB.Migration.V06 do
  @moduledoc false

  use Ecto.Migration

  def up do
    alter table(:tower_web_events) do
      add(:reopened, :boolean, null: false, default: false)
    end
  end

  def down do
    alter table(:tower_web_events) do
      remove(:reopened)
    end
  end
end
