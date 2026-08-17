defmodule TowerWeb.Live.Dashboard.IndexTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
  alias TowerWeb.Live.Dashboard.Index, as: Dashboard
  alias TowerWeb.Live.Filters

  describe "render/1" do
    test "shows total errors and total occurrences" do
      html =
        render_component(&Dashboard.render/1, %{
          total_errors: 3,
          total_occurrences: 7,
          search_query: "",
          selected_level: nil,
          levels: Filters.levels(),
          datetime_range_options: Filters.datetime_range_options(),
          datetime_range_param: "",
          datetime_range_menu_open: false
        })

      assert html =~ "Total Errors"
      assert html =~ "3"
      assert html =~ "Total Occurrences"
      assert html =~ "7"
    end
  end

  describe "handle_params" do
    test "filters counts by search" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -1, :hour),
            kind: :message,
            level: :error,
            reason: "Database connection failed"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(now, -2, :hour),
            kind: :message,
            level: :warning,
            reason: "Memory usage high"
          },
          repo: TowerWeb.TestRepo
        )

      {:noreply, socket} =
        Dashboard.handle_params(
          %{"search" => "database"},
          "/tower/dashboard",
          socket_with_dashboard()
        )

      assert socket.assigns.total_errors == 1
      assert socket.assigns.total_occurrences == 1
      assert socket.assigns.search_query == "database"
    end

    test "filters counts by level" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -1, :hour),
            kind: :message,
            level: :error,
            reason: "Database connection failed"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(now, -2, :hour),
            kind: :message,
            level: :warning,
            reason: "Memory usage high"
          },
          repo: TowerWeb.TestRepo
        )

      {:noreply, socket} =
        Dashboard.handle_params(
          %{"level" => "error"},
          "/tower/dashboard",
          socket_with_dashboard()
        )

      assert socket.assigns.total_errors == 1
      assert socket.assigns.total_occurrences == 1
      assert socket.assigns.selected_level == "error"
    end

    test "filters counts by datetime_range" do
      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(DateTime.utc_now(), -30, :minute),
            kind: :message,
            level: :error,
            reason: "inside range"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(DateTime.utc_now(), -2, :day),
            kind: :message,
            level: :warning,
            reason: "outside range"
          },
          repo: TowerWeb.TestRepo
        )

      {:noreply, socket} =
        Dashboard.handle_params(
          %{"datetime_range" => "last_hour"},
          "/tower/dashboard",
          socket_with_dashboard()
        )

      assert socket.assigns.total_errors == 1
      assert socket.assigns.total_occurrences == 1
      assert socket.assigns.datetime_range_param == "last_hour"
    end
  end

  defp socket_with_dashboard do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        base_path: "/tower",
        dashboard_base_path: "/tower/dashboard",
        datetime_range_options: Filters.datetime_range_options(),
        datetime_range_menu_open: false,
        levels: Filters.levels()
      }
    }
  end
end
