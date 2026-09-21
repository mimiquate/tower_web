defmodule TowerWeb.Live.Dashboard.IndexTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
  alias TowerWeb.Live.Dashboard.Index, as: Dashboard
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Level

  describe "render/1" do
    test "shows total errors and total occurrences" do
      html =
        render_component(&Dashboard.render/1, %{
          total_errors: 3,
          total_occurrences: 7,
          show_chart: true,
          chart_datetimes: [],
          chart_datetime_range: Filters.datetime_range("last_7d"),
          search_query: "",
          selected_level: nil,
          levels: Level.levels(),
          datetime_range_options: Filters.datetime_range_options(),
          datetime_range_param: "",
          datetime_range_from: "",
          datetime_range_to: "",
          datetime_range_menu_open: false,
          datetime_range_custom_open: false,
          flash: %{}
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

  describe "allowed_filter_keys/0" do
    test "supports search, level, datetime_range, and datetime_range_from/to, but not issue_ids" do
      assert Dashboard.allowed_filter_keys() == [
               :search,
               :level,
               :datetime_range,
               :datetime_range_from,
               :datetime_range_to
             ]
    end
  end

  describe "handle_params current_filters" do
    test "assigns current_filters with the resolved search/level/datetime_range" do
      {:noreply, socket} =
        Dashboard.handle_params(
          %{"search" => "timeout", "level" => "error", "datetime_range" => "last_30d"},
          "/tower/dashboard",
          socket_with_dashboard()
        )

      assert socket.assigns.current_filters == [
               search: "timeout",
               level: "error",
               datetime_range: "last_30d",
               datetime_range_from: "",
               datetime_range_to: ""
             ]
    end

    test "assigns current_filters with defaults when no params are given" do
      {:noreply, socket} =
        Dashboard.handle_params(%{}, "/tower/dashboard", socket_with_dashboard())

      assert socket.assigns.current_filters == [
               search: "",
               level: nil,
               datetime_range: "last_7d",
               datetime_range_from: "",
               datetime_range_to: ""
             ]
    end

    test "assigns current_filters with datetime_range_from/to when datetime_range is custom" do
      {:noreply, socket} =
        Dashboard.handle_params(
          %{
            "datetime_range" => "custom",
            "datetime_range_from" => "2026-01-01",
            "datetime_range_to" => "2026-01-31"
          },
          "/tower/dashboard",
          socket_with_dashboard()
        )

      assert socket.assigns.current_filters == [
               search: "",
               level: nil,
               datetime_range: "custom",
               datetime_range_from: "2026-01-01",
               datetime_range_to: "2026-01-31"
             ]

      assert socket.assigns.datetime_range_custom_open
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
        levels: Level.levels()
      }
    }
  end
end
