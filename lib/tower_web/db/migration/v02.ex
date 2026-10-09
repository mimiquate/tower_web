defmodule TowerWeb.DB.Migration.V02 do
  @moduledoc false

  use Ecto.Migration

  def up do
    create_if_not_exists table(:tower_web_issues) do
    end

    alter table(:tower_web_events) do
      add(:issue_id, :integer)
    end

    execute("""
    CREATE TEMPORARY TABLE tower_web_similarity_issue_map AS
    SELECT similarity_id, nextval(pg_get_serial_sequence('tower_web_issues', 'id')) AS issue_id
    FROM (SELECT DISTINCT similarity_id FROM tower_web_events WHERE similarity_id IS NOT NULL) AS distinct_similarity_ids
    """)

    execute("""
    INSERT INTO tower_web_issues (id)
    SELECT issue_id FROM tower_web_similarity_issue_map
    """)

    execute("""
    UPDATE tower_web_events e
    SET issue_id = m.issue_id
    FROM tower_web_similarity_issue_map m
    WHERE e.similarity_id = m.similarity_id
    """)

    execute("DROP TABLE tower_web_similarity_issue_map")

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
