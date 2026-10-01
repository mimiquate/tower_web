defmodule TowerWeb.DBTest do
  use ExUnit.Case
  doctest TowerWeb.DB

  import ExUnit.CaptureLog, only: [capture_log: 1]

  setup do
    put_env(:tower, :reporters, [TowerWeb.DB])

    :ok
  end

  test "logs database error message when inserting" do
    assert capture_log(fn ->
             assert :ok = Tower.report_message(:invalid_level, "message")
           end) =~ ~r/\[TowerWeb\.DB\] Error creating event in DB: #Ecto.Changeset/
  end

  describe "enable/0 and disable/0" do
    setup do
      on_exit(fn -> Application.delete_env(:tower_web, :enabled) end)

      :ok
    end

    test "disable/0 and enable/0 toggle the :enabled config" do
      TowerWeb.DB.disable()
      assert Application.get_env(:tower_web, :enabled) == false

      TowerWeb.DB.enable()
      assert Application.get_env(:tower_web, :enabled) == true
    end
  end

  defp put_env(app, key, value) do
    original_value = Application.get_env(app, key)
    Application.put_env(app, key, value)

    on_exit(fn ->
      if original_value == nil do
        Application.delete_env(app, key)
      else
        Application.put_env(app, key, original_value)
      end
    end)
  end
end
