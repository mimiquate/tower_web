defmodule TowerWeb.DB.BackfillIssueUuidsTest do
  use TowerWeb.DB.DataCase, async: false

  alias TowerWeb.DB.BackfillIssueUuids
  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Events
  alias TowerWeb.DB.Issue
  alias TowerWeb.DB.TestRepo

  test "assigns a new_id to issues missing one, and matches it on their events' new_issue_id" do
    {:ok, %{event: event_a1}} =
      Events.create_event_for_issue(%{
        id: UUIDv7.generate(),
        similarity_id: 1,
        datetime: ~U[2026-05-08 10:00:00.000000Z],
        level: :error,
        kind: :error,
        reason: %RuntimeError{message: "issue A, event 1"}
      })

    {:ok, %{event: event_a2}} =
      Events.create_event_for_issue(%{
        id: UUIDv7.generate(),
        similarity_id: 1,
        datetime: ~U[2026-05-08 11:00:00.000000Z],
        level: :error,
        kind: :error,
        reason: %RuntimeError{message: "issue A, event 2"}
      })

    {:ok, %{event: event_b}} =
      Events.create_event_for_issue(%{
        id: UUIDv7.generate(),
        similarity_id: 2,
        datetime: ~U[2026-05-08 12:00:00.000000Z],
        level: :warning,
        kind: :error,
        reason: %ArgumentError{message: "issue B"}
      })

    # Simulate pre-existing data from before this feature existed: wipe out the new_id
    # these events already got via the normal dual-write path.
    TestRepo.update_all(Issue, set: [new_id: nil])
    TestRepo.update_all(Event, set: [new_issue_id: nil])

    BackfillIssueUuids.run()

    issue_a = TestRepo.get(Issue, event_a1.issue_id)
    issue_b = TestRepo.get(Issue, event_b.issue_id)

    assert issue_a.new_id != nil
    assert issue_b.new_id != nil
    assert issue_a.new_id != issue_b.new_id

    events = Events.list_events() |> Map.new(&{&1.id, &1})

    assert events[event_a1.id].new_issue_id == issue_a.new_id
    assert events[event_a2.id].new_issue_id == issue_a.new_id
    assert events[event_b.id].new_issue_id == issue_b.new_id
  end
end
