defmodule TowerWeb.DB.Tasks.BackfillIssueUuids do
  @moduledoc """
  Generates a UUIDv7 id for every existing issue, writing it into the temporary
  `new_id`/`new_issue_id` columns added by migration V04, ahead of the column
  swap performed by migration V05.

  Meant to be run manually, between V04 and V05, before the application's full
  supervision tree starts - so nothing queries `Issue`/`Event` (which already assume
  the final UUID schema) against a database that hasn't been swapped yet.
  """

  import Ecto.Query

  alias TowerWeb.DB.Repo

  @doc """
  Options are passed as the second argument to `c:Ecto.Repo.transact/2`, so e.g.
  `:timeout` sets the timeout for the transaction's connection checkout. It does not
  apply to the individual queries run inside it.
  """
  def run(opts \\ []) do
    repo = Repo.repo()

    repo.transact(
      fn ->
        "tower_web_issues"
        |> where([i], is_nil(i.new_id))
        |> select([i], i.id)
        |> repo.stream()
        |> Enum.each(fn issue_id ->
          new_id = UUIDv7.generate() |> Ecto.UUID.dump!()

          "tower_web_issues"
          |> where([i], i.id == ^issue_id)
          |> repo.update_all(set: [new_id: new_id])

          "tower_web_events"
          |> where([e], e.issue_id == ^issue_id)
          |> repo.update_all(set: [new_issue_id: new_id])
        end)

        {:ok, :ok}
      end,
      opts
    )
  end
end
