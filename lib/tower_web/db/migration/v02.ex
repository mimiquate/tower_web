defmodule TowerWeb.DB.Migration.V02 do
  @moduledoc false

  use Ecto.Migration

  def up do
    create_if_not_exists table(:tower_web_issues, primary_key: false) do
      add(:id, :integer, primary_key: true)
      add(:count_events, :integer, null: false)
      add(:first_seen, :utc_datetime_usec, null: false)
      add(:last_seen, :utc_datetime_usec, null: false)
      add(:level, :string, null: false)
      add(:normalized_reason, :text, null: false)
      add(:stacktrace, :binary)

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists(index(:tower_web_issues, [:level]))

    create_if_not_exists(
      index(:tower_web_issues, ["normalized_reason gin_trgm_ops"], using: :gin)
    )
  end

  def down do
    drop_if_exists(table(:tower_web_issues))
  end
end
