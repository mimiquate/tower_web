defmodule TowerWeb.DB.Migration.V05 do
  @moduledoc false

  use Ecto.Migration

  def up do
    alter table(:tower_web_issues) do
      add(:muted_until, :utc_datetime_usec)
    end
  end

  def down do
    alter table(:tower_web_issues) do
      remove(:muted_until)
    end
  end
end
