defmodule TowerWeb.DB.Events do
  import Ecto.Query

  alias TowerWeb.DB.Event
  alias TowerWeb.DB.Issue
  alias TowerWeb.DB.Issues
  alias TowerWeb.DB.Repo

  @default_limit 20

  def list_events(opts \\ []) do
    repo = Repo.repo()
    filters = Keyword.get(opts, :filters, [])
    limit = Keyword.get(opts, :limit, @default_limit)
    offset = Keyword.get(opts, :offset, 0)
    fields = Keyword.get(opts, :select, dynamic([e], e))

    Event
    |> where(^filter_where(filters))
    |> order_by(desc: :datetime)
    |> limit(^limit)
    |> offset(^offset)
    |> select(^fields)
    |> repo.all()
  end

  def count_events(opts \\ []) do
    repo = Repo.repo()
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

      {:issue_id, value}, dynamic when is_binary(value) or is_list(value) ->
        value = List.wrap(value)
        dynamic([e], ^dynamic and e.issue_id in ^value)

      {:datetime_range, {from, to}}, dynamic ->
        dynamic([e], ^dynamic and e.datetime >= ^from and e.datetime <= ^to)

      {_, _}, dynamic ->
        dynamic
    end)
  end

  def get_event(id) do
    Repo.repo().get(Event, id)
  end

  def create_event(attrs) do
    repo = Repo.repo()
    changeset = Event.changeset(%Event{}, attrs)

    if changeset.valid? do
      similarity_id = Ecto.Changeset.get_field(changeset, :similarity_id)

      repo.transact(fn ->
        with {:ok, issue_id} <- Issues.find_or_create_issue(similarity_id) do
          %Event{}
          |> Event.changeset(Map.put(attrs, :issue_id, issue_id))
          |> repo.insert()
        end
      end)
    else
      {:error, changeset}
    end
  end

  def delete_event(%Event{} = event) do
    repo = Repo.repo()

    repo.transact(fn ->
      result = repo.delete(event)
      delete_issues_if_empty([event.issue_id], repo)
      result
    end)
  end

  def delete_events(ids) when is_list(ids) do
    repo = Repo.repo()

    {:ok, result} =
      repo.transact(fn ->
        {count, issue_ids} =
          Event
          |> where([e], e.id in ^ids)
          |> select([e], e.issue_id)
          |> repo.delete_all()

        delete_issues_if_empty(Enum.uniq(issue_ids), repo)

        {:ok, {count, nil}}
      end)

    result
  end

  defp delete_issues_if_empty(issue_ids, repo) do
    empty_ids =
      Issue
      |> where([i], i.id in ^issue_ids)
      |> join(:left, [i], e in Event, on: e.issue_id == i.id)
      |> where([i, e], is_nil(e.id))
      |> select([i], i.id)
      |> repo.all()

    Issues.delete_issues_and_events(empty_ids)

    :ok
  end
end
