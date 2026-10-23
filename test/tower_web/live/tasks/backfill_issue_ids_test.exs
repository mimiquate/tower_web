defmodule TowerWeb.DB.Tasks.BackfillIssueIdsTest do
  use TowerWeb.DB.DataCase, async: false

  alias TowerWeb.DB.Tasks.BackfillIssueIds
  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Events
  alias TowerWeb.DB.Repo

  test "assigns a new issue_id to events missing one, without touching events that already have one" do
    {:ok, %{event: event_with_issue}} =
      Events.create_event_for_issue(%{
        id: UUIDv7.generate(),
        similarity_id: 1,
        datetime: ~U[2026-05-08 10:00:00.000000Z],
        level: :error,
        kind: :error,
        reason: %RuntimeError{message: "already has an issue"}
      })

    repo = Repo.repo()

    {:ok, event_without_issue} =
      %Event{}
      |> Event.changeset(%{
        id: UUIDv7.generate(),
        similarity_id: 2,
        datetime: ~U[2026-05-08 11:00:00.000000Z],
        level: :error,
        kind: :error,
        reason: %RuntimeError{message: "missing an issue"}
      })
      |> repo.insert()

    assert event_without_issue.issue_id == nil

    BackfillIssueIds.run()

    reloaded_event_with_issue = Events.get_event(event_with_issue.id)
    reloaded_event_without_issue = Events.get_event(event_without_issue.id)

    assert reloaded_event_with_issue.issue_id == event_with_issue.issue_id
    assert reloaded_event_without_issue.issue_id != nil
  end
end
