defmodule TowerWeb.DB.Migration.V02 do
  @moduledoc false

  use Ecto.Migration

  def up do
    create_if_not_exists table(:tower_web_issues, primary_key: false) do
      add(:id, :integer, primary_key: true)
    end

    execute("""
    INSERT INTO tower_web_issues (id)
    SELECT DISTINCT similarity_id FROM tower_web_events
    WHERE similarity_id IS NOT NULL
    ON CONFLICT (id) DO NOTHING
    """)

    alter table(:tower_web_events) do
      add(:issue_id, :integer)
    end

    execute("UPDATE tower_web_events SET issue_id = similarity_id WHERE issue_id IS NULL")

    alter table(:tower_web_events) do
      modify(:issue_id, references(:tower_web_issues, column: :id, type: :integer), null: false)
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
