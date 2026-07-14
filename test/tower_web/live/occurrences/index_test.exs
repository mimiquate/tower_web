defmodule TowerWeb.Live.Occurrences.IndexTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
  alias TowerWeb.Live.Occurrences.Index, as: Occurrences

  describe "render/1" do
    test "shows empty message when no events" do
      html =
        render_component(&Occurrences.render/1, %{
          filtered_events: [],
          search_query: "",
          page: 1,
          total_pages: 1,
          total_count: 0,
          base_path: "/tower",
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
            reason: "Something failed"
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
          page: 1,
          total_pages: 1,
          total_count: 2,
          base_path: "/tower",
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
            reason: "Error event"
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
            reason: "Info event"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)

      html =
        render_component(&Occurrences.render/1, %{
          filtered_events: events,
          search_query: "",
          page: 1,
          total_pages: 1,
          total_count: 3,
          base_path: "/tower",
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
            reason: "Test error"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)

      html =
        render_component(&Occurrences.render/1, %{
          filtered_events: events,
          search_query: "",
          page: 1,
          total_pages: 1,
          total_count: 1,
          base_path: "/tower",
          flash: %{}
        })

      assert html =~ "15/03/2024"
      assert html =~ "02:30:45 PM UTC"
    end
  end

  describe "handle_params search" do
    test "filters events by reason and clears filter" do
      {:ok, _} = Events.create_event(%{
        datetime: ~U[2024-03-15 10:00:00Z],
        level: :error,
        reason: "Database connection failed"
      }, repo: TowerWeb.TestRepo)

      {:ok, _} = Events.create_event(%{
        datetime: ~U[2024-03-15 11:00:00Z],
        level: :warning,
        reason: "Memory usage high"
      }, repo: TowerWeb.TestRepo)

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      # Filter by "database"
      {:noreply, socket} = Occurrences.handle_params(%{"page" => "1", "search" => "database"}, "/tower", socket)

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
      {:ok, _} = Events.create_event(%{
        datetime: ~U[2024-03-15 10:00:00Z],
        level: :error,
        reason: "DATABASE ERROR"
      }, repo: TowerWeb.TestRepo)

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      {:noreply, socket} = Occurrences.handle_params(%{"page" => "1", "search" => "database"}, "/tower", socket)

      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "DATABASE ERROR"
    end

    test "returns empty list when no events match" do
      {:ok, _} = Events.create_event(%{
        datetime: ~U[2024-03-15 10:00:00Z],
        level: :error,
        reason: "Database connection failed"
      }, repo: TowerWeb.TestRepo)

      events = Events.list_events(repo: TowerWeb.TestRepo)
      socket = socket_with_events(events)

      {:noreply, socket} = Occurrences.handle_params(%{"page" => "1", "search" => "nonexistent"}, "/tower", socket)

      html = render_component(&Occurrences.render/1, socket.assigns)
      assert html =~ "No occurrences recorded yet."
      refute html =~ "Database connection failed"
    end
  end

  defp socket_with_events(events) do
    %Phoenix.LiveView.Socket{
      assigns: %{
        __changed__: %{},
        events: events,
        filtered_events: events,
        search_query: "",
        base_path: "/tower",
        flash: %{}
      }
    }
  end
end
