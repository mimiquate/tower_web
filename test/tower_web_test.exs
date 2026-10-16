defmodule TowerWebTest do
  use ExUnit.Case

  @id "01a13157-7d12-7849-addc-60108c5ba540"
  @base_url "http://localhost:4000/tower_errors"

  describe "occurrence_url/1" do
    test "returns the absolute URL of the occurrence" do
      put_env(:tower_web, :base_url, @base_url)
      assert TowerWeb.occurrence_url(@id) == "#{@base_url}/occurrences/#{@id}"
    end

    test "returns nil when base_url is not configured" do
      assert TowerWeb.occurrence_url(@id) == nil
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
