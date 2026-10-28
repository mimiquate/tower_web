defmodule TowerWeb.DB.PrunerTest do
  use TowerWeb.DB.DataCase, async: false

  alias TowerWeb.DB.Events
  alias TowerWeb.DB.Issues
  alias TowerWeb.DB.Pruner

  defp insert_event(overrides) do
    attrs =
      Map.merge(
        %{
          id: UUIDv7.generate(),
          similarity_id: 1,
          datetime: DateTime.utc_now(),
          level: :error,
          kind: :error,
          reason: %RuntimeError{message: "boom"}
        },
        Map.new(overrides)
      )

    {:ok, %{event: event}} = Events.create_event_for_issue(attrs)
    event
  end

  defp ids_of(events), do: events |> Enum.map(& &1.id) |> Enum.sort()

  # Starts the pruner with a long interval so its timer never fires on its own,
  # then triggers a single prune cycle synchronously: `:sys.get_state/1` only
  # replies once every message queued ahead of it - including our `:prune` -
  # has been handled.
  defp prune(opts) do
    {:ok, pid} = Pruner.start_link(Keyword.put_new(opts, :interval, {999_999, :seconds}))
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)

    send(pid, :prune)
    :sys.get_state(pid)
    :ok
  end

  test "deletes events older than max_age and keeps the rest" do
    now = DateTime.utc_now()
    old = insert_event(datetime: DateTime.add(now, -200, :second))
    recent = insert_event(datetime: DateTime.add(now, -10, :second))

    prune(max_age: {100, :seconds})

    assert ids_of(Events.list_events(limit: 100)) == ids_of([recent])
    refute old.id in ids_of(Events.list_events(limit: 100))
  end

  test "keeps only the newest max_size_per_issue events per issue" do
    now = DateTime.utc_now()

    e1 = insert_event(similarity_id: 1, datetime: DateTime.add(now, -300, :second))
    e2 = insert_event(similarity_id: 1, datetime: DateTime.add(now, -200, :second))
    e3 = insert_event(similarity_id: 1, datetime: DateTime.add(now, -100, :second))
    e4 = insert_event(similarity_id: 1, datetime: now)
    other = insert_event(similarity_id: 2, datetime: DateTime.add(now, -500, :second))

    prune(max_size_per_issue: 2, max_age: {999_999_999, :seconds})

    remaining = ids_of(Events.list_events(limit: 100))
    assert remaining == ids_of([e3, e4, other])
    refute e1.id in remaining
    refute e2.id in remaining
  end

  test "prunes per issue_id, not per similarity_id, after a merge" do
    now = DateTime.utc_now()

    e1 = insert_event(similarity_id: 1, datetime: DateTime.add(now, -300, :second))
    e2 = insert_event(similarity_id: 2, datetime: DateTime.add(now, -200, :second))
    e3 = insert_event(similarity_id: 2, datetime: now)

    issue_id_1 = Events.get_event(e1.id).issue_id
    issue_id_2 = Events.get_event(e2.id).issue_id
    assert issue_id_1 != issue_id_2

    Issues.merge_issues(issue_id_1, [issue_id_2])

    prune(max_size_per_issue: 1, max_age: {999_999_999, :seconds})

    remaining = ids_of(Events.list_events(limit: 100))
    assert remaining == ids_of([e3])
    refute e1.id in remaining
    refute e2.id in remaining
  end

  test "prunes per issue_id, not per similarity_id, after an unmerge" do
    now = DateTime.utc_now()

    e1 = insert_event(similarity_id: 1, datetime: DateTime.add(now, -300, :second))
    e2 = insert_event(similarity_id: 1, datetime: DateTime.add(now, -200, :second))
    e3 = insert_event(similarity_id: 1, datetime: DateTime.add(now, -100, :second))
    e4 = insert_event(similarity_id: 1, datetime: now)

    {1, nil} = Events.unmerge_events([e1.id])

    prune(max_size_per_issue: 3, max_age: {999_999_999, :seconds})

    remaining = ids_of(Events.list_events(limit: 100))
    assert remaining == ids_of([e1, e2, e3, e4])
  end

  test "keeps only the newest max_size events overall, batching the deletes" do
    now = DateTime.utc_now()

    events =
      for i <- 1..10 do
        insert_event(similarity_id: i, datetime: DateTime.add(now, -(10 - i), :second))
      end

    kept = Enum.take(events, -2)

    prune(max_size: 2, batch_size: 2, max_age: {999_999_999, :seconds})

    assert ids_of(Events.list_events(limit: 100)) == ids_of(kept)
  end
end
