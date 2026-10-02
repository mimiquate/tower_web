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

    Issue
    |> where(^filter_where(filters))
    |> order_by(desc: :last_seen)
    |> limit(^limit)
    |> offset(^offset)
    |> repo.all()
  end

  def get_issue(id, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()
    recent_occurrences_limit = Keyword.get(opts, :recent_occurrences_limit)

    case repo.get(Issue, id) do
      nil ->
        nil

      issue when is_integer(recent_occurrences_limit) ->
        repo.preload(issue,
          occurrences:
            from(e in Event, order_by: [desc: e.datetime], limit: ^recent_occurrences_limit)
        )

      issue ->
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

  def upsert_issue(%Event{} = event, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    case repo.get(Issue, event.similarity_id) do
      nil ->
        %Issue{}
        |> Issue.changeset(%{
          id: event.similarity_id,
          count_events: 1,
          first_seen: event.datetime,
          last_seen: event.datetime,
          level: event.level,
          normalized_reason: event.normalized_reason,
          stacktrace: event.stacktrace
        })
        |> repo.insert()

      issue ->
        issue
        |> Issue.changeset(%{count_events: issue.count_events + 1})
        |> put_if(
          DateTime.compare(event.datetime, issue.first_seen) == :lt,
          :first_seen,
          event.datetime
        )
        |> put_if(
          DateTime.compare(event.datetime, issue.last_seen) == :gt,
          :last_seen,
          event.datetime
        )
        |> repo.update()
    end
  end

  defp put_if(changeset, true, field, value),
    do: Ecto.Changeset.put_change(changeset, field, value)

  defp put_if(changeset, false, _field, _value), do: changeset

  def update_issue_on_event_deletion(%Event{} = event, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()
    issue = repo.get(Issue, event.similarity_id)
    remaining_count = issue.count_events - 1

    if remaining_count == 0 do
      Issue |> where([i], i.id == ^issue.id) |> repo.delete_all()
    else
      first_seen =
        if DateTime.compare(event.datetime, issue.first_seen) != :gt do
          Event
          |> where([e], e.similarity_id == ^issue.id)
          |> select([e], min(e.datetime))
          |> repo.one()
        else
          issue.first_seen
        end

      last_seen =
        if DateTime.compare(event.datetime, issue.last_seen) != :lt do
          Event
          |> where([e], e.similarity_id == ^issue.id)
          |> select([e], max(e.datetime))
          |> repo.one()
        else
          issue.last_seen
        end

      issue
      |> Issue.changeset(%{
        count_events: remaining_count,
        first_seen: first_seen,
        last_seen: last_seen
      })
      |> repo.update()
    end
  end

  def recalculate_issue(id, deleted_count, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()
    issue = repo.get(Issue, id)
    remaining_count = issue.count_events - deleted_count

    if remaining_count == 0 do
      Issue |> where([i], i.id == ^id) |> repo.delete_all()
    else
      %{first_seen: first_seen, last_seen: last_seen} =
        Event
        |> where([e], e.similarity_id == ^id)
        |> select([e], %{first_seen: min(e.datetime), last_seen: max(e.datetime)})
        |> repo.one()

      issue
      |> Issue.changeset(%{
        count_events: remaining_count,
        first_seen: first_seen,
        last_seen: last_seen
      })
      |> repo.update()
    end
  end

  def delete_issue(id, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    result = Event |> where([e], e.similarity_id == ^id) |> repo.delete_all()

    Issue |> where([i], i.id == ^id) |> repo.delete_all()

    result
  end

  def delete_issues(ids, opts \\ []) when is_list(ids) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    result = Event |> where([e], e.similarity_id in ^ids) |> repo.delete_all()

    Issue |> where([i], i.id in ^ids) |> repo.delete_all()

    result
  end

  defp filter_where(filters) do
    Enum.reduce(filters, dynamic(true), fn
      {:search, value}, dynamic when value != "" ->
        search_term = "%#{value}%"
        dynamic([i], ^dynamic and ilike(i.normalized_reason, ^search_term))

      {:level, value}, dynamic when not is_nil(value) ->
        dynamic([i], ^dynamic and i.level == ^value)

      {:similarity_id, value}, dynamic
      when is_binary(value) or is_list(value) or is_integer(value) ->
        value = List.wrap(value)
        dynamic([i], ^dynamic and i.id in ^value)

      {:datetime_range, {from, to}}, dynamic ->
        matching_ids =
          from(e in Event,
            where: e.datetime >= ^from and e.datetime <= ^to,
            select: e.similarity_id
          )

        dynamic([i], ^dynamic and i.id in subquery(matching_ids))

      {_, _}, dynamic ->
        dynamic
    end)
  end
end
