defmodule TowerWeb.DB.Tasks.RecomputeSimilarityIdsTest do
  use TowerWeb.DB.DataCase, async: false

  import Ecto.Query

  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Issue
  alias TowerWeb.DB.RecomputeSimilarityIds
  alias TowerWeb.DB.Repo
  alias TowerWeb.DB.SimilarityId

  # TowerWeb.DB.Events is a real module compiled as part of :tower_web,
  # unlike a test-defined module, so :application.get_application/1
  # can correctly identify its OTP application.
  @stacktrace [
    {:some_library_module, :internal_fun, 2, [file: ~c"lib.ex", line: 5]},
    {TowerWeb.DB.Events, :run, 0, [file: ~c"test.exs", line: 1]}
  ]
  @normalized_reason Exception.format(:error, %RuntimeError{message: "boom"}, [])
  @other_normalized_reason Exception.format(:error, %ArgumentError{message: "different"}, [])

  # Inserts a row directly via a bare changeset, to simulate a historical row whose
  # similarity_id was computed by an older algorithm.
  defp insert_legacy_event(overrides) do
    repo = Repo.repo()

    attrs =
      Map.merge(
        %{
          id: UUIDv7.generate(),
          similarity_id: 111,
          datetime: DateTime.utc_now(),
          level: :error,
          kind: :error,
          normalized_reason: @normalized_reason,
          stacktrace: @stacktrace
        },
        Map.new(overrides)
      )

    %Event{}
    |> Ecto.Changeset.change(attrs)
    |> repo.insert!()
  end

  defp reload(event), do: Repo.repo().get(Event, event.id)

  defp distinct_similarity_id_count do
    Event
    |> distinct([e], e.similarity_id)
    |> Repo.repo().aggregate(:count)
  end

  test "recomputes similarity_id by content, independent of old similarity_id or issue_id, idempotently" do
    repo = Repo.repo()

    # Set up every event and issue first, covering the three relevant
    # combinations of old similarity_id vs. issue_id.
    {:ok, issue_a} = repo.insert(%Issue{})
    {:ok, issue_b} = repo.insert(%Issue{})
    {:ok, issue_c} = repo.insert(%Issue{})
    {:ok, issue_d} = repo.insert(%Issue{})

    # different issues, same old similarity_id
    event_diff_issue_1 = insert_legacy_event(issue_id: issue_a.id, similarity_id: 111)
    event_diff_issue_2 = insert_legacy_event(issue_id: issue_b.id, similarity_id: 111)

    # same issue, different old similarity_id
    event_same_issue_1 = insert_legacy_event(issue_id: issue_c.id, similarity_id: 222)

    event_same_issue_2 =
      insert_legacy_event(
        issue_id: issue_c.id,
        similarity_id: 333,
        normalized_reason: @other_normalized_reason
      )

    # same old similarity_id and same issue
    event_same_both_1 = insert_legacy_event(issue_id: issue_d.id, similarity_id: 444)
    event_same_both_2 = insert_legacy_event(issue_id: issue_d.id, similarity_id: 444)

    expected_default = SimilarityId.compute(:error, @normalized_reason, @stacktrace)
    expected_other = SimilarityId.compute(:error, @other_normalized_reason, @stacktrace)
    refute expected_default == expected_other

    assert distinct_similarity_id_count() == 4

    {:ok, :ok} = RecomputeSimilarityIds.run()

    reloaded_event_diff_issue_1 = reload(event_diff_issue_1)
    reloaded_event_diff_issue_2 = reload(event_diff_issue_2)
    reloaded_event_same_issue_1 = reload(event_same_issue_1)
    reloaded_event_same_issue_2 = reload(event_same_issue_2)
    reloaded_event_same_both_1 = reload(event_same_both_1)
    reloaded_event_same_both_2 = reload(event_same_both_2)

    # different issues, same old similarity_id -> same new similarity_id, issues untouched
    assert reloaded_event_diff_issue_1.similarity_id == expected_default
    assert reloaded_event_diff_issue_2.similarity_id == expected_default
    assert reloaded_event_diff_issue_1.issue_id == issue_a.id
    assert reloaded_event_diff_issue_2.issue_id == issue_b.id

    # same issue, different old similarity_id -> each recomputed from its own
    # content, so they end up different despite already sharing an issue
    assert reloaded_event_same_issue_1.similarity_id == expected_default
    assert reloaded_event_same_issue_2.similarity_id == expected_other
    assert reloaded_event_same_issue_1.issue_id == issue_c.id
    assert reloaded_event_same_issue_2.issue_id == issue_c.id

    # same old similarity_id and same issue -> both converge trivially, issue untouched
    assert reloaded_event_same_both_1.similarity_id == expected_default
    assert reloaded_event_same_both_2.similarity_id == expected_default
    assert reloaded_event_same_both_1.issue_id == issue_d.id
    assert reloaded_event_same_both_2.issue_id == issue_d.id

    # 4 old similarity_ids collapse down to 2 real content-based groups.
    assert distinct_similarity_id_count() == 2
  end
end
