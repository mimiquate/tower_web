defmodule TowerWeb.DB.Migration.V04 do
  @moduledoc false

  use Ecto.Migration

  def up do
    execute("CREATE SEQUENCE tower_web_issues_synthetic_id_seq START WITH 134217728")
  end

  def down do
    execute("DROP SEQUENCE tower_web_issues_synthetic_id_seq")
  end
end
