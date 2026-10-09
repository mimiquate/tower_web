defmodule TowerWeb.DB.IssuesTest do
  use TowerWeb.DB.DataCase, async: false

  alias TowerWeb.DB.Events
  alias TowerWeb.DB.Issues

  describe "list_issues/1" do
    test "lists distinct issues grouped by similarity_id" do
      {:ok, event_a1} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 10:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "first occurrence of error A"}
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 12:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "second occurrence of error A"}
        })

      {:ok, event_b} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 2,
          datetime: ~U[2026-05-08 11:00:00.000000Z],
          level: :warning,
          kind: :error,
          reason: %ArgumentError{message: "error B"}
        })

      issues = Issues.list_issues()

      assert length(issues) == 2

      issue_a = Enum.find(issues, &(&1.id == event_a1.issue_id))
      issue_b = Enum.find(issues, &(&1.id == event_b.issue_id))

      assert issue_a.count_events == 2
      assert issue_a.first_seen == ~U[2026-05-08 10:00:00.000000Z]
      assert issue_a.last_seen == ~U[2026-05-08 12:00:00.000000Z]
      assert issue_a.normalized_reason =~ "first occurrence of error A"

      assert issue_b.count_events == 1
      assert issue_b.first_seen == ~U[2026-05-08 11:00:00.000000Z]
      assert issue_b.last_seen == ~U[2026-05-08 11:00:00.000000Z]
      assert issue_b.normalized_reason =~ "error B"
    end

    test "returns all issues without filters and only matching ones with a search filter" do
      {:ok, event_a} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 10:00:00.000000Z],
          level: :error,
          kind: :message,
          reason: "Database connection failed"
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 2,
          datetime: ~U[2026-05-08 11:00:00.000000Z],
          level: :warning,
          kind: :message,
          reason: "Memory usage high"
        })

      assert length(Issues.list_issues()) == 2

      issues = Issues.list_issues(filters: [search: "database"])

      assert length(issues) == 1
      assert hd(issues).id == event_a.issue_id
    end

    test "paginates results with limit and offset" do
      {:ok, event_a} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 10:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "error A"}
        })

      {:ok, event_b} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 2,
          datetime: ~U[2026-05-08 11:00:00.000000Z],
          level: :warning,
          kind: :error,
          reason: %ArgumentError{message: "error B"}
        })

      {:ok, event_c} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 3,
          datetime: ~U[2026-05-08 12:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "error C"}
        })

      page_1 = Issues.list_issues(limit: 2, offset: 0)
      page_2 = Issues.list_issues(limit: 2, offset: 2)

      assert Enum.map(page_1, & &1.id) == [event_c.issue_id, event_b.issue_id]
      assert Enum.map(page_2, & &1.id) == [event_a.issue_id]
    end

    test "orders issues by last_seen descending" do
      {:ok, event_a} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 10:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "error A"}
        })

      {:ok, event_b} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 2,
          datetime: ~U[2026-05-08 12:00:00.000000Z],
          level: :warning,
          kind: :error,
          reason: %ArgumentError{message: "error B"}
        })

      {:ok, event_c} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 3,
          datetime: ~U[2026-05-08 11:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "error C"}
        })

      issues = Issues.list_issues()

      assert Enum.map(issues, & &1.id) == [event_b.issue_id, event_c.issue_id, event_a.issue_id]
    end

    test "count_events, first_seen and last_seen are not scoped to the datetime_range filter" do
      now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
      outside_window = DateTime.add(now, -10, :day)
      another_outside_window = DateTime.add(now, -5, :day)
      inside_window = DateTime.add(now, -1, :hour)

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: outside_window,
          level: :error,
          kind: :message,
          reason: "Older occurrence outside the filtered window"
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: another_outside_window,
          level: :error,
          kind: :message,
          reason: "Another occurrence outside the filtered window"
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: inside_window,
          level: :error,
          kind: :message,
          reason: "Recent occurrence inside the filtered window"
        })

      datetime_range = {DateTime.add(now, -2, :hour), now}

      [issue] = Issues.list_issues(filters: [datetime_range: datetime_range])

      assert issue.count_events == 3
      assert issue.first_seen == outside_window
      assert issue.last_seen == inside_window
      assert issue.normalized_reason == "Older occurrence outside the filtered window"
    end
  end

  describe "get_issue/2" do
    test "returns the issue matching the given id" do
      {:ok, event_a1} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 10:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "first occurrence of error A"}
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 12:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "second occurrence of error A"}
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 2,
          datetime: ~U[2026-05-08 11:00:00.000000Z],
          level: :warning,
          kind: :error,
          reason: %ArgumentError{message: "error B"}
        })

      issue = Issues.get_issue(event_a1.issue_id)

      assert issue.id == event_a1.issue_id
      assert issue.count_events == 2
      assert issue.normalized_reason =~ "first occurrence of error A"
    end
  end

  describe "count_issues/1" do
    test "counts distinct similarity_ids, not total events, and respects filters" do
      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 10:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "first occurrence of error A"}
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 11:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "second occurrence of error A"}
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 2,
          datetime: ~U[2026-05-08 12:00:00.000000Z],
          level: :warning,
          kind: :error,
          reason: %ArgumentError{message: "error B"}
        })

      assert Issues.count_issues() == 2
      assert Issues.count_issues(filters: [level: :warning]) == 1
    end
  end

  describe "delete_issue/2" do
    test "deletes all events for the given similarity_id and returns the count" do
      {:ok, event_a1} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 10:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "first occurrence of error A"}
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 11:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "second occurrence of error A"}
        })

      {:ok, kept_event} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 2,
          datetime: ~U[2026-05-08 12:00:00.000000Z],
          level: :warning,
          kind: :error,
          reason: %ArgumentError{message: "error B"}
        })

      assert Issues.delete_issue(event_a1.issue_id) == {2, nil}

      remaining_ids = Events.list_events() |> Enum.map(& &1.id)
      assert remaining_ids == [kept_event.id]

      assert Issues.get_issue(event_a1.issue_id) == nil
      assert Issues.get_issue(kept_event.issue_id) != nil
    end
  end

  describe "find_or_create_issue/2 (via Events.create_event/2)" do
    test "creates the issue on the first event for a similarity_id" do
      {:ok, event} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 12:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "first occurrence"}
        })

      issue = Issues.get_issue(event.issue_id)

      assert issue.count_events == 1
      assert issue.first_seen == ~U[2026-05-08 12:00:00.000000Z]
      assert issue.last_seen == ~U[2026-05-08 12:00:00.000000Z]
      assert issue.level == :error
      assert issue.normalized_reason =~ "first occurrence"
    end

    test "increments count_events and extends first_seen/last_seen, with level/normalized_reason/stacktrace reflecting the event with the earliest datetime" do
      {:ok, event} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 12:00:00.000000Z],
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "first occurrence"}
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 14:00:00.000000Z],
          level: :warning,
          kind: :error,
          reason: %ArgumentError{message: "later occurrence"}
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 10:00:00.000000Z],
          level: :warning,
          kind: :error,
          reason: %ArgumentError{message: "backfilled earlier occurrence"}
        })

      {:ok, _} =
        Events.create_event(%{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: ~U[2026-05-08 13:00:00.000000Z],
          level: :warning,
          kind: :error,
          reason: %ArgumentError{message: "occurrence within the existing range"}
        })

      issue = Issues.get_issue(event.issue_id)

      assert issue.count_events == 4
      assert issue.first_seen == ~U[2026-05-08 10:00:00.000000Z]
      assert issue.last_seen == ~U[2026-05-08 14:00:00.000000Z]
      assert issue.level == :warning
      assert issue.normalized_reason =~ "backfilled earlier occurrence"
    end
  end
end
