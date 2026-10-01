defmodule TowerWeb.DB.Migration.V03 do
  @moduledoc false

  use Ecto.Migration

  def up do
    alter table(:tower_web_issues) do
      add(:state, :string, null: false, default: "unresolved")
    end
  end

  def down do
    alter table(:tower_web_issues) do
      remove(:state)
    end
  end
end
