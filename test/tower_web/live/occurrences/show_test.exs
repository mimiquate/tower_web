defmodule TowerWeb.Live.Occurrences.ShowTest do
  use TowerWeb.DB.DataCase

  import Phoenix.LiveViewTest

  alias TowerWeb.DB.Events
  alias TowerWeb.Live.Occurrences.Index
  alias TowerWeb.Live.Occurrences.Show

  @levels ~w(emergency alert critical error warning notice info)
  @datetime_range_options [
    {"All time", "all_time"},
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
          repo: TowerWeb.DB.TestRepo
        )

      events = Events.list_events(repo: TowerWeb.DB.TestRepo)

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
          datetime_range_from: "",
          datetime_range_to: "",
          datetime_range_menu_open: false,
          datetime_range_custom_open: false,
          selected_occurrences_ids: MapSet.new(),
          show_delete_modal: false,
          host_otp_app: :tower_web
        })

      assert html =~ ~s(href="/tower/occurrences/#{event.id}?page=1")
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
          repo: TowerWeb.DB.TestRepo
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
          repo: TowerWeb.DB.TestRepo
        )

      # Reload from database to ensure metadata is loaded properly
      event1 = Events.get_event(event1.id, repo: TowerWeb.DB.TestRepo)

      # Render show page with event1
      html =
        render_component(&Show.render/1, %{
          event: event1,
          base_path: "/tower",
          back_path: "/tower/occurrences?page=1",
          occurrences_base_path: "/tower/occurrences",
          issues_base_path: "/tower/issues",
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

    test "show page displays request data when present" do
      {:ok, event} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 3,
            datetime: ~U[2024-03-15 10:30:00Z],
            level: :error,
            kind: :error,
            reason: %RuntimeError{message: "Request error"},
            request_data: %{
              "method" => "GET",
              "url" => "https://example.com/users/1",
              "user_ip" => "127.0.0.1",
              "headers" => %{"user-agent" => "curl/8.0"},
              "params" => %{"id" => "1"}
            }
          },
          repo: TowerWeb.DB.TestRepo
        )

      event = Events.get_event(event.id, repo: TowerWeb.DB.TestRepo)

      html =
        render_component(&Show.render/1, %{
          event: event,
          base_path: "/tower",
          back_path: "/tower/occurrences?page=1",
          occurrences_base_path: "/tower/occurrences",
          issues_base_path: "/tower/issues",
          show_delete_modal: false,
          reason_expanded: false
        })

      assert html =~ "Request"
      assert html =~ "GET https://example.com/users/1"
      assert html =~ "127.0.0.1"
      assert html =~ "Headers"
      assert html =~ "user-agent"
      assert html =~ "curl/8.0"
      assert html =~ "Params"
      assert html =~ "id: &quot;1&quot;"
    end

    test "show page hides request section when request data is absent" do
      {:ok, event} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 4,
            datetime: ~U[2024-03-15 10:30:00Z],
            level: :error,
            kind: :error,
            reason: %RuntimeError{message: "No request error"}
          },
          repo: TowerWeb.DB.TestRepo
        )

      event = Events.get_event(event.id, repo: TowerWeb.DB.TestRepo)

      html =
        render_component(&Show.render/1, %{
          event: event,
          base_path: "/tower",
          back_path: "/tower/occurrences?page=1",
          occurrences_base_path: "/tower/occurrences",
          issues_base_path: "/tower/issues",
          show_delete_modal: false,
          reason_expanded: false
        })

      refute html =~ "Request</h2>"
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
          repo: TowerWeb.DB.TestRepo
        )

      assert length(Events.list_events(repo: TowerWeb.DB.TestRepo)) == 1

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

      assert Events.list_events(repo: TowerWeb.DB.TestRepo) == []

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
