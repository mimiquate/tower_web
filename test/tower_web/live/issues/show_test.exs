defmodule TowerWeb.Live.Issues.ShowTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
  alias TowerDB.Issues
  alias TowerWeb.Live.Issues.Show

  describe "index to show navigation" do
    test "show page displays the correct issue info" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, _older_event} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(now, -5, :day),
            level: :warning,
            kind: :throw,
            reason: "First occurrence message"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _latest_event} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(now, -1, :day),
            level: :error,
            kind: :error,
            reason: %RuntimeError{message: "Latest error message"}
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _old_event} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(now, -45, :day),
            level: :error,
            kind: :error,
            reason: "Old occurrence outside chart range"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _other_issue_event} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 3,
            datetime: DateTime.add(now, -1, :day),
            level: :error,
            kind: :error,
            reason: "Unrelated issue message"
          },
          repo: TowerWeb.TestRepo
        )

      socket = %Phoenix.LiveView.Socket{assigns: %{flash: %{}, __changed__: %{}}}

      {:ok, socket} = Show.mount(%{"id" => "2"}, %{"base_path" => "/tower"}, socket)
      {:noreply, socket} = Show.handle_params(%{}, "/tower/issues/2", socket)

      html = render_component(&Show.render/1, socket.assigns)

      # Verify correct issue is displayed (last_event is the most recent one)
      assert html =~ "ID: #2"
      assert html =~ "Latest error message"

      # count_events includes every event for the issue, even ones outside the 30-day window
      assert html =~ "Occurrences (3)"

      # the recent occurrences list only includes events within the last 30 days
      assert html =~ "First occurrence message"
      refute html =~ "Old occurrence outside 30 day range"

      # Verify unrelated issue is NOT displayed
      refute html =~ "Unrelated issue message"
    end
  end

  describe "delete issue" do
    test "deletes all of the issue's events and redirects to list page with success flash" do
      {:ok, _event1} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: ~U[2024-03-15 10:30:00Z],
            level: :error,
            kind: :message,
            reason: "Occurrence to delete 1"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, _event2} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 1,
            datetime: ~U[2024-03-15 11:30:00Z],
            level: :error,
            kind: :message,
            reason: "Occurrence to delete 2"
          },
          repo: TowerWeb.TestRepo
        )

      {:ok, kept_event} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: ~U[2024-03-15 12:30:00Z],
            level: :error,
            kind: :message,
            reason: "Unrelated occurrence"
          },
          repo: TowerWeb.TestRepo
        )

      issue = Issues.get_issue(1, repo: TowerWeb.TestRepo)

      socket = %Phoenix.LiveView.Socket{
        assigns: %{
          issue: issue,
          base_path: "/tower",
          issues_base_path: "/tower/issues",
          show_delete_modal: true,
          flash: %{},
          __changed__: %{}
        },
        redirected: nil
      }

      {:noreply, updated_socket} = Show.handle_event("confirm_delete", %{}, socket)

      assert Events.list_events(filters: [similarity_id: [1]], repo: TowerWeb.TestRepo) == []

      remaining_ids =
        Events.list_events(repo: TowerWeb.TestRepo) |> Enum.map(& &1.id)

      assert remaining_ids == [kept_event.id]

      assert updated_socket.redirected ==
               {:live, :redirect, %{to: "/tower/issues", kind: :push}}

      assert updated_socket.assigns.flash["info"] == "Issue deleted successfully"
    end
  end

  describe "issue not found" do
    test "redirects to list page with error flash when issue does not exist" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{flash: %{}, __changed__: %{}},
        redirected: nil
      }

      {:ok, updated_socket} = Show.mount(%{"id" => "999999"}, %{"base_path" => "/tower"}, socket)

      assert updated_socket.redirected == {:live, :redirect, %{to: "/tower/issues", kind: :push}}
      assert updated_socket.assigns.flash["error"] == "Issue not found"
    end
  end
end
