defmodule TowerWeb.DB.Migration.V02 do
  @moduledoc false

  use Ecto.Migration

  def up do
    create_if_not_exists table(:tower_web_issues) do
    end

    alter table(:tower_web_events) do
      add(:issue_id, references(:tower_web_issues, column: :id, type: :integer))
    end

    create_if_not_exists(index(:tower_web_events, [:issue_id, "datetime DESC"]))
  end

  def down do
    drop_if_exists(index(:tower_web_events, [:issue_id, "datetime DESC"]))

    alter table(:tower_web_events) do
      remove(:issue_id)
    end

    drop_if_exists(table(:tower_web_issues))
  end
end
