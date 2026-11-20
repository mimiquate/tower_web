defmodule TowerWeb.DB.Migration.V06 do
  @moduledoc false

  use Ecto.Migration

  def up do
    alter table(:tower_web_events) do
      add(:issue_reopened, :boolean, null: false, default: false)
    end
  end

  def down do
    alter table(:tower_web_events) do
      remove(:issue_reopened)
    end
  end
end
