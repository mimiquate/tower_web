defmodule TowerWebTest do
  use ExUnit.Case

  import ExUnit.CaptureLog, only: [capture_log: 1]

  @id "01a13157-7d12-7849-addc-60108c5ba540"

  defmodule FakeEndpoint do
    # Stands in for the host application's Phoenix endpoint
    def url, do: "http://localhost:4000"
    def path(path), do: path
  end

  defmodule PrefixedFakeEndpoint do
    # An endpoint configured with `url: [path: "/app"]`
    def url, do: "http://localhost:4000"
    def path(path), do: "/app" <> path
  end

  defmodule Router do
    use Phoenix.Router
    import TowerWeb.Router

    scope "/admin" do
      tower_dashboard("/tower_errors")
    end
  end

  defmodule RouterWithoutDashboard do
    use Phoenix.Router
  end

  describe "occurrence_url/1" do
    test "returns the absolute URL of the occurrence, including enclosing scopes" do
      put_env(:tower_web, :endpoint, FakeEndpoint)
      put_env(:tower_web, :router, Router)

      assert TowerWeb.occurrence_url(@id) ==
               "#{FakeEndpoint.url()}/admin/tower_errors/occurrences/#{@id}"
    end

    test "keeps the endpoint path prefix of apps served under a sub-path" do
      put_env(:tower_web, :endpoint, PrefixedFakeEndpoint)
      put_env(:tower_web, :router, Router)

      assert TowerWeb.occurrence_url(@id) ==
               "#{PrefixedFakeEndpoint.url()}/app/admin/tower_errors/occurrences/#{@id}"
    end

    test "returns nil when not configured" do
      put_env(:tower_web, :router, Router)
      assert TowerWeb.occurrence_url(@id) == nil

      Application.delete_env(:tower_web, :router)
      put_env(:tower_web, :endpoint, FakeEndpoint)
      assert TowerWeb.occurrence_url(@id) == nil
    end

    test "returns nil and warns when the router doesn't mount the dashboard" do
      put_env(:tower_web, :endpoint, FakeEndpoint)
      put_env(:tower_web, :router, RouterWithoutDashboard)

      log =
        capture_log(fn ->
          assert TowerWeb.occurrence_url(@id) == nil
        end)

      assert log =~ "TowerWebTest.RouterWithoutDashboard doesn't mount tower_dashboard"
    end

    test "follows TowerWeb.DB.disable/0 and enable/0" do
      put_env(:tower_web, :endpoint, FakeEndpoint)
      put_env(:tower_web, :router, Router)
      put_env(:tower_web, :enabled, true)

      TowerWeb.DB.disable()
      assert TowerWeb.occurrence_url(@id) == nil

      TowerWeb.DB.enable()

      assert TowerWeb.occurrence_url(@id) ==
               "#{FakeEndpoint.url()}/admin/tower_errors/occurrences/#{@id}"
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
