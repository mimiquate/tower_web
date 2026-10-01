defmodule TowerWeb.DB.Events do
  import Ecto.Query

  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Issue
  alias TowerWeb.DB.Issues
  alias TowerWeb.DB.Repo

  @default_limit 20

  def list_events(opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()
    filters = Keyword.get(opts, :filters, [])
    limit = Keyword.get(opts, :limit, @default_limit)
    offset = Keyword.get(opts, :offset, 0)
    fields = Keyword.get(opts, :select, dynamic([e], e))
    preload_issue = Keyword.get(opts, :preload_issue, false)

    events =
      Event
      |> where(^filter_where(filters))
      |> order_by(desc: :datetime)
      |> limit(^limit)
      |> offset(^offset)
      |> select(^fields)
      |> repo.all()

    case preload_issue do
      true ->
        repo.preload(events, :issue)

      fields when is_list(fields) ->
        repo.preload(events, issue: from(i in Issue, select: ^fields))

      _ ->
        events
    end
  end

  def count_events(opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()
    filters = Keyword.get(opts, :filters, [])

    Event
    |> where(^filter_where(filters))
    |> repo.aggregate(:count)
  end

  defp filter_where(filters) do
    Enum.reduce(filters, dynamic(true), fn
      {:search, value}, dynamic when value != "" ->
        search_term = "%#{value}%"
        dynamic([e], ^dynamic and ilike(e.normalized_reason, ^search_term))

      {:level, value}, dynamic when not is_nil(value) ->
        dynamic([e], ^dynamic and e.level == ^value)

      {:similarity_id, value}, dynamic when is_binary(value) or is_list(value) ->
        value = List.wrap(value)
        dynamic([e], ^dynamic and e.similarity_id in ^value)

      {:datetime_range, {from, to}}, dynamic ->
        dynamic([e], ^dynamic and e.datetime >= ^from and e.datetime <= ^to)

      {_, _}, dynamic ->
        dynamic
    end)
  end

  def get_event(id, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    repo.get(Event, id)
  end

  def create_event(attrs, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    case Map.get(attrs, :similarity_id) do
      similarity_id when is_integer(similarity_id) ->
        changeset = Event.changeset(%Event{}, Map.put(attrs, :issue_id, similarity_id))

        if changeset.valid? do
          repo.transact(fn ->
            with {:ok, _issue} <- Issues.upsert_issue(similarity_id, repo: repo),
                 {:ok, event} <- repo.insert(changeset) do
              {:ok, event}
            end
          end)
        else
          {:error, changeset}
        end

      _ ->
        {:error, Event.changeset(%Event{}, attrs)}
    end
  end

  def delete_event(%Event{} = event, opts \\ []) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    repo.transact(fn ->
      result = repo.delete(event)
      Issues.delete_issue_if_empty(event.issue_id, repo: repo)
      result
    end)
  end

  def delete_events(ids, opts \\ []) when is_list(ids) do
    repo = Keyword.get(opts, :repo) || Repo.repo()

    {:ok, result} =
      repo.transact(fn ->
        {count, issue_ids} =
          Event
          |> where([e], e.id in ^ids)
          |> select([e], e.issue_id)
          |> repo.delete_all()

        issue_ids
        |> Enum.uniq()
        |> Enum.each(fn issue_id ->
          Issues.delete_issue_if_empty(issue_id, repo: repo)
        end)

        {:ok, {count, nil}}
      end)

    result
  end
end
