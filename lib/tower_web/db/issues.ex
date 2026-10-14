defmodule TowerWeb.DB.Issues do
  import Ecto.Query

  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Issue
  alias TowerWeb.DB.Repo

  @default_limit 20

  def list_issues(opts \\ []) do
    repo = Repo.repo()
    filters = Keyword.get(opts, :filters, [])
    limit = Keyword.get(opts, :limit, @default_limit)
    offset = Keyword.get(opts, :offset, 0)

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
    |> select_merge([i], %{
      count_events:
        type(
          fragment("(SELECT COUNT(*) FROM tower_web_events WHERE issue_id = ?)", i.id),
          :integer
        )
    })
    |> preload(first_event: ^Issue.first_event_query(), last_event: ^Issue.last_event_query())
    |> repo.all()
  end

  def get_issue(id, opts \\ []) do
    repo = Repo.repo()
    recent_occurrences_limit = Keyword.get(opts, :recent_occurrences_limit)
    id = to_integer(id)

    case list_issues(filters: [id: id], limit: 1) do
      [] ->
        nil

      [issue] when is_integer(recent_occurrences_limit) ->
        query = Event |> order_by(desc: :datetime) |> limit(^recent_occurrences_limit)
        repo.preload(issue, occurrences: query)

      [issue] ->
        issue
    end
  end

  def count_issues(opts \\ []) do
    repo = Repo.repo()
    filters = Keyword.get(opts, :filters, [])

    Issue
    |> where(^filter_where(filters))
    |> repo.aggregate(:count)
  end

  def find_or_create_issue(similarity_id) when is_integer(similarity_id) do
    repo = Repo.repo()

    case Event
         |> where([e], e.similarity_id == ^similarity_id)
         |> order_by(desc: :datetime)
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

  def delete_issues_and_events([]), do: {:ok, {0, nil}}

  def delete_issues_and_events(ids) when is_list(ids) do
    repo = Repo.repo()

    result = Event |> where([e], e.issue_id in ^ids) |> repo.delete_all()

    Issue |> where([i], i.id in ^ids) |> repo.delete_all()

    {:ok, result}
  end

  def merge_issues(target_id, source_ids, opts \\ []) when is_list(source_ids) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    {:ok, result} =
      repo.transaction(fn ->
        any_source_unresolved? =
          Issue
          |> where([i], i.id in ^source_ids and i.state == :unresolved)
          |> repo.exists?()

        if any_source_unresolved? do
          Issue |> where([i], i.id == ^target_id) |> repo.update_all(set: [state: :unresolved])
        end

        events_moved =
          Event
          |> where([e], e.issue_id in ^source_ids)
          |> repo.update_all(set: [issue_id: target_id])

        Issue |> where([i], i.id in ^source_ids) |> repo.delete_all()

        events_moved
      end)

    result
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
