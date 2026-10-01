defmodule TowerWeb.DB.Migration.V01 do
  @moduledoc false

  use Ecto.Migration

  def up do
    create_if_not_exists table(:tower_web_events, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:similarity_id, :bigint)
      add(:normalized_reason, :text)
      add(:datetime, :utc_datetime_usec, null: false)
      add(:level, :string, null: false)
      add(:kind, :string)
      add(:stacktrace, :binary)
      add(:metadata, :binary)
      add(:request_data, :map)

      timestamps(type: :utc_datetime_usec)
    end

    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")

    create_if_not_exists(index(:tower_web_events, [:datetime]))
    create_if_not_exists(index(:tower_web_events, [:level]))

    create_if_not_exists(
      index(:tower_web_events, ["normalized_reason gin_trgm_ops"], using: :gin)
    )

    create_if_not_exists(index(:tower_web_events, [:similarity_id, "datetime DESC"]))
  end

  def down do
    drop_if_exists(table(:tower_web_events))
  end
end
