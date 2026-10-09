defmodule TowerWeb.DB.Issues do
  import Ecto.Query

  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Issue
  alias TowerWeb.DB.Repo

  @default_limit 20

  def list_issues(opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()
    filters = Keyword.get(opts, :filters, [])
    limit = Keyword.get(opts, :limit, @default_limit)
    offset = Keyword.get(opts, :offset, 0)

    ordered_ids =
      Issue
      |> where(^filter_where(filters))
      |> order_by([i],
        desc:
          fragment(
            "(SELECT MAX(datetime) FROM tower_web_events WHERE issue_id = ?)",
            i.id
          )
      )
      |> limit(^limit)
      |> offset(^offset)
      |> select([i], i.id)
      |> repo.all()

    load_issues(ordered_ids, repo)
  end

  def get_issue(id, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()
    recent_occurrences_limit = Keyword.get(opts, :recent_occurrences_limit)
    id = to_integer(id)

    case load_issues([id], repo) do
      [] ->
        nil

      [issue] when is_integer(recent_occurrences_limit) ->
        occurrences =
          Event
          |> where([e], e.issue_id == ^id)
          |> order_by(desc: :datetime)
          |> limit(^recent_occurrences_limit)
          |> repo.all()

        Map.put(issue, :occurrences, occurrences)

      [issue] ->
        issue
    end
  end

  def count_issues(opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()
    filters = Keyword.get(opts, :filters, [])

    Issue
    |> where(^filter_where(filters))
    |> repo.aggregate(:count)
  end

  def find_or_create_issue(similarity_id, opts \\ []) when is_integer(similarity_id) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    case Event
         |> where([e], e.similarity_id == ^similarity_id)
         |> select([e], e.issue_id)
         |> limit(1)
         |> repo.one() do
      nil ->
        {:ok, issue} =
          %Issue{}
          |> Issue.changeset(%{state: :unresolved})
          |> repo.insert()

        {:ok, issue.id}

      issue_id ->
        case repo.get(Issue, issue_id) do
          %Issue{state: :resolved} = issue ->
            {:ok, reopened_issue} =
              issue
              |> Issue.changeset(%{state: :unresolved})
              |> repo.update()

            {:ok, reopened_issue.id}

          %Issue{} ->
            {:ok, issue_id}
        end
    end
  end

  def update_issue(issue, attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()
    issue_struct = repo.get(Issue, issue.id)

    issue_struct
    |> Issue.changeset(attrs)
    |> repo.update()
  end

  def delete_issues_and_events(ids, opts \\ []) when is_list(ids) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    result = Event |> where([e], e.issue_id in ^ids) |> repo.delete_all()

    Issue |> where([i], i.id in ^ids) |> repo.delete_all()

    result
  end

  defp load_issues(ids, repo) do
    stats_by_id =
      Event
      |> where([e], e.issue_id in ^ids)
      |> join(:inner, [e], i in Issue, on: i.id == e.issue_id)
      |> distinct([e], e.issue_id)
      |> order_by([e], asc: e.issue_id, desc: e.datetime)
      |> select([e, i], %{
        id: e.issue_id,
        state: i.state,
        count_events: over(count(e.id), partition_by: e.issue_id),
        first_seen: over(min(e.datetime), partition_by: e.issue_id),
        last_seen: over(max(e.datetime), partition_by: e.issue_id),
        level: e.level,
        normalized_reason: e.normalized_reason,
        stacktrace: e.stacktrace
      })
      |> repo.all()
      |> Map.new(&{&1.id, &1})

    ids
    |> Enum.map(&Map.get(stats_by_id, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp to_integer(id) when is_integer(id), do: id
  defp to_integer(id) when is_binary(id), do: String.to_integer(id)

  defp filter_where(filters) do
    Enum.reduce(filters, dynamic(true), fn
      {:search, value}, dynamic when value != "" ->
        search_term = "%#{value}%"

        matching_ids =
          from(e in Event, where: ilike(e.normalized_reason, ^search_term), select: e.issue_id)

        dynamic([i], ^dynamic and i.id in subquery(matching_ids))

      {:level, value}, dynamic when not is_nil(value) ->
        matching_ids = from(e in Event, where: e.level == ^value, select: e.issue_id)
        dynamic([i], ^dynamic and i.id in subquery(matching_ids))

      {:id, value}, dynamic
      when is_binary(value) or is_list(value) or is_integer(value) ->
        value = List.wrap(value)
        dynamic([i], ^dynamic and i.id in ^value)

      {:datetime_range, {from, to}}, dynamic ->
        matching_ids =
          from(e in Event,
            where: e.datetime >= ^from and e.datetime <= ^to,
            select: e.issue_id
          )

        dynamic([i], ^dynamic and i.id in subquery(matching_ids))

      {_, _}, dynamic ->
        dynamic
    end)
  end
end
