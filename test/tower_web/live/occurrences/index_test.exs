defmodule TowerWeb.Live.Occurrences.IndexTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
  alias TowerWeb.Live.Occurrences.Index, as: Occurrences

  @levels ~w(emergency alert critical error warning notice info)

  describe "render/1" do
    test "shows empty message when no events" do
      html =
        render_component(&Occurrences.render/1, %{
          filtered_events: [],
          search_query: "",
          selected_level: nil,
          issue_id_query: "",
          levels: @levels,
          page: 1,
          total_pages: 1,
          total_count: 0,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          flash: %{}
        })

      assert html =~ "No occurrences recorded yet."
      refute html =~ "<table"
    end

    test "shows table with events" do
      # Create real events in database
      {:ok, event1} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:30:00Z],
            kind: :error,
            level: :error,
            kind: :error,
            similarity_id: 1,
            reason: %RuntimeError{message: "Something failed"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, event2} =
        Events.create_event(
          %{
            similarity_id: 2,
            datetime: ~U[2024-03-14 09:00:00Z],
            kind: :error,
            level: :warning,
            kind: :throw,
            similarity_id: 2,
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
          issue_id_query: "",
          levels: @levels,
          page: 1,
          total_pages: 1,
          total_count: 2,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          flash: %{}
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
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:00:00Z],
            kind: :error,
            level: :error,
            kind: :error,
            similarity_id: 1,
            reason: %RuntimeError{message: "Error event"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 2,
            datetime: ~U[2024-03-15 10:00:00Z],
            kind: :error,
            level: :warning,
            kind: :exit,
            similarity_id: 2,
            reason: "Warning event"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 3,
            datetime: ~U[2024-03-15 10:00:00Z],
            kind: :error,
            level: :info,
            kind: :message,
            similarity_id: 3,
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
          issue_id_query: "",
          levels: @levels,
          page: 1,
          total_pages: 1,
          total_count: 3,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          flash: %{}
        })

      # Error = red, Warning = yellow, Info = gray
      assert html =~ "text-red-400"
      assert html =~ "text-yellow-400"
      assert html =~ "text-gray-400"
    end

    test "formats date and time correctly" do
      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 14:30:45Z],
            kind: :error,
            level: :error,
            kind: :message,
            similarity_id: 1,
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
          issue_id_query: "",
          levels: @levels,
          page: 1,
          total_pages: 1,
          total_count: 1,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          flash: %{}
        })

      assert html =~ "15/03/2024"
      assert html =~ "02:30:45 PM UTC"
    end
  end

  describe "handle_params search" do
    test "filters events by reason and clears filter" do
      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:00:00Z],
            kind: :message,
            level: :error,
            reason: "Database connection failed"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 11:00:00Z],
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
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:00:00Z],
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
      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:00:00Z],
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Error event"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 11:00:00Z],
            kind: :error,
            level: :warning,
            reason: %RuntimeError{message: "Warning event"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 12:00:00Z],
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
      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:00:00Z],
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Error event"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 11:00:00Z],
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
      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:00:00Z],
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Database error"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 11:00:00Z],
            kind: :error,
            level: :error,
            reason: %RuntimeError{message: "Network error"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 1,
            datetime: ~U[2024-03-15 12:00:00Z],
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

  defp socket_with_events(events) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        events: events,
        filtered_events: events,
        search_query: "",
        selected_level: nil,
        issue_id_query: "",
        levels: @levels,
        base_path: "/tower",
        flash: %{},
        occurrences_base_path: "/tower/occurrences"
      }
    }
  end
end
