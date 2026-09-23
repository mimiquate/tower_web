defmodule TowerWeb.DB.MigrationTest do
  use ExUnit.Case, async: true

  alias Ecto.Adapters.SQL
  alias TowerWeb.DB.PartialUpgradeTestRepo, as: Repo
  alias TowerWeb.DB.PartialUpgradeTestRepo.Migrations.AddTowerWebDB
  alias TowerWeb.DB.PartialUpgradeTestRepo.Migrations.UpgradeTowerWebDB

  describe "up/1 and down/1 with :from and :to" do
    setup do
      Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)
      # Needed because when running mix test it will run the migrations
      # Rolling them back manually
      run_migration(:down, {2, UpgradeTowerWebDB})
      run_migration(:down, {1, AddTowerWebDB})
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual) end)
      :ok
    end

    test "applies and reverts only the migrations between :from and :to" do
      refute table_exists?("tower_db_events")
      refute table_exists?("tower_web_events")

      run_migration(:up, {1, AddTowerWebDB})
      assert table_exists?("tower_db_events")
      assert "similarity_id" in get_columns("tower_db_events")

      run_migration(:up, {2, UpgradeTowerWebDB})
      refute table_exists?("tower_db_events")
      assert table_exists?("tower_web_events")
      assert "similarity_id" in get_columns("tower_web_events")

      run_migration(:down, {2, UpgradeTowerWebDB})
      refute table_exists?("tower_web_events")
      assert table_exists?("tower_db_events")
      assert "similarity_id" in get_columns("tower_db_events")

      run_migration(:down, {1, AddTowerWebDB})
      refute table_exists?("tower_db_events")
    end

    test "renaming to tower_web_events preserves existing data" do
      run_migration(:up, {1, AddTowerWebDB})

      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      {1, nil} =
        Repo.insert_all("tower_db_events", [
          %{
            id: Ecto.UUID.dump!(UUIDv7.generate()),
            datetime: now,
            level: "error",
            similarity_id: 1,
            inserted_at: now,
            updated_at: now
          }
        ])

      assert %{rows: [[1]]} = SQL.query!(Repo, "SELECT count(*) FROM tower_db_events", [])

      run_migration(:up, {2, UpgradeTowerWebDB})

      assert %{rows: [[1]]} = SQL.query!(Repo, "SELECT count(*) FROM tower_web_events", [])
    end
  end

  defp run_migration(direction, migration) do
    Ecto.Migrator.run(Repo, [migration], direction, all: true)
  end

  defp table_exists?(table_name) do
    query = """
    SELECT EXISTS (
      SELECT FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = $1
    )
    """

    %{rows: [[exists]]} = SQL.query!(Repo, query, [table_name])
    exists
  end

  defp get_columns(table_name) do
    query = """
    SELECT column_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = $1
    """

    %{rows: rows} = SQL.query!(Repo, query, [table_name])
    List.flatten(rows)
  end
end
