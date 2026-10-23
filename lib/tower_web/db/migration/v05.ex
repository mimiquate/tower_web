defmodule TowerWeb.DB.Migration.V05 do
  @moduledoc false

  use Ecto.Migration

  def up do
    TowerWeb.DB.BackfillIssueUuids.run()
  end

  def down do
    :ok
  end
end
