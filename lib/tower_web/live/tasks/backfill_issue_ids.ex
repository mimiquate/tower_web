defmodule TowerWeb.DB.BackfillIssueIds do
  @moduledoc """
  Backfills `issue_id` on `tower_web_events` rows that don't have one yet.

  This is needed when adopting `tower_web`'s storage layer on top of data that already
  existed before the `issue_id` column was introduced (for example, events migrated over
  from the standalone `tower_db` package). Each run groups the affected rows by
  `similarity_id` and assigns one new issue per group.
  """

  import Ecto.Query

  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Issue
  alias TowerWeb.DB.Repo

  def run do
    repo = Repo.repo()

    repo.transact(fn ->
      Event
      |> where([e], is_nil(e.issue_id))
      |> distinct([e], e.similarity_id)
      |> select([e], e.similarity_id)
      |> repo.stream()
      |> Enum.each(fn similarity_id ->
        {:ok, issue} = repo.insert(%Issue{})

        Event
        |> where([e], e.similarity_id == ^similarity_id and is_nil(e.issue_id))
        |> repo.update_all(set: [issue_id: issue.id])
      end)

      {:ok, :ok}
    end)
  end
end
