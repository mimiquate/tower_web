defmodule TowerWeb.Live.Issues.IndexTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
  alias TowerDB.Issues
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Level
  alias TowerWeb.Live.Issues.Index, as: IssuesIndex

  describe "render/1" do
    test "shows table with issues" do
      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:30:00Z],
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Something failed"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: ~U[2024-03-14 09:00:00Z],
            kind: :throw,
            level: :warning,
            reason: "A warning occurred"
          },
          repo: TowerWeb.TestRepo
        )

      issues = Issues.list_issues(repo: TowerWeb.TestRepo)

      html =
        render_component(&IssuesIndex.render/1, %{
          issues: issues,
          search_query: "",
          selected_level: nil,
          issue_ids_filtered: [],
          levels: Level.levels(),
          page: 1,
          total_pages: 1,
          base_path: "/tower",
          issues_base_path: "/tower/issues",
          datetime_range_options: Filters.datetime_range_options(),
          datetime_range_param: "",
          datetime_range_menu_open: false,
          flash: %{}
        })

      assert html =~ "<table"
      assert html =~ "Something failed"
      assert html =~ "A warning occurred"
      assert html =~ "#1"
      assert html =~ "#2"
    end
  end

  describe "handle_params search" do
    test "filters issues by reason" do
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

      socket = socket_with_issues()

      {:noreply, socket} =
        IssuesIndex.handle_params(%{"page" => "1", "search" => "database"}, "/tower", socket)

      assert length(socket.assigns.issues) == 1
      assert socket.assigns.search_query == "database"

      html = render_component(&IssuesIndex.render/1, socket.assigns)
      assert html =~ "Database connection failed"
      refute html =~ "Memory usage high"
    end
  end

  describe "handle_params level filter" do
    test "filters issues by level" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -1, :hour),
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Error event"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(now, -2, :hour),
            kind: :error,
            level: :warning,
            reason: %RuntimeError{message: "Warning event"}
          },
          repo: TowerWeb.TestRepo
        )

      socket = socket_with_issues()

      {:noreply, socket} =
        IssuesIndex.handle_params(%{"page" => "1", "level" => "error"}, "/tower", socket)

      assert length(socket.assigns.issues) == 1
      assert socket.assigns.selected_level == "error"

      html = render_component(&IssuesIndex.render/1, socket.assigns)
      assert html =~ "Error event"
      refute html =~ "Warning event"
    end
  end

  describe "handle_params datetime range filter" do
    test "Last hour filters to issues within the last hour" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -30, :minute),
            kind: :error,
            level: :error,
            reason: "30 minutes ago"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(now, -2, :hour),
            kind: :error,
            level: :error,
            reason: "2 hours ago"
          },
          repo: TowerWeb.TestRepo
        )

      socket = socket_with_issues()

      {:noreply, socket} =
        IssuesIndex.handle_params(
          %{"page" => "1", "datetime_range" => "last_hour"},
          "/tower",
          socket
        )

      assert length(socket.assigns.issues) == 1
    end
  end

  describe "handle_params issue id filter" do
    test "filter issues by id" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -1, :hour),
            kind: :error,
            level: :warning,
            reason: %RuntimeError{message: "Warning event"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(now, -1, :hour),
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Error event"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 3,
            datetime: DateTime.add(now, -1, :hour),
            kind: :error,
            level: :critical,
            reason: %RuntimeError{message: "Critical event"}
          },
          repo: TowerWeb.TestRepo
        )

      socket = socket_with_issues()

      {:noreply, socket} =
        IssuesIndex.handle_params(%{"page" => "1", "issue_ids" => "1"}, "/tower", socket)

      assert length(socket.assigns.issues) == 1
    end
  end

  describe "allowed_filter_keys/0" do
    test "supports search, level, datetime_range, and issue_ids" do
      assert IssuesIndex.allowed_filter_keys() == [:search, :level, :datetime_range, :issue_ids]
    end
  end

  describe "handle_params current_filters" do
    test "assigns current_filters with the resolved filters, including issue_ids, following the same page-1 redirect a fresh nav takes" do
      {:noreply, redirected_socket} =
        IssuesIndex.handle_params(
          %{
            "search" => "timeout",
            "level" => "error",
            "datetime_range" => "last_30d",
            "issue_ids" => "1,2"
          },
          "/tower/issues",
          socket_with_issues()
        )

      assert {:live, :patch, %{to: to}} = redirected_socket.redirected

      %URI{query: query} = URI.parse(to)
      redirected_params = URI.decode_query(query)

      {:noreply, socket} =
        IssuesIndex.handle_params(redirected_params, "/tower/issues", socket_with_issues())

      assert socket.assigns.current_filters == [
               search: "timeout",
               level: "error",
               datetime_range: "last_30d",
               issue_ids: ["1", "2"]
             ]
    end
  end

  defp socket_with_issues do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        search_query: "",
        selected_level: nil,
        levels: Level.levels(),
        base_path: "/tower",
        issues_base_path: "/tower/issues",
        datetime_range_options: Filters.datetime_range_options(),
        datetime_range_menu_open: false,
        flash: %{}
      }
    }
  end
end
