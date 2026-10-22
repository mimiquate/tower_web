defmodule TowerWeb.DB.Migration.V04 do
  @moduledoc false

  use Ecto.Migration

  def up do
    alter table(:tower_web_issues) do
      add(:new_id, :uuid)
    end

    alter table(:tower_web_events) do
      add(:new_issue_id, :uuid)
    end

    flush()
  end

  def down do
    alter table(:tower_web_events) do
      remove(:new_issue_id)
    end

    alter table(:tower_web_issues) do
      remove(:new_id)
    end
  end
end
