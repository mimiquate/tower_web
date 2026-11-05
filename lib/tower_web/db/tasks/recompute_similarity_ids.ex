defmodule TowerWeb.DB.RecomputeSimilarityIds do
  @moduledoc """
  Recomputes `similarity_id` for every `tower_web_events` row using the
  current grouping algorithm.

  Needed after a change to how `similarity_id` is calculated, so historical
  events reflect the same value the new algorithm would compute for them.
  `issue_id` is left untouched - this only updates `similarity_id` itself.
  """

  import Ecto.Query

  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Repo
  alias TowerWeb.DB.SimilarityId

  @doc """
  Options are passed as the second argument to `c:Ecto.Repo.transact/2`, so e.g.
  `:timeout` sets the timeout for the transaction's connection checkout. It does not
  apply to the individual queries run inside it.
  """
  def run(opts \\ []) do
    repo = Repo.repo()

    repo.transact(
      fn ->
        Event
        |> distinct([e], e.similarity_id)
        |> select([e], %{
          similarity_id: e.similarity_id,
          kind: e.kind,
          normalized_reason: e.normalized_reason,
          stacktrace: e.stacktrace
        })
        |> repo.all()
        |> Enum.each(fn event ->
          new_similarity_id =
            SimilarityId.compute(event.kind, event.normalized_reason, event.stacktrace)

          Event
          |> where([e], e.similarity_id == ^event.similarity_id)
          |> repo.update_all(set: [similarity_id: new_similarity_id])
        end)

        {:ok, :ok}
      end,
      opts
    )
  end
end
