defmodule TowerWeb.DB.Tasks.RecomputeSimilarityIdsTest do
  use TowerWeb.DB.DataCase, async: false

  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Issue
  alias TowerWeb.DB.Tasks.RecomputeSimilarityIds
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

  test "events sharing the same old similarity_id end up with the same new similarity_id" do
    event1 = insert_legacy_event(similarity_id: 111)
    event2 = insert_legacy_event(similarity_id: 111)

    {:ok, :ok} = RecomputeSimilarityIds.run()

    expected = SimilarityId.compute(:error, @normalized_reason, @stacktrace)

    assert reload(event1).similarity_id == expected
    assert reload(event2).similarity_id == expected
  end

  test "issue_id is never touched" do
    {:ok, issue} = Repo.repo().insert(%Issue{})

    event = insert_legacy_event(issue_id: issue.id, similarity_id: 111)

    {:ok, :ok} = RecomputeSimilarityIds.run()

    assert reload(event).issue_id == issue.id
  end
end
