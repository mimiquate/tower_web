defmodule TowerWeb.Live.Occurrences.IndexTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Level
  alias TowerWeb.Live.Occurrences.Index, as: Occurrences

  describe "render/1" do
    test "shows empty message when no events" do
      html =
        render_component(&Occurrences.render/1, %{
          filtered_events: [],
          search_query: "",
          selected_level: nil,
          issue_ids_filtered: [],
          levels: Level.levels(),
          page: 1,
          total_pages: 1,
          total_count: 0,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          flash: %{},
          datetime_range_options: Filters.datetime_range_options(),
          datetime_range_param: "",
          datetime_range_menu_open: false
        })

      assert html =~ "No occurrences recorded yet."
      refute html =~ "<table"
    end

    test "shows table with events" do
      # Create real events in database
      {:ok, event1} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:30:00Z],
            level: :error,
            kind: :error,
            reason: %RuntimeError{message: "Something failed"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, event2} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: ~U[2024-03-14 09:00:00Z],
            level: :warning,
            kind: :throw,
            reason: "A warning occurred"
          },
          repo: TowerWeb.TestRepo
        )

      # Fetch events like the LiveView does
      events = Events.list_events(repo: TowerWeb.TestRepo)

      # Render with real events
      html =
        render_component(&Occurrences.render/1, %{
          filtered_events: events,
          search_query: "",
          selected_level: nil,
          issue_ids_filtered: [],
          levels: Level.levels(),
          page: 1,
          total_pages: 1,
          total_count: 2,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          flash: %{},
          datetime_range_options: Filters.datetime_range_options(),
          datetime_range_param: "",
          datetime_range_menu_open: false
        })

      assert html =~ "<table"
      assert html =~ "Something failed"
      assert html =~ "A warning occurred"
      assert html =~ "##{event1.id}"
      assert html =~ "##{event2.id}"
    end

    test "displays correct severity colors" do
      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:00:00Z],
            level: :error,
            kind: :error,
            reason: %RuntimeError{message: "Error event"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: ~U[2024-03-15 10:00:00Z],
            level: :warning,
            kind: :exit,
            reason: "Warning event"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 3,
            datetime: ~U[2024-03-15 10:00:00Z],
            level: :info,
            kind: :message,
            reason: "Info event"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)

      html =
        render_component(&Occurrences.render/1, %{
          filtered_events: events,
          search_query: "",
          selected_level: nil,
          issue_ids_filtered: [],
          levels: Level.levels(),
          page: 1,
          total_pages: 1,
          total_count: 3,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          flash: %{},
          datetime_range_options: Filters.datetime_range_options(),
          datetime_range_param: "",
          datetime_range_menu_open: false
        })

      # Error = red, Warning = yellow, Info = gray
      assert html =~ "text-red-500"
      assert html =~ "text-yellow-500"
      assert html =~ "text-gray-400"
    end

    test "formats date and time correctly" do
      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: ~U[2024-03-15 14:30:45Z],
            level: :error,
            kind: :message,
            reason: "Test error"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)

      html =
        render_component(&Occurrences.render/1, %{
          filtered_events: events,
          search_query: "",
          selected_level: nil,
          issue_ids_filtered: [],
          levels: Level.levels(),
          page: 1,
          total_pages: 1,
          total_count: 1,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          flash: %{},
          datetime_range_options: Filters.datetime_range_options(),
          datetime_range_param: "",
          datetime_range_menu_open: false
        })

      assert html =~ "15/03/2024"
      assert html =~ "02:30:45.000 PM UTC"
    end
  end

  describe "handle_params search" do
    test "filters events by reason and clears filter" do
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
            similarity_id: 1,
            datetime: DateTime.add(now, -2, :hour),
            kind: :message,
            level: :warning,
            reason: "Memory usage high"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      # Filter by "database"
      {:noreply, socket} =
        Occurrences.handle_params(%{"page" => "1", "search" => "database"}, "/tower", socket)

      # Verify socket assigns
      assert length(socket.assigns.filtered_events) == 1
      assert socket.assigns.search_query == "database"

      # Verify rendered HTML shows only filtered event
      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "Database connection failed"
      refute html =~ "Memory usage high"

      # Clear filter
      {:noreply, socket} = Occurrences.handle_params(%{"page" => "1"}, "/tower", socket)

      # Verify all events are shown again
      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "Database connection failed"
      assert html =~ "Memory usage high"
    end

    test "search is case insensitive" do
      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(DateTime.utc_now(), -1, :hour),
            kind: :message,
            level: :error,
            reason: "DATABASE ERROR"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      {:noreply, socket} =
        Occurrences.handle_params(
          %{"page" => "1", "search" => "database"},
          "/tower",
          socket
        )

      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "DATABASE ERROR"
    end

    test "returns empty list when no events match" do
      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:00:00Z],
            kind: :message,
            level: :error,
            reason: "Database connection failed"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      {:noreply, socket} =
        Occurrences.handle_params(%{"page" => "1", "search" => "nonexistent"}, "/tower", socket)

      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "No matching occurrences found."
      refute html =~ "Database connection failed"
    end
  end

  describe "handle_params level filter" do
    test "filters events by level" do
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
            similarity_id: 1,
            datetime: DateTime.add(now, -2, :hour),
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
            similarity_id: 1,
            datetime: DateTime.add(now, -3, :hour),
            kind: :error,
            level: :info,
            reason: %RuntimeError{message: "Info event"}
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      {:noreply, socket} =
        Occurrences.handle_params(%{"page" => "1", "level" => "error"}, "/tower", socket)

      assert length(socket.assigns.filtered_events) == 1
      assert socket.assigns.selected_level == "error"

      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "Error event"
      refute html =~ "Warning event"
      refute html =~ "Info event"
    end

    test "clears level filter when no level param" do
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
            similarity_id: 1,
            datetime: DateTime.add(now, -2, :hour),
            kind: :error,
            level: :warning,
            reason: %RuntimeError{message: "Warning event"}
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      {:noreply, socket} =
        Occurrences.handle_params(%{"page" => "1", "level" => "error"}, "/tower", socket)

      assert length(socket.assigns.filtered_events) == 1

      {:noreply, socket} = Occurrences.handle_params(%{"page" => "1"}, "/tower", socket)
      assert length(socket.assigns.filtered_events) == 2
      assert socket.assigns.selected_level == nil
    end

    test "combines search and level filters" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -1, :hour),
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Database error"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -2, :hour),
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Network error"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -3, :hour),
            kind: :error,
            level: :warning,
            reason: %RuntimeError{message: "Database warning"}
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      {:noreply, socket} =
        Occurrences.handle_params(
          %{"page" => "1", "search" => "database", "level" => "error"},
          "/tower",
          socket
        )

      assert length(socket.assigns.filtered_events) == 1
      assert socket.assigns.search_query == "database"
      assert socket.assigns.selected_level == "error"

      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "Database error"
      refute html =~ "Network error"
      refute html =~ "Database warning"
    end
  end

  describe "handle_params datetime range filter" do
    setup do
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

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 3,
            datetime: DateTime.add(now, -3, :day),
            kind: :error,
            level: :error,
            reason: "3 days ago"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 4,
            datetime: DateTime.add(now, -10, :day),
            kind: :error,
            level: :error,
            reason: "10 days ago"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)
      %{socket: socket_with_events(events)}
    end

    test "All time shows every event", %{socket: socket} do
      {:noreply, socket} =
        Occurrences.handle_params(%{"page" => "1", "datetime_range" => ""}, "/tower", socket)

      assert length(socket.assigns.filtered_events) == 4
    end

    test "Last hour filters to events within the last hour", %{socket: socket} do
      {:noreply, socket} =
        Occurrences.handle_params(
          %{"page" => "1", "datetime_range" => "last_hour"},
          "/tower",
          socket
        )

      assert length(socket.assigns.filtered_events) == 1
    end

    test "Last 24 hours filters to events within the last day", %{socket: socket} do
      {:noreply, socket} =
        Occurrences.handle_params(
          %{"page" => "1", "datetime_range" => "last_24h"},
          "/tower",
          socket
        )

      assert length(socket.assigns.filtered_events) == 2
    end

    test "Last 7 days filters to events within the last week", %{socket: socket} do
      {:noreply, socket} =
        Occurrences.handle_params(
          %{"page" => "1", "datetime_range" => "last_7d"},
          "/tower",
          socket
        )

      assert length(socket.assigns.filtered_events) == 3
    end
  end

  describe "handle_params issue_id filter" do
    test "filters events by a single issue_id" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -1, :hour),
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "First issue"}
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
            reason: %RuntimeError{message: "Second issue"}
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      {:noreply, socket} =
        Occurrences.handle_params(%{"page" => "1", "issue_ids" => "1"}, "/tower", socket)

      assert length(socket.assigns.filtered_events) == 1

      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "First issue"
      refute html =~ "Second issue"
    end

    test "filters events by more than one issue_id" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: DateTime.add(now, -1, :hour),
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "First issue"}
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
            reason: %RuntimeError{message: "Second issue"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 3,
            datetime: DateTime.add(now, -3, :hour),
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Third issue"}
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      {:noreply, socket} =
        Occurrences.handle_params(%{"page" => "1", "issue_ids" => "1,3"}, "/tower", socket)

      assert length(socket.assigns.filtered_events) == 2

      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "First issue"
      assert html =~ "Third issue"
      refute html =~ "Second issue"
    end
  end

  describe "allowed_filter_keys/0" do
    test "supports search, level, datetime_range, and issue_ids" do
      assert Occurrences.allowed_filter_keys() == [:search, :level, :datetime_range, :issue_ids]
    end
  end

  describe "handle_params current_filters" do
    test "assigns current_filters with the resolved filters, including issue_ids, following the same page-1 redirect a fresh nav takes" do
      {:noreply, redirected_socket} =
        Occurrences.handle_params(
          %{
            "search" => "timeout",
            "level" => "error",
            "datetime_range" => "last_30d",
            "issue_ids" => "1,2"
          },
          "/tower/occurrences",
          socket_with_occurrences()
        )

      assert {:live, :patch, %{to: to}} = redirected_socket.redirected

      %URI{query: query} = URI.parse(to)
      redirected_params = URI.decode_query(query)

      {:noreply, socket} =
        Occurrences.handle_params(
          redirected_params,
          "/tower/occurrences",
          socket_with_occurrences()
        )

      assert socket.assigns.current_filters == [
               search: "timeout",
               level: "error",
               datetime_range: "last_30d",
               issue_ids: ["1", "2"]
             ]
    end
  end

  defp socket_with_occurrences do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        base_path: "/tower",
        occurrences_base_path: "/tower/occurrences",
        datetime_range_options: Filters.datetime_range_options(),
        datetime_range_menu_open: false
      }
    }
  end

  defp socket_with_events(events) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        events: events,
        filtered_events: events,
        search_query: "",
        selected_level: nil,
        issue_ids_filtered: [],
        levels: Level.levels(),
        base_path: "/tower",
        flash: %{},
        occurrences_base_path: "/tower/occurrences",
        datetime_range_options: Filters.datetime_range_options(),
        datetime_range_menu_open: false
      }
    }
  end
end
