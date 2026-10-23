defmodule TowerWeb.DB.Migration.V06 do
  @moduledoc false

  use Ecto.Migration

  def up do
    drop(index(:tower_web_events, [:issue_id, "datetime DESC"]))

    alter table(:tower_web_events) do
      remove(:issue_id)
    end

    alter table(:tower_web_issues) do
      remove(:id)
    end

    rename(table(:tower_web_issues), :new_id, to: :id)
    rename(table(:tower_web_events), :new_issue_id, to: :issue_id)

    execute("ALTER TABLE tower_web_issues ADD PRIMARY KEY (id)")

    alter table(:tower_web_events) do
      modify(:issue_id, references(:tower_web_issues, column: :id, type: :uuid))
    end

    create(index(:tower_web_events, [:issue_id, "datetime DESC"]))
  end

  def down do
    drop(index(:tower_web_events, [:issue_id, "datetime DESC"]))

    execute("ALTER TABLE tower_web_events DROP CONSTRAINT tower_web_events_issue_id_fkey")
    execute("ALTER TABLE tower_web_issues DROP CONSTRAINT tower_web_issues_pkey")

    rename(table(:tower_web_issues), :id, to: :new_id)
    rename(table(:tower_web_events), :issue_id, to: :new_issue_id)

    alter table(:tower_web_issues) do
      add(:id, :bigserial, primary_key: true)
    end

    alter table(:tower_web_events) do
      add(:issue_id, references(:tower_web_issues, column: :id, type: :integer))
    end

    create(index(:tower_web_events, [:issue_id, "datetime DESC"]))
  end
end
