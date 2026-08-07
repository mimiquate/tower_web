defmodule TowerWeb.Live.Occurrences.IndexTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
  alias TowerWeb.Live.Occurrences.Index, as: Occurrences

  describe "render/1" do
    test "shows empty message when no events" do
      html =
        render_component(&Occurrences.render/1, %{
          events: [],
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
            kind: :error,
            datetime: ~U[2024-03-15 10:30:00Z],
            level: :error,
            reason: "Something failed"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, event2} =
        Events.create_event(
          %{
            similarity_id: 2,
            kind: :error,
            datetime: ~U[2024-03-14 09:00:00Z],
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
          events: events,
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
            similarity_id: 3,
            kind: :error,
            datetime: ~U[2024-03-15 10:00:00Z],
            level: :error,
            reason: "Error event"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 4,
            kind: :error,
            datetime: ~U[2024-03-15 10:00:00Z],
            level: :warning,
            reason: "Warning event"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _} =
        Events.create_event(
          %{
            similarity_id: 5,
            kind: :error,
            datetime: ~U[2024-03-15 10:00:00Z],
            level: :info,
            reason: "Info event"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)

      html =
        render_component(&Occurrences.render/1, %{
          events: events,
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
            similarity_id: 6,
            kind: :error,
            datetime: ~U[2024-03-15 14:30:45Z],
            level: :error,
            reason: "Test error"
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)

      html =
        render_component(&Occurrences.render/1, %{
          events: events,
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
end
