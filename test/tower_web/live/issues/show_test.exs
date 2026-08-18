defmodule TowerWeb.Live.Issues.ShowTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerDB.Events
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

      {:ok, _old_event_outside_range} =
        Events.create_event(
          %{
            id: UUIDv7.generate(),
            similarity_id: 2,
            datetime: DateTime.add(now, -45, :day),
            level: :error,
            kind: :error,
            reason: "Old occurrence outside 30 day range"
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

      # Total Occurrences/heading count only reflects events within the last 30 days
      assert html =~ "Occurrences (2)"

      # the recent occurrences list only includes events within the last 30 days
      assert html =~ "First occurrence message"
      refute html =~ "Old occurrence outside 30 day range"

      # Verify unrelated issue is NOT displayed
      refute html =~ "Unrelated issue message"
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
