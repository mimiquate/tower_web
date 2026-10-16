defmodule TowerWeb.DB.Events do
  import Ecto.Query

  alias Ecto.Multi
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

  def create_event_for_issue(attrs) do
    repo = Repo.repo()
    changeset = Event.changeset(%Event{}, attrs)
    similarity_id = Ecto.Changeset.get_field(changeset, :similarity_id)

    Multi.new()
    |> Multi.run(:issue, fn _repo, _changes ->
      Issues.find_or_create_issue(similarity_id)
    end)
    |> Multi.insert(:event, fn %{issue: issue} ->
      Event.changeset(%Event{}, Map.put(attrs, :issue_id, issue.id))
    end)
    |> repo.transact()
  end

  def delete_event(%Event{} = event) do
    repo = Repo.repo()

    Multi.new()
    |> Multi.delete(:event, event)
    |> Multi.run(:issue, fn _repo, _changes ->
      delete_issues_if_empty([event.issue_id])
    end)
    |> repo.transact()
  end

  def delete_events(ids) when is_list(ids) do
    repo = Repo.repo()

    query =
      Event
      |> where([e], e.id in ^ids)
      |> select([e], e.issue_id)

    Multi.new()
    |> Multi.delete_all(:events, query)
    |> Multi.run(:issue, fn _repo, %{events: {_count, issue_ids}} ->
      delete_issues_if_empty(Enum.uniq(issue_ids))
    end)
    |> repo.transact()
  end

  defp delete_issues_if_empty(issue_ids) do
    repo = Repo.repo()

    empty_ids =
      Issue
      |> where([i], i.id in ^issue_ids)
      |> join(:left, [i], e in Event, on: e.issue_id == i.id)
      |> where([i, e], is_nil(e.id))
      |> select([i], i.id)
      |> repo.all()

    Issues.delete_issues_and_events(empty_ids)
  end
end
