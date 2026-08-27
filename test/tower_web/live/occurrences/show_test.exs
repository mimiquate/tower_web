defmodule TowerWeb.Live.Occurrences.ShowTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
  alias TowerWeb.Live.Occurrences.Index
  alias TowerWeb.Live.Occurrences.Show

  @levels ~w(emergency alert critical error warning notice info)
  @datetime_range_options [
    {"Last hour", "last_hour"},
    {"Last 24 hours", "last_24h"},
    {"Last 7 days", "last_7d"},
    {"Last 14 days", "last_14d"},
    {"Last 30 days", "last_30d"}
  ]

  describe "index to show navigation" do
    test "index page has link to correct occurrence" do
      {:ok, event} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:30:00Z],
            level: :error,
            kind: :error,
            reason: %RuntimeError{message: "Test error"}
          },
          repo: TowerWeb.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.TestRepo)

      html =
        render_component(&Index.render/1, %{
          filtered_events: events,
          search_query: "",
          selected_level: nil,
          issue_ids_filtered: [],
          levels: @levels,
          page: 1,
          total_pages: 1,
          total_count: 1,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          flash: %{},
          datetime_range_options: @datetime_range_options,
          datetime_range_param: "",
          datetime_range_menu_open: false
        })

      assert html =~ ~s(href="/tower/occurrences/#{event.id}?from_page=1")
    end

    test "show page displays the correct occurrence info" do
      {:ok, event1} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: ~U[2024-03-15 10:30:00Z],
            level: :error,
            kind: :error,
            reason: %RuntimeError{message: "First error message"},
            stacktrace: [{MyApp, :func, 1, [file: ~c"lib/app.ex", line: 10]}],
            metadata: %{user_id: 123, request_id: "abc"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _event2} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: ~U[2024-03-14 09:00:00Z],
            level: :warning,
            kind: :throw,
            reason: "Second error message"
          },
          repo: TowerWeb.TestRepo
        )

      # Reload from database to ensure metadata is loaded properly
      event1 = Events.get_event(event1.id, repo: TowerWeb.TestRepo)

      # Render show page with event1
      html =
        render_component(&Show.render/1, %{
          event: event1,
          base_path: "/tower",
          back_path: "/tower/occurrences?page=1",
          occurrences_base_path: "/tower/occurrences",
          issues_base_path: "/tower/issues",
          from_page: "1",
          show_delete_modal: false,
          reason_expanded: false
        })

      # Verify correct occurrence is displayed
      assert html =~ "##{event1.id}"
      assert html =~ "First error message"
      assert html =~ "app.ex"
      assert html =~ "user_id"
      assert html =~ "123"

      # Verify other occurrence is NOT displayed
      refute html =~ "Second error message"
    end
  end

  describe "delete event" do
    test "deletes event and redirects to list page with success flash" do
      {:ok, event} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:30:00Z],
            level: :error,
            kind: :message,
            reason: "Event to delete"
          },
          repo: TowerWeb.TestRepo
        )

      assert length(Events.list_events(repo: TowerWeb.TestRepo)) == 1

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          event: event,
          base_path: "/tower",
          occurrences_base_path: "/tower/occurrences",
          show_delete_modal: true,
          flash: %{},
          __changed__: %{}
        },
        redirected: nil
      }

      {:noreply, updated_socket} = Show.handle_event("confirm_delete", %{}, socket)

      assert Events.list_events(repo: TowerWeb.TestRepo) == []

      assert updated_socket.redirected ==
               {:live, :redirect, %{to: "/tower/occurrences", kind: :push}}

      assert updated_socket.assigns.flash["info"] == "Event deleted successfully"
    end
  end

  describe "event not found" do
    test "redirects to list page with error flash when event does not exist" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{flash: %{}, __changed__: %{}},
        redirected: nil
      }

      {:ok, updated_socket} =
        Show.mount(%{"id" => UUIDv7.generate()}, %{"base_path" => "/tower"}, socket)

      assert updated_socket.redirected ==
               {:live, :redirect, %{to: "/tower/occurrences", kind: :push}}

      assert updated_socket.assigns.flash["error"] == "Event not found"
    end
  end
end
